import Foundation
import os

/// アプリ全体の構造化ログ出力ユーティリティ。
/// 開発方針「6. 堅牢な実装ルール（エラーハンドリングとログ）」に基づき、
/// 異常系（通信切断、デコード失敗、Keychainエラー、音声初期化失敗、不正データ検出等）の発生箇所と詳細原因を
/// Apple 標準の Unified Logging (`os.Logger`) へ記録し、迅速に原因究明できるようにする。
enum BingoLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.naritamasayuki.bingomaster"

    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let sync = Logger(subsystem: subsystem, category: "MultipeerSync")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let speech = Logger(subsystem: subsystem, category: "Speech")
    static let game = Logger(subsystem: subsystem, category: "GameLogic")

    /// エラーオブジェクトと発生箇所（ファイル・関数・行番号）およびコールスタックを伴うエラーログ出力
    static func logError(
        _ logger: Logger,
        context: String,
        error: Error? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        let stackSummary = Thread.callStackSymbols.dropFirst().prefix(5).joined(separator: " | ")
        if let error = error {
            logger.error("[\(file, privacy: .public):\(line, privacy: .public) \(function, privacy: .public)] \(context, privacy: .public) - error: \(String(describing: error), privacy: .public) | stack: \(stackSummary, privacy: .public)")
        } else {
            logger.error("[\(file, privacy: .public):\(line, privacy: .public) \(function, privacy: .public)] \(context, privacy: .public) | stack: \(stackSummary, privacy: .public)")
        }
    }

    /// 警告レベルの異常系（不正カード検出、未知のホストからの通信遮断など）を記録
    static func logWarning(
        _ logger: Logger,
        context: String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        logger.warning("[\(file, privacy: .public):\(line, privacy: .public) \(function, privacy: .public)] \(context, privacy: .public)")
    }

    /// 正常系の重要イベント（セッション開始・接続・リセット等）を記録
    static func logInfo(
        _ logger: Logger,
        message: String
    ) {
        logger.info("\(message, privacy: .public)")
    }
}
