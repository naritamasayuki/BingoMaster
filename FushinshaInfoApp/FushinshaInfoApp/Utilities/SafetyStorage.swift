import Foundation
import SwiftUI

/// アプリ全体のデータを管理し、操作ごとに即座に UserDefaults へ自動保存するクラス
@MainActor
final class SafetyStorage: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let favoritePrefectureCodes = "fushinsha_favorite_prefecture_codes_v1"
        static let selectedProvider = "fushinsha_selected_provider_v1"
        static let currentURLString = "fushinsha_current_url_string_v1"
        static let incidentPins = "fushinsha_incident_pins_v1"
        static let savedArticles = "fushinsha_saved_articles_v1"
        static let browsingHistory = "fushinsha_browsing_history_v1"
        static let checklistItems = "fushinsha_checklist_items_v1"
        static let hasInitializedSamplePins = "fushinsha_has_initialized_sample_pins_v1"
    }

    /// 選択中のメインタブ（0: 情報サイト, 1: 防犯マップ, 2: 保存・履歴, 3: 防犯ツール）
    @Published var selectedTab: Int = 0

    /// お気に入り都道府県コード一覧（自動保存）
    @Published var favoritePrefectureCodes: [String] = [] {
        didSet { saveStringArray(favoritePrefectureCodes, forKey: Keys.favoritePrefectureCodes) }
    }

    /// 選択中のサイトプロバイダ（自動保存）
    @Published var selectedProvider: SafetySiteProvider = .fushinshaCenter {
        didSet { defaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider) }
    }

    /// Webビューアで開くURL文字列（自動保存）
    @Published var currentURLString: String = SafetySiteProvider.fushinshaCenter.baseURLString {
        didSet { defaults.set(currentURLString, forKey: Keys.currentURLString) }
    }

    /// Webビューアへの強制遷移リクエスト用トリガー
    @Published var requestedWebURL: URL?

    /// マップ画面で新規ピン作成シートを開く際の引き継ぎ情報
    @Published var pendingDraftPinTitle: String = ""
    @Published var pendingDraftPinURL: String = ""
    @Published var shouldPresentAddPinSheetFromWeb: Bool = false

    /// 地図上の不審者・危険箇所ピン一覧（自動保存）
    @Published var incidentPins: [SafetyIncidentPin] = [] {
        didSet { saveCodable(incidentPins, forKey: Keys.incidentPins) }
    }

    /// ブックマーク保存した記事一覧（自動保存）
    @Published var savedArticles: [SavedArticleItem] = [] {
        didSet { saveCodable(savedArticles, forKey: Keys.savedArticles) }
    }

    /// Web閲覧履歴一覧（自動保存・最大100件）
    @Published var browsingHistory: [BrowsingHistoryItem] = [] {
        didSet { saveCodable(browsingHistory, forKey: Keys.browsingHistory) }
    }

    /// 防犯チェックリスト項目（自動保存）
    @Published var checklistItems: [SafetyChecklistItem] = [] {
        didSet { saveCodable(checklistItems, forKey: Keys.checklistItems) }
    }

    init() {
        loadAll()
    }

    // MARK: - 読み込み処理
    private func loadAll() {
        if let savedCodes = defaults.stringArray(forKey: Keys.favoritePrefectureCodes), !savedCodes.isEmpty {
            favoritePrefectureCodes = savedCodes
        } else {
            // 初期値は東京都・大阪府・愛知県をサンプル登録
            favoritePrefectureCodes = ["13", "27", "23"]
        }

        if let rawProvider = defaults.string(forKey: Keys.selectedProvider),
           let provider = SafetySiteProvider(rawValue: rawProvider) {
            selectedProvider = provider
        }

        if let savedURL = defaults.string(forKey: Keys.currentURLString), !savedURL.isEmpty {
            currentURLString = savedURL
        } else {
            currentURLString = selectedProvider.baseURLString
        }

        if let loadedPins: [SafetyIncidentPin] = loadCodable(forKey: Keys.incidentPins) {
            incidentPins = loadedPins
        } else if !defaults.bool(forKey: Keys.hasInitializedSamplePins) {
            incidentPins = Self.sampleIncidentPins
            defaults.set(true, forKey: Keys.hasInitializedSamplePins)
        }

        if let loadedArticles: [SavedArticleItem] = loadCodable(forKey: Keys.savedArticles) {
            savedArticles = loadedArticles
        }

        if let loadedHistory: [BrowsingHistoryItem] = loadCodable(forKey: Keys.browsingHistory) {
            browsingHistory = loadedHistory
        }

        if let loadedChecklist: [SafetyChecklistItem] = loadCodable(forKey: Keys.checklistItems), !loadedChecklist.isEmpty {
            checklistItems = loadedChecklist
        } else {
            checklistItems = SafetyChecklistItem.defaultItems
        }
    }

    // MARK: - お気に入り都道府県操作
    var favoritePrefectures: [PrefectureItem] {
        favoritePrefectureCodes.compactMap { code in
            PrefectureItem.all.first(where: { $0.code == code })
        }
    }

    func isFavoritePrefecture(_ prefecture: PrefectureItem) -> Bool {
        favoritePrefectureCodes.contains(prefecture.code)
    }

    func toggleFavoritePrefecture(_ prefecture: PrefectureItem) {
        if let idx = favoritePrefectureCodes.firstIndex(of: prefecture.code) {
            favoritePrefectureCodes.remove(at: idx)
        } else {
            favoritePrefectureCodes.append(prefecture.code)
        }
    }

    // MARK: - Web遷移・履歴・ブックマーク操作
    func openURLInWebTab(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        currentURLString = urlString
        requestedWebURL = url
        selectedTab = 0
    }

    func recordBrowsingHistory(title: String, urlString: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, urlString.hasPrefix("http") else { return }
        let displayTitle = trimmedTitle.isEmpty ? urlString : trimmedTitle

        // 直前と同じURLなら日時・タイトルのみ更新
        if let first = browsingHistory.first, first.urlString == urlString {
            browsingHistory[0].title = displayTitle
            browsingHistory[0].visitedAt = Date()
            return
        }

        // 重複URLを除去して先頭に追加
        browsingHistory.removeAll { $0.urlString == urlString }
        let newItem = BrowsingHistoryItem(title: displayTitle, urlString: urlString, visitedAt: Date())
        browsingHistory.insert(newItem, at: 0)

        if browsingHistory.count > 100 {
            browsingHistory = Array(browsingHistory.prefix(100))
        }
    }

    func addSavedArticle(title: String, urlString: String, prefectureName: String, note: String) {
        let item = SavedArticleItem(
            title: title.isEmpty ? "不審者・防犯情報ページ" : title,
            urlString: urlString,
            prefectureName: prefectureName,
            note: note,
            savedAt: Date()
        )
        savedArticles.insert(item, at: 0)
    }

    func updateSavedArticle(_ item: SavedArticleItem) {
        if let idx = savedArticles.firstIndex(where: { $0.id == item.id }) {
            savedArticles[idx] = item
        }
    }

    func removeSavedArticle(id: UUID) {
        savedArticles.removeAll { $0.id == id }
    }

    // MARK: - マップピン操作
    func addIncidentPin(_ pin: SafetyIncidentPin) {
        incidentPins.insert(pin, at: 0)
    }

    func updateIncidentPin(_ pin: SafetyIncidentPin) {
        if let idx = incidentPins.firstIndex(where: { $0.id == pin.id }) {
            incidentPins[idx] = pin
        }
    }

    func deleteIncidentPin(id: UUID) {
        incidentPins.removeAll { $0.id == id }
    }

    func startAddPinFromWebPage(title: String, urlString: String) {
        pendingDraftPinTitle = title.isEmpty ? "Web記事の不審者情報" : title
        pendingDraftPinURL = urlString
        selectedTab = 1
        shouldPresentAddPinSheetFromWeb = true
    }

    // MARK: - 防犯チェックリスト操作
    func toggleChecklistItem(id: String) {
        guard let idx = checklistItems.firstIndex(where: { $0.id == id }) else { return }
        checklistItems[idx].isChecked.toggle()
    }

    func resetChecklistChecks() {
        for idx in checklistItems.indices {
            checklistItems[idx].isChecked = false
        }
    }

    // MARK: - 各種リセット操作（2段階確認後に呼ばれる）
    func clearBrowsingHistory() {
        browsingHistory.removeAll()
    }

    func clearSavedArticles() {
        savedArticles.removeAll()
    }

    func clearAllIncidentPins() {
        incidentPins.removeAll()
    }

    func restoreSampleIncidentPins() {
        incidentPins = Self.sampleIncidentPins
    }

    func resetAllAppData() {
        favoritePrefectureCodes = ["13", "27", "23"]
        selectedProvider = .fushinshaCenter
        currentURLString = SafetySiteProvider.fushinshaCenter.baseURLString
        incidentPins = []
        savedArticles = []
        browsingHistory = []
        checklistItems = SafetyChecklistItem.defaultItems
    }

    // MARK: - UserDefaults ヘルパー
    private func saveStringArray(_ array: [String], forKey key: String) {
        defaults.set(array, forKey: key)
    }

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - 初期サンプルピン（使い方がすぐ分かる見本データ）
    static let sampleIncidentPins: [SafetyIncidentPin] = [
        SafetyIncidentPin(
            title: "【見本】下校中の児童への声かけ事案",
            category: .approaching,
            addressOrArea: "東京都新宿区西新宿付近",
            latitude: 35.6895,
            longitude: 139.6917,
            occurredAt: Date().addingTimeInterval(-3600 * 18),
            details: "夕方16時頃、下校途中の小学生に対し「お菓子をあげるからこっちにおいで」等と声をかける事案が発生。（※これは使い方を示すサンプルデータです。自由に削除・編集できます）",
            sourceURLString: "https://fushinsha-joho.co.jp/",
            isResolved: false
        ),
        SafetyIncidentPin(
            title: "【見本】夜間の一人歩き注意（街灯が少ない道路）",
            category: .darkSpot,
            addressOrArea: "大阪府大阪市北区付近",
            latitude: 34.7024,
            longitude: 135.4959,
            occurredAt: Date().addingTimeInterval(-3600 * 48),
            details: "人通りが途切れる21時以降、つきまとい事案の報告あり。夜間は大通り側を通行推奨。（※サンプルデータ）",
            sourceURLString: "https://www.gaccom.jp/safety",
            isResolved: false
        ),
        SafetyIncidentPin(
            title: "【見本】不審車両による徐行・つきまとい警戒",
            category: .suspiciousVehicle,
            addressOrArea: "愛知県名古屋市中区付近",
            latitude: 35.1815,
            longitude: 136.9066,
            occurredAt: Date().addingTimeInterval(-3600 * 72),
            details: "黒っぽい乗用車が歩行者の横をゆっくり並走し、スマートフォンを向けるような動きが目撃されました。（※サンプルデータ）",
            sourceURLString: "https://fushinsha-joho.co.jp/",
            isResolved: false
        )
    ]
}
