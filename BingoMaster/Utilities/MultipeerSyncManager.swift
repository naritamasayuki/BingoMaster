import Foundation
import MultipeerConnectivity
import UIKit

/// 近距離P2P通信（MultipeerConnectivity）の抽象プロトコル。
/// 実機の無線通信を介さずに HostViewModel / PlayerViewModel 間のメッセージ同期・不正防止ロジックを
/// ユニットテストで検証できるようにするため分離している。
@MainActor
protocol BingoSyncManaging: AnyObject {
    var connectedPeerNames: [String] { get }
    var isActive: Bool { get }

    var onPeerConnectedToHost: ((MCPeerID) -> Void)? { get set }
    var onPeerConnectedToPlayer: ((MCPeerID) -> Void)? { get set }
    var onReceivePlayerPayload: ((PlayerToHostPayload) -> Void)? { get set }
    var onReceiveHostPayload: ((HostToPlayerPayload) -> Void)? { get set }

    func startHosting()
    func startBrowsing()
    func stop()
    func sendHostPayload(_ payload: HostToPlayerPayload, to targetPeers: [MCPeerID]?)
    func sendPlayerPayload(_ payload: PlayerToHostPayload)
}

extension BingoSyncManaging {
    func sendHostPayload(_ payload: HostToPlayerPayload) {
        sendHostPayload(payload, to: nil)
    }
}

@MainActor
final class MultipeerSyncManager: NSObject, ObservableObject, BingoSyncManaging {
    static let serviceType = "bingomaster-p2p"

    /// 不正に肥大化したペイロードによるメモリ圧迫を防ぐための受信サイズ上限（64KB）
    private static let maxPayloadByteCount = 65_536

    enum Role {
        case none
        case host
        case player
    }

    @Published private(set) var currentRole: Role = .none
    @Published private(set) var connectedPeerNames: [String] = []
    @Published private(set) var isActive: Bool = false
    /// 同時接続上限（自分を含め kMCSessionMaximumNumberOfPeers 台）で断った招待の件数（司会者画面の「満員」表示用）
    @Published private(set) var rejectedInvitationCount: Int = 0

    /// 司会者が受け入れられる参加者の最大数（自分の1台を除く = 7人）
    static let maxPlayerPeers = kMCSessionMaximumNumberOfPeers - 1

