import Foundation
import MultipeerConnectivity
import UIKit

@MainActor
final class MultipeerSyncManager: NSObject, ObservableObject {
    static let serviceType = "bingomaster-p2p"

    enum Role {
        case none
        case host
        case player
    }

    @Published private(set) var currentRole: Role = .none
    @Published private(set) var connectedPeerNames: [String] = []
    @Published private(set) var isActive: Bool = false

    /// 司会側：新しい参加者Peerが .connected になった瞬間に呼ばれるコールバック（全出目の即時同期用）
    var onPeerConnectedToHost: ((MCPeerID) -> Void)?

    /// 司会側：参加者から PlayerToHostPayload を受信した際のコールバック
    var onReceivePlayerPayload: ((PlayerToHostPayload) -> Void)?

    /// 参加側：司会者から HostToPlayerPayload を受信した際のコールバック
    var onReceiveHostPayload: ((HostToPlayerPayload) -> Void)?

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        let deviceName = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: deviceName)
        super.init()
    }

    // MARK: - Session Control

    /// 司会者（Host / Advertiser）としてP2P待機を開始
    func startHosting() {
        stop()
        currentRole = .host

        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
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
    }

    /// 参加者（Player / Browser）として司会者の探索・自動接続を開始
    func startBrowsing() {
        stop()
        currentRole = .player

        let newSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
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
    }

    /// 通信・探索を停止してセッションを破棄
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
    }

    // MARK: - Send Payloads

    /// 司会者 ➔ 全参加者（または特定Peer）へ HostToPlayerPayload を送信
    func sendHostPayload(_ payload: HostToPlayerPayload, to targetPeers: [MCPeerID]? = nil) {
        guard let session = session else { return }
        let peers = targetPeers ?? session.connectedPeers
        guard !peers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            // 送信エラー時は次回の同期でリカバリ
        }
    }

    /// 参加者 ➔ 司会者へ PlayerToHostPayload を送信
    func sendPlayerPayload(_ payload: PlayerToHostPayload) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            // 送信エラー時は無視
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
            if state == .connected && self.currentRole == .host {
                // 新しいPeerが接続された瞬間、司会側から現在の全出目を即座に送信して同期させる
                self.onPeerConnectedToHost?(peerID)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            if self.currentRole == .player,
               let hostPayload = try? JSONDecoder().decode(HostToPlayerPayload.self, from: data) {
                self.onReceiveHostPayload?(hostPayload)
            } else if self.currentRole == .host,
                      let playerPayload = try? JSONDecoder().decode(PlayerToHostPayload.self, from: data) {
                self.onReceivePlayerPayload?(playerPayload)
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
    ) {}
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
            // 司会側は参加者からの招待を自動的に承認する
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
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
            // 参加側は司会者を発見したら自動的に招待を送る
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
