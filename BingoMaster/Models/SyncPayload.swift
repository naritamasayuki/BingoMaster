import Foundation

/// Host ➔ Player へブロードキャストするメッセージ
struct HostToPlayerPayload: Codable {
    enum ActionType: String, Codable {
        case drawNumber   // 新しい数字が引かれた（または途中参加・再接続時の状態同期）
        case resetGame    // 司会者がゲームをリセットした（この時のみ参加者のカードが新規配布される）
    }
    let action: ActionType
    let hostID: String                        // 本物の司会者端末の固有ID（偽ホストによる不正リセット・不正配信防止用）
    let gameSessionID: String                 // ゲーム回ごとの固有ID（不正なカード引き直し防止用）
    let latestNumber: Int?                    // 直近に引かれた番号
    let drawnNumbers: [Int]                   // これまでに引かれた全番号リスト（順番保持）
    let lockedPlayerCards: [String: [Int]]    // 司会者側でロック保存された参加者IDごとの5×5カード数字配列（不正変更防止用）

    init(
        action: ActionType,
        hostID: String = "",
        gameSessionID: String,
        latestNumber: Int?,
        drawnNumbers: [Int],
        lockedPlayerCards: [String: [Int]] = [:]
    ) {
        self.action = action
        self.hostID = hostID
        self.gameSessionID = gameSessionID
        self.latestNumber = latestNumber
        self.drawnNumbers = drawnNumbers
        self.lockedPlayerCards = lockedPlayerCards
    }

    enum CodingKeys: String, CodingKey {
        case action
        case hostID
        case gameSessionID
        case latestNumber
        case drawnNumbers
        case lockedPlayerCards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.action = try container.decode(ActionType.self, forKey: .action)
        self.hostID = try container.decodeIfPresent(String.self, forKey: .hostID) ?? ""
        self.gameSessionID = try container.decodeIfPresent(String.self, forKey: .gameSessionID) ?? ""
        self.latestNumber = try container.decodeIfPresent(Int.self, forKey: .latestNumber)
        self.drawnNumbers = try container.decodeIfPresent([Int].self, forKey: .drawnNumbers) ?? []
        self.lockedPlayerCards = try container.decodeIfPresent([String: [Int]].self, forKey: .lockedPlayerCards) ?? [:]
    }
}

/// Player ➔ Host へ送信するステータスメッセージ（および司会者側で検算・保存される参加者データ）
struct PlayerToHostPayload: Codable, Equatable, Identifiable {
    enum PlayerStatus: String, Codable, Equatable {
        case normal
        case reach        // リーチ発生
        case bingo        // ビンゴ達成
    }

    var id: String { playerID.isEmpty ? playerName : playerID }

    let playerID: String                  // Keychainに永続化された参加者端末固有ID（アプリ再起動・再インストールでも不変）
    var playerName: String                // 端末名またはニックネーム（ゲーム開始後はロック）
    var status: PlayerStatus              // 司会者側で検算済みの確定ステータス
    var bingoLineCount: Int               // 司会者側で検算済みのビンゴライン数
    var reachLineCount: Int               // 司会者側で検算済みのリーチライン数
    var cardNumbers: [Int]                // 参加者の5×5カードの数字配列（25マス・司会者側での不正防止ロック＆検算用）
    var punchedIndices: [Int]             // 参加者が現在開けているマスのインデックス配列（0〜24）
    var untappedDrawnCount: Int           // 手動モードで「すでに出ているのにまだ開けていない」マス数
    var theoreticalStatus: PlayerStatus   // 未タップのマスもすべて開けたと仮定した場合の理論上ステータス
    let requestSync: Bool                 // 途中参加・再接続時に司会者へこれまでの全出目を要求するフラグ

    init(
        playerID: String = "",
        playerName: String,
        status: PlayerStatus,
        bingoLineCount: Int = 0,
        reachLineCount: Int,
        cardNumbers: [Int] = [],
        punchedIndices: [Int] = [],
        untappedDrawnCount: Int = 0,
        theoreticalStatus: PlayerStatus = .normal,
        requestSync: Bool = false
    ) {
        self.playerID = playerID
        self.playerName = playerName
        self.status = status
        self.bingoLineCount = bingoLineCount
        self.reachLineCount = reachLineCount
        self.cardNumbers = cardNumbers
        self.punchedIndices = punchedIndices
        self.untappedDrawnCount = untappedDrawnCount
        self.theoreticalStatus = theoreticalStatus
        self.requestSync = requestSync
    }

    enum CodingKeys: String, CodingKey {
        case playerID
        case playerName
        case status
        case bingoLineCount
        case reachLineCount
        case cardNumbers
        case punchedIndices
        case untappedDrawnCount
        case theoreticalStatus
        case requestSync
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.playerID = try container.decodeIfPresent(String.self, forKey: .playerID) ?? ""
        self.playerName = try container.decode(String.self, forKey: .playerName)
        self.status = try container.decode(PlayerStatus.self, forKey: .status)
        self.bingoLineCount = try container.decodeIfPresent(Int.self, forKey: .bingoLineCount) ?? (self.status == .bingo ? 1 : 0)
        self.reachLineCount = try container.decode(Int.self, forKey: .reachLineCount)
        self.cardNumbers = try container.decodeIfPresent([Int].self, forKey: .cardNumbers) ?? []
        self.punchedIndices = try container.decodeIfPresent([Int].self, forKey: .punchedIndices) ?? []
        self.untappedDrawnCount = try container.decodeIfPresent(Int.self, forKey: .untappedDrawnCount) ?? 0
        self.theoreticalStatus = try container.decodeIfPresent(PlayerStatus.self, forKey: .theoreticalStatus) ?? self.status
        self.requestSync = try container.decodeIfPresent(Bool.self, forKey: .requestSync) ?? false
    }
}