    var onPeerConnectedToHost: ((MCPeerID) -> Void)?
    var onPeerConnectedToPlayer: ((MCPeerID) -> Void)?
    var onReceivePlayerPayload: ((PlayerToHostPayload) -> Void)?
    var onReceiveHostPayload: ((HostToPlayerPayload) -> Void)?

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        let deviceName = UIDevice.current.name
        let sanitizedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.myPeerID = MCPeerID(displayName: sanitizedName.isEmpty ? "iPhone" : sanitizedName)
        super.init()
    }

    // MARK: - Session Control

    func startHosting() {
        stop()
        currentRole = .host

        // 会場内の盗聴・改ざんを防ぐため暗号化を必須にする（参加者側と必ず揃えること）
        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        self.session = newSession

        let newAdvertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        newAdvertiser.delegate = self
        newAdvertiser.startAdvertisingPeer()
        self.advertiser = newAdvertiser
        self.isActive = true
        BingoLogger.logInfo(BingoLogger.sync, message: "司会者（Host）としてP2Pアドバタイズを開始しました")
    }

    func startBrowsing() {
        stop()
        currentRole = .player

        // 会場内の盗聴・改ざんを防ぐため暗号化を必須にする（司会者側と必ず揃えること）
        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        newSession.delegate = self
        self.session = newSession

        let newBrowser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: Self.serviceType
        )
        newBrowser.delegate = self
        newBrowser.startBrowsingForPeers()
        self.browser = newBrowser
        self.isActive = true
        BingoLogger.logInfo(BingoLogger.sync, message: "参加者（Player）としてP2Pブラウジングを開始しました")
    }

    /// バックグラウンド復帰時などに広告・探索を再開して再接続しやすくする
    func restartDiscoveryIfNeeded() {
        guard isActive else { return }
        switch currentRole {
        case .host:
            advertiser?.stopAdvertisingPeer()
            advertiser?.startAdvertisingPeer()
        case .player:
            if connectedPeerNames.isEmpty {
                browser?.stopBrowsingForPeers()
                browser?.startBrowsingForPeers()
            }
        case .none:
            break
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil

        session?.disconnect()
        session?.delegate = nil
        session = nil

        connectedPeerNames = []
        currentRole = .none
        isActive = false
        rejectedInvitationCount = 0
    }

    // MARK: - Send Payloads

    func sendHostPayload(_ payload: HostToPlayerPayload, to targetPeers: [MCPeerID]? = nil) {
        guard let session = session else { return }
        let peers = targetPeers ?? session.connectedPeers
        guard !peers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            BingoLogger.logError(
                BingoLogger.sync,
                context: "司会者ペイロードのP2P送信に失敗しました (対象Peer数: \(peers.count), action: \(payload.action.rawValue))",
                error: error
            )
        }
    }

    func sendPlayerPayload(_ payload: PlayerToHostPayload) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            BingoLogger.logError(
                BingoLogger.sync,
                context: "参加者ペイロードのP2P送信に失敗しました (playerName: \(payload.playerName))",
                error: error
            )
        }
    }

    private func updateConnectedPeers() {
        guard let session = session else {
            connectedPeerNames = []
            return
        }
        connectedPeerNames = session.connectedPeers.map { $0.displayName }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerSyncManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.updateConnectedPeers()
            switch state {
            case .connected:
                BingoLogger.logInfo(BingoLogger.sync, message: "Peerと接続完了しました: \(peerID.displayName)")
                if self.currentRole == .host {
                    // 途中参加・一時切断からの復帰時に出目の取りこぼしを防ぐため、接続確立と同時に全出目を即時配信する
                    self.onPeerConnectedToHost?(peerID)
                } else if self.currentRole == .player {
                    self.onPeerConnectedToPlayer?(peerID)
                }
            case .notConnected:
                BingoLogger.logWarning(BingoLogger.sync, context: "Peerとの接続が切断されました: \(peerID.displayName)")
                // 参加者が司会者を見失った場合、再探索をトリガーして自動再接続を促す
                if self.currentRole == .player, self.connectedPeerNames.isEmpty {
                    self.browser?.stopBrowsingForPeers()
                    self.browser?.startBrowsingForPeers()
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= Self.maxPayloadByteCount else {
            BingoLogger.logWarning(
                BingoLogger.sync,
                context: "上限サイズ(\(Self.maxPayloadByteCount)B)を超える受信データを破棄しました (サイズ: \(data.count)B, from: \(peerID.displayName))"
            )
            return
        }
        Task { @MainActor in
            do {
                if self.currentRole == .player {
                    let hostPayload = try JSONDecoder().decode(HostToPlayerPayload.self, from: data)
                    self.onReceiveHostPayload?(hostPayload)
                } else if self.currentRole == .host {
                    let playerPayload = try JSONDecoder().decode(PlayerToHostPayload.self, from: data)
                    self.onReceivePlayerPayload?(playerPayload)
                }
            } catch {
                BingoLogger.logError(
                    BingoLogger.sync,
                    context: "P2P受信データのデコードに失敗しました (role: \(self.currentRole), from: \(peerID.displayName))",
                    error: error
                )
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        if let error = error {
            BingoLogger.logError(
                BingoLogger.sync,
                context: "リソース受信中にエラーが発生しました (resource: \(resourceName))",
                error: error
            )
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MultipeerSyncManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            // 停止直後などでセッションがない場合は、nil セッションで承認しないよう必ず拒否する
            guard self.currentRole == .host, let session = self.session else {
                invitationHandler(false, nil)
                return
            }
            // MCSession は自分を含め最大 8 台（参加者最大 7 人）のため、上限超過時は拒否して司会者へ通知する
            guard session.connectedPeers.count < Self.maxPlayerPeers else {
                self.rejectedInvitationCount += 1
                BingoLogger.logWarning(
                    BingoLogger.sync,
                    context: "同時接続上限(\(Self.maxPlayerPeers)人)に達したため招待を拒否しました: \(peerID.displayName)"
                )
                invitationHandler(false, nil)
                return
            }
            invitationHandler(true, session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        BingoLogger.logError(
            BingoLogger.sync,
            context: "P2Pアドバタイズ開始に失敗しました（ローカルネットワーク権限やWi-Fi/Bluetooth状態を確認してください）",
            error: error
        )
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MultipeerSyncManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard let session = self.session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        BingoLogger.logWarning(BingoLogger.sync, context: "近隣Peerを見失いました: \(peerID.displayName)")
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        BingoLogger.logError(
            BingoLogger.sync,
            context: "P2Pブラウジング開始に失敗しました（ローカルネットワーク権限やWi-Fi/Bluetooth状態を確認してください）",
            error: error
        )
    }
}
