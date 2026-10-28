import Foundation

/// Host ➔ Player へブロードキャストするメッセージ
struct HostToPlayerPayload: Codable {
    enum ActionType: String, Codable {
        case drawNumber   // 新しい数字が引かれた（または再接続時の状態同期）
        case resetGame    // ゲームがリセットされた
    }
    let action: ActionType
    let latestNumber: Int?        // 直近に引かれた番号
    let drawnNumbers: [Int]       // これまでに引かれた全番号リスト（順番保持）
}

/// Player ➔ Host へ送信するステータスメッセージ
struct PlayerToHostPayload: Codable {
    enum PlayerStatus: String, Codable {
        case normal
        case reach        // リーチ発生
        case bingo        // ビンゴ達成
    }
    let playerName: String        // 端末名またはニックネーム
    let status: PlayerStatus
    let reachLineCount: Int       // 現在のリーチライン数
}
