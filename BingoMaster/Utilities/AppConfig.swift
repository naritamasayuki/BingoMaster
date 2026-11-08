import Foundation

/// アプリ全体の設定値・外部サービス識別子を一元管理する構成ユーティリティ。
/// 開発方針「5. セキュリティとパフォーマンス（シークレット管理）」に基づき、
/// APIキーや広告IDをソースコード内にハードコーディングせず、環境変数または Info.plist から安全に取得する。
enum AppConfig {
    /// Google AdMob アプリID（未設定またはプレースホルダー時は nil）
    static var adMobAppID: String? {
        resolvedSecret(
            envKey: "ADMOB_APP_ID",
            plistKey: "GADApplicationIdentifier"
        )
    }

    /// Google AdMob バナー広告ユニットID（未設定またはプレースホルダー時は nil）
    static var adMobBannerUnitID: String? {
        resolvedSecret(
            envKey: "ADMOB_BANNER_UNIT_ID",
            plistKey: "AdMobBannerUnitID"
        )
    }

    /// 本番用 AdMob ID が両方とも有効に設定されているか判定
    static var isAdMobConfigured: Bool {
        adMobAppID != nil && adMobBannerUnitID != nil
    }

    /// CI環境やローカル開発では環境変数を優先し、実機ビルドでは Info.plist を参照するため2段階で解決する
    private static func resolvedSecret(envKey: String, plistKey: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           isValidSecretValue(envValue) {
            return envValue
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidSecretValue(trimmed) {
                return trimmed
            }
        }
        return nil
    }

    /// 空文字や未展開のXcode変数 `$(...)`、サンプル値を除外して誤動作を防ぐ
    private static func isValidSecretValue(_ value: String) -> Bool {
        guard !value.isEmpty,
              !value.hasPrefix("$("),
              !value.contains("xxxxxxxxxxxxxxxx") else {
            return false
        }
        return true
    }
}
