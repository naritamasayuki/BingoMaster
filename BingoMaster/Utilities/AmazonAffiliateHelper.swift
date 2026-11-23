import Foundation
import SwiftUI

/// ビンゴ大会・パーティー向けのおすすめAmazon商品カテゴリ
struct AmazonAffiliateItem: Identifiable {
    let id: String
    let iconName: String
    let accentColor: Color
    let title: String
    let subtitle: String
    let searchKeywordJP: String
    let searchKeywordGlobal: String
}

/// Amazonアソシエイト（物販アフィリエイト）の安全なURL生成および商品一覧を提供するユーティリティ
enum AmazonAffiliateHelper {
    /// 共通 Amazon アソシエイト ID（日本・Amazon.co.jp）
    static let associateTagJP = "shirokumacamp-22"

    /// ビンゴイベント主催者・参加者向けのおすすめグッズ一覧
    static var recommendedItems: [AmazonAffiliateItem] {
        [
            AmazonAffiliateItem(
                id: "prizes",
                iconName: "gift.fill",
                accentColor: .pink,
                title: String(localized: "ビンゴ大会の景品セット"),
                subtitle: String(localized: "忘年会・新年会・二次会で盛り上がる目録や定番景品"),
                searchKeywordJP: "ビンゴ 景品 セット 目録",
                searchKeywordGlobal: "bingo party prizes gift set"
            ),
            AmazonAffiliateItem(
                id: "paper-cards",
                iconName: "rectangle.grid.3x2.fill",
                accentColor: .orange,
                title: String(localized: "紙のビンゴカード（補充用）"),
                subtitle: String(localized: "スマホをお持ちでないお子様やご年配の参加者向け"),
                searchKeywordJP: "ビンゴカード 50枚 100枚",
                searchKeywordGlobal: "bingo cards paper pack"
            ),
            AmazonAffiliateItem(
                id: "projector-cable",
                iconName: "tv.fill",
                accentColor: .blue,
                title: String(localized: "プロジェクター・画面出力ケーブル"),
                subtitle: String(localized: "司会者の抽選画面をテレビや大型スクリーンに投影"),
                searchKeywordJP: "iPhone HDMI 変換 ケーブル プロジェクター",
                searchKeywordGlobal: "iPhone HDMI adapter mini projector"
            ),
            AmazonAffiliateItem(
                id: "bluetooth-speaker",
                iconName: "hifispeaker.fill",
                accentColor: .green,
                title: String(localized: "Bluetooth スピーカー"),
                subtitle: String(localized: "アプリの音声読み上げを広い会場全体にクリアに届ける"),
                searchKeywordJP: "Bluetooth スピーカー 大音量 パーティー",
                searchKeywordGlobal: "portable bluetooth party speaker"
            ),
            AmazonAffiliateItem(
                id: "party-goods",
                iconName: "party.popper.fill",
                accentColor: .purple,
                title: String(localized: "パーティー盛り上げグッズ"),
                subtitle: String(localized: "クラッカー・たすき・抽選箱などイベント演出アイテム"),
                searchKeywordJP: "パーティー グッズ クラッカー 抽選箱",
                searchKeywordGlobal: "party poppers bingo event supplies"
            )
        ]
    }

    /// ロケールに応じて日本（amazon.co.jp + アソシエイトタグ）または海外（amazon.com）の安全な検索URLを生成する
    static func makeSearchURL(
        for item: AmazonAffiliateItem,
        locale: Locale = .current
    ) -> URL? {
        let isJapanLocale = isJapaneseMarket(locale: locale)
        var components = URLComponents()
        components.scheme = "https"
        components.host = isJapanLocale ? "www.amazon.co.jp" : "www.amazon.com"
        components.path = "/s"

        var queryItems = [
            URLQueryItem(
                name: "k",
                value: isJapanLocale ? item.searchKeywordJP : item.searchKeywordGlobal
            )
        ]
        if isJapanLocale {
            queryItems.append(URLQueryItem(name: "tag", value: associateTagJP))
        }
        components.queryItems = queryItems
        return components.url
    }

    /// 日本向け Amazon.co.jp を使用すべきロケールか判定する
    static func isJapaneseMarket(locale: Locale = .current) -> Bool {
        if let regionCode = locale.region?.identifier.uppercased(), regionCode == "JP" {
            return true
        }
        if let languageCode = locale.language.languageCode?.identifier.lowercased(), languageCode == "ja" {
            return true
        }
        return false
    }
}
