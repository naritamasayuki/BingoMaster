import Foundation
import CoreLocation
import SwiftUI

// MARK: - 情報サイト種別
enum SafetySiteProvider: String, CaseIterable, Codable, Identifiable {
    case fushinshaCenter = "日本不審者情報センター"
    case gaccomSafety = "ガッコム安全ナビ"
    case npscPolice = "警察庁・都道府県警察リンク"
    case yahooBosai = "Yahoo!天気・災害（防犯・防災）"

    var id: String { rawValue }

    var baseURLString: String {
        switch self {
        case .fushinshaCenter:
            return "https://fushinsha-joho.co.jp/"
        case .gaccomSafety:
            return "https://www.gaccom.jp/safety"
        case .npscPolice:
            return "https://www.npa.go.jp/link/prefectural.html"
        case .yahooBosai:
            return "https://typhoon.yahoo.co.jp/weather/jp/emergency/"
        }
    }

    var shortDescription: String {
        switch self {
        case .fushinshaCenter:
            return "全国の警察・自治体が発表する不審者・危険動物情報を網羅"
        case .gaccomSafety:
            return "学校周辺・市区町村別の治安・不審者マップ情報"
        case .npscPolice:
            return "各都道府県警察の公式防犯情報・メール配信窓口"
        case .yahooBosai:
            return "全国の緊急情報・自治体からの安全情報一覧"
        }
    }

    var iconName: String {
        switch self {
        case .fushinshaCenter:
            return "shield.lefthalf.filled.badge.checkmark"
        case .gaccomSafety:
            return "map.fill"
        case .npscPolice:
            return "building.columns.fill"
        case .yahooBosai:
            return "bell.badge.fill"
        }
    }

    /// 都道府県名に応じた検索・地域ページURLを返す
    func urlForPrefecture(_ prefecture: PrefectureItem) -> URL {
        switch self {
        case .fushinshaCenter:
            // 日本不審者情報センター内の検索またはGoogleサイト内検索で確実に該当都道府県記事を表示
            let query = "site:fushinsha-joho.co.jp \(prefecture.name)"
            if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.co.jp/search?q=\(encoded)&tbs=qdr:m") {
                return url
            }
            return URL(string: baseURLString)!
        case .gaccomSafety:
            if let url = URL(string: "https://www.gaccom.jp/safety/area/\(prefecture.romanSlug)") {
                return url
            }
            return URL(string: baseURLString)!
        case .npscPolice, .yahooBosai:
            let query = "\(prefecture.name) 警察 不審者情報 防犯"
            if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.co.jp/search?q=\(encoded)") {
                return url
            }
            return URL(string: baseURLString)!
        }
    }
}

// MARK: - 都道府県データ
struct PrefectureItem: Identifiable, Codable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let region: String
    let romanSlug: String
    let defaultLatitude: Double
    let defaultLongitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: defaultLatitude, longitude: defaultLongitude)
    }

    static let all: [PrefectureItem] = [
        // 北海道・東北
        PrefectureItem(code: "01", name: "北海道", region: "北海道・東北", romanSlug: "hokkaido", defaultLatitude: 43.0642, defaultLongitude: 141.3469),
        PrefectureItem(code: "02", name: "青森県", region: "北海道・東北", romanSlug: "aomori", defaultLatitude: 40.8244, defaultLongitude: 140.7400),
        PrefectureItem(code: "03", name: "岩手県", region: "北海道・東北", romanSlug: "iwate", defaultLatitude: 39.7036, defaultLongitude: 141.1527),
        PrefectureItem(code: "04", name: "宮城県", region: "北海道・東北", romanSlug: "miyagi", defaultLatitude: 38.2688, defaultLongitude: 140.8721),
        PrefectureItem(code: "05", name: "秋田県", region: "北海道・東北", romanSlug: "akita", defaultLatitude: 39.7186, defaultLongitude: 140.1024),
        PrefectureItem(code: "06", name: "山形県", region: "北海道・東北", romanSlug: "yamagata", defaultLatitude: 38.2404, defaultLongitude: 140.3633),
        PrefectureItem(code: "07", name: "福島県", region: "北海道・東北", romanSlug: "fukushima", defaultLatitude: 37.7503, defaultLongitude: 140.4676),
        // 関東
        PrefectureItem(code: "08", name: "茨城県", region: "関東", romanSlug: "ibaraki", defaultLatitude: 36.3418, defaultLongitude: 140.4468),
        PrefectureItem(code: "09", name: "栃木県", region: "関東", romanSlug: "tochigi", defaultLatitude: 36.5657, defaultLongitude: 139.8836),
        PrefectureItem(code: "10", name: "群馬県", region: "関東", romanSlug: "gunma", defaultLatitude: 36.3911, defaultLongitude: 139.0608),
        PrefectureItem(code: "11", name: "埼玉県", region: "関東", romanSlug: "saitama", defaultLatitude: 35.8570, defaultLongitude: 139.6489),
        PrefectureItem(code: "12", name: "千葉県", region: "関東", romanSlug: "chiba", defaultLatitude: 35.6051, defaultLongitude: 140.1233),
        PrefectureItem(code: "13", name: "東京都", region: "関東", romanSlug: "tokyo", defaultLatitude: 35.6895, defaultLongitude: 139.6917),
        PrefectureItem(code: "14", name: "神奈川県", region: "関東", romanSlug: "kanagawa", defaultLatitude: 35.4478, defaultLongitude: 139.6425),
        // 甲信越・北陸
        PrefectureItem(code: "15", name: "新潟県", region: "甲信越・北陸", romanSlug: "niigata", defaultLatitude: 37.9026, defaultLongitude: 139.0232),
        PrefectureItem(code: "16", name: "富山県", region: "甲信越・北陸", romanSlug: "toyama", defaultLatitude: 36.6953, defaultLongitude: 137.2113),
        PrefectureItem(code: "17", name: "石川県", region: "甲信越・北陸", romanSlug: "ishikawa", defaultLatitude: 36.5947, defaultLongitude: 136.6256),
        PrefectureItem(code: "18", name: "福井県", region: "甲信越・北陸", romanSlug: "fukui", defaultLatitude: 36.0652, defaultLongitude: 136.2216),
        PrefectureItem(code: "19", name: "山梨県", region: "甲信越・北陸", romanSlug: "yamanashi", defaultLatitude: 35.6642, defaultLongitude: 138.5684),
        PrefectureItem(code: "20", name: "長野県", region: "甲信越・北陸", romanSlug: "nagano", defaultLatitude: 36.6513, defaultLongitude: 138.1810),
        // 東海
        PrefectureItem(code: "21", name: "岐阜県", region: "東海", romanSlug: "gifu", defaultLatitude: 35.3912, defaultLongitude: 136.7223),
        PrefectureItem(code: "22", name: "静岡県", region: "東海", romanSlug: "shizuoka", defaultLatitude: 34.9769, defaultLongitude: 138.3831),
        PrefectureItem(code: "23", name: "愛知県", region: "東海", romanSlug: "aichi", defaultLatitude: 35.1802, defaultLongitude: 136.9066),
        PrefectureItem(code: "24", name: "三重県", region: "東海", romanSlug: "mie", defaultLatitude: 34.7303, defaultLongitude: 136.5086),
        // 関西
        PrefectureItem(code: "25", name: "滋賀県", region: "関西", romanSlug: "shiga", defaultLatitude: 35.0045, defaultLongitude: 135.8686),
        PrefectureItem(code: "26", name: "京都府", region: "関西", romanSlug: "kyoto", defaultLatitude: 35.0211, defaultLongitude: 135.7556),
        PrefectureItem(code: "27", name: "大阪府", region: "関西", romanSlug: "osaka", defaultLatitude: 34.6863, defaultLongitude: 135.5200),
        PrefectureItem(code: "28", name: "兵庫県", region: "関西", romanSlug: "hyogo", defaultLatitude: 34.6913, defaultLongitude: 135.1830),
        PrefectureItem(code: "29", name: "奈良県", region: "関西", romanSlug: "nara", defaultLatitude: 34.6851, defaultLongitude: 135.8327),
        PrefectureItem(code: "30", name: "和歌山県", region: "関西", romanSlug: "wakayama", defaultLatitude: 34.2260, defaultLongitude: 135.1675),
        // 中国・四国
        PrefectureItem(code: "31", name: "鳥取県", region: "中国・四国", romanSlug: "tottori", defaultLatitude: 35.5039, defaultLongitude: 134.2377),
        PrefectureItem(code: "32", name: "島根県", region: "中国・四国", romanSlug: "shimane", defaultLatitude: 35.4723, defaultLongitude: 133.0505),
        PrefectureItem(code: "33", name: "岡山県", region: "中国・四国", romanSlug: "okayama", defaultLatitude: 34.6618, defaultLongitude: 133.9344),
        PrefectureItem(code: "34", name: "広島県", region: "中国・四国", romanSlug: "hiroshima", defaultLatitude: 34.3966, defaultLongitude: 132.4596),
        PrefectureItem(code: "35", name: "山口県", region: "中国・四国", romanSlug: "yamaguchi", defaultLatitude: 34.1859, defaultLongitude: 131.4706),
        PrefectureItem(code: "36", name: "徳島県", region: "中国・四国", romanSlug: "tokushima", defaultLatitude: 34.0658, defaultLongitude: 134.5593),
        PrefectureItem(code: "37", name: "香川県", region: "中国・四国", romanSlug: "kagawa", defaultLatitude: 34.3401, defaultLongitude: 134.0434),
        PrefectureItem(code: "38", name: "愛媛県", region: "中国・四国", romanSlug: "ehime", defaultLatitude: 33.8416, defaultLongitude: 132.7657),
        PrefectureItem(code: "39", name: "高知県", region: "中国・四国", romanSlug: "kochi", defaultLatitude: 33.5597, defaultLongitude: 133.5311),
        // 九州・沖縄
        PrefectureItem(code: "40", name: "福岡県", region: "九州・沖縄", romanSlug: "fukuoka", defaultLatitude: 33.6064, defaultLongitude: 130.4183),
        PrefectureItem(code: "41", name: "佐賀県", region: "九州・沖縄", romanSlug: "saga", defaultLatitude: 33.2494, defaultLongitude: 130.2988),
        PrefectureItem(code: "42", name: "長崎県", region: "九州・沖縄", romanSlug: "nagasaki", defaultLatitude: 32.7503, defaultLongitude: 129.8777),
        PrefectureItem(code: "43", name: "熊本県", region: "九州・沖縄", romanSlug: "kumamoto", defaultLatitude: 32.7898, defaultLongitude: 130.7417),
        PrefectureItem(code: "44", name: "大分県", region: "九州・沖縄", romanSlug: "oita", defaultLatitude: 33.2382, defaultLongitude: 131.6126),
        PrefectureItem(code: "45", name: "宮崎県", region: "九州・沖縄", romanSlug: "miyazaki", defaultLatitude: 31.9111, defaultLongitude: 131.4239),
        PrefectureItem(code: "46", name: "鹿児島県", region: "九州・沖縄", romanSlug: "kagoshima", defaultLatitude: 31.5602, defaultLongitude: 130.5581),
        PrefectureItem(code: "47", name: "沖縄県", region: "九州・沖縄", romanSlug: "okinawa", defaultLatitude: 26.2124, defaultLongitude: 127.6809)
    ]
}

// MARK: - 不審者・危険箇所の事案カテゴリ
enum IncidentCategory: String, CaseIterable, Codable, Identifiable {
    case approaching = "声かけ・つきまとい"
    case indecent = "痴漢・公然わいせつ・盗撮"
    case suspiciousVehicle = "不審車両・連れ去り警戒"
    case wildAnimal = "クマ・イノシシ等の危険動物"
    case darkSpot = "街灯不足・死角・危険箇所"
    case safeSpot = "子ども110番の家・交番"
    case other = "その他の防犯情報"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .approaching:
            return "figure.walk.motion"
        case .indecent:
            return "exclamationmark.triangle.fill"
        case .suspiciousVehicle:
            return "car.fill"
        case .wildAnimal:
            return "pawprint.fill"
        case .darkSpot:
            return "moon.stars.fill"
        case .safeSpot:
            return "house.and.flag.fill"
        case .other:
            return "bell.fill"
        }
    }

    var pinColor: Color {
        switch self {
        case .approaching:
            return .orange
        case .indecent:
            return .red
        case .suspiciousVehicle:
            return .purple
        case .wildAnimal:
            return .brown
        case .darkSpot:
            return .indigo
        case .safeSpot:
            return .green
        case .other:
            return .blue
        }
    }
}

// MARK: - 地図にピン留めする不審者・防犯メモモデル
struct SafetyIncidentPin: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var category: IncidentCategory
    var addressOrArea: String
    var latitude: Double
    var longitude: Double
    var occurredAt: Date
    var details: String
    var sourceURLString: String
    var isResolved: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - ブックマーク（保存記事）モデル
struct SavedArticleItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    var prefectureName: String
    var note: String
    var savedAt: Date
}

// MARK: - Web閲覧履歴モデル
struct BrowsingHistoryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    var visitedAt: Date
}

// MARK: - 防犯チェックリスト項目
struct SafetyChecklistItem: Identifiable, Codable, Equatable {
    var id: String
    var category: String
    var title: String
    var detail: String
    var isChecked: Bool

    static let defaultItems: [SafetyChecklistItem] = [
        SafetyChecklistItem(
            id: "check_1",
            category: "登下校・お子さま",
            title: "防犯ブザーの電池切れ・鳴動確認",
            detail: "ランドセルやカバンのすぐ手が届く位置に装着されているか確認しましょう。",
            isChecked: false
        ),
        SafetyChecklistItem(
            id: "check_2",
            category: "登下校・お子さま",
            title: "通学路の「子ども110番の家」・交番の位置確認",
            detail: "いざという時に駆け込める場所を親子で一緒に歩いて確認しておきましょう。",
            isChecked: false
        ),
        SafetyChecklistItem(
            id: "check_3",
            category: "登下校・お子さま",
            title: "「いかのおすし」の約束を再確認",
            detail: "いかない・のらない・おおごえをだす・すぐにげる・しらせる。",
            isChecked: false
        ),
        SafetyChecklistItem(
            id: "check_4",
            category: "夜道・通勤・通学",
            title: "歩きスマホ・イヤホンの両耳装着を控える",
            detail: "背後からの接近に気づけるよう、夜間は周囲の音と気配に注意しましょう。",
            isChecked: false
        ),
        SafetyChecklistItem(
            id: "check_5",
            category: "夜道・通勤・通学",
            title: "遠回りでも街灯や人通りのある大通りを選ぶ",
            detail: "不審者情報が出ているエリアや公園の脇道は避けて通行しましょう。",
            isChecked: false
        ),
        SafetyChecklistItem(
            id: "check_6",
            category: "自宅・マンション",
            title: "帰宅時、玄関を開ける前に周囲・背後を確認",
            detail: "エレベーターやエントランスで不審な人物がいないか確認し、入室後はすぐ施錠。",
            isChecked: false
        )
    ]
}
