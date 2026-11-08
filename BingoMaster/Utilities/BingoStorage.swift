import Foundation
import Security

struct PastGameRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let savedAt: Date
    let drawnNumbers: [Int]
    let players: [PlayerToHostPayload]

    init(
        id: UUID = UUID(),
        savedAt: Date = Date(),
        drawnNumbers: [Int],
        players: [PlayerToHostPayload] = []
    ) {
        self.id = id
        self.savedAt = savedAt
        self.drawnNumbers = drawnNumbers
        self.players = players
    }

    enum CodingKeys: String, CodingKey {
        case id
        case savedAt
        case drawnNumbers
        case players
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.savedAt = try container.decode(Date.self, forKey: .savedAt)
        self.drawnNumbers = try container.decode([Int].self, forKey: .drawnNumbers)
        self.players = try container.decodeIfPresent([PlayerToHostPayload].self, forKey: .players) ?? []
    }

    var formattedDate: String {
        BingoStorage.formatJapaneseDate(savedAt)
    }
}

struct PastPlayerGameRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let savedAt: Date
    let cardCells: [BingoCardCell]
    let drawnNumbers: [Int]
    let bingoLineCount: Int
    let reachLineCount: Int

    var formattedDate: String {
        BingoStorage.formatJapaneseDate(savedAt)
    }
}

/// ストレージ層を抽象化するプロトコル。
/// ユニットテスト時に実機の UserDefaults や Keychain を汚染せずインメモリで高速検証できるようにするため定義している。
protocol BingoStorageProviding {
    func saveActiveRole(_ role: String)
    func loadActiveRole() -> String?

    func saveHostDrawnNumbers(_ numbers: [Int])
    func loadHostDrawnNumbers() -> [Int]
    func saveHostPlayerStatuses(_ statuses: [String: PlayerToHostPayload])
    func loadHostPlayerStatuses() -> [String: PlayerToHostPayload]
    func saveHostRegisteredCards(_ cards: [String: [Int]])
    func loadHostRegisteredCards() -> [String: [Int]]
    func clearHostData()
    func loadOrCreateHostID() -> String
    func loadOrCreateHostGameSessionID() -> String
    @discardableResult func regenerateHostGameSessionID() -> String
    func saveHostSpinDurationMode(_ rawValue: String)
    func loadHostSpinDurationMode() -> String?
    func archiveGameHistory(_ drawnNumbers: [Int], players: [PlayerToHostPayload])
    func loadPastGameHistory() -> [PastGameRecord]

    func loadOrCreatePlayerID() -> String
    func savePlayerCardCells(_ cells: [BingoCardCell])
    func loadPlayerCardCells() -> [BingoCardCell]?
    func savePlayerIsAutoPunch(_ isAutoPunch: Bool)
    func loadPlayerIsAutoPunch() -> Bool
    func savePlayerName(_ name: String)
    func loadPlayerName() -> String?
    func clearPlayerCardCells()
    func savePlayerLockedHostID(_ hostID: String)
    func loadPlayerLockedHostID() -> String?
    func clearPlayerLockedHostID()
    func savePlayerGameSessionID(_ sessionID: String)
    func loadPlayerGameSessionID() -> String?
    func savePlayerDrawnNumbers(_ numbers: [Int])
    func loadPlayerDrawnNumbers() -> [Int]
    func archivePlayerGameHistory(
        cardCells: [BingoCardCell],
        drawnNumbers: [Int],
        bingoLineCount: Int,
        reachLineCount: Int
    )
    func loadPlayerPastGameHistory() -> [PastPlayerGameRecord]
}

/// 本番環境用の永続化ストレージ実装（UserDefaults + Keychain 二重保護）。
struct DefaultBingoStorage: BingoStorageProviding {
    static let shared = DefaultBingoStorage()

    func saveActiveRole(_ role: String) { BingoStorage.saveActiveRole(role) }
    func loadActiveRole() -> String? { BingoStorage.loadActiveRole() }

    func saveHostDrawnNumbers(_ numbers: [Int]) { BingoStorage.saveHostDrawnNumbers(numbers) }
    func loadHostDrawnNumbers() -> [Int] { BingoStorage.loadHostDrawnNumbers() }
    func saveHostPlayerStatuses(_ statuses: [String: PlayerToHostPayload]) { BingoStorage.saveHostPlayerStatuses(statuses) }
    func loadHostPlayerStatuses() -> [String: PlayerToHostPayload] { BingoStorage.loadHostPlayerStatuses() }
    func saveHostRegisteredCards(_ cards: [String: [Int]]) { BingoStorage.saveHostRegisteredCards(cards) }
    func loadHostRegisteredCards() -> [String: [Int]] { BingoStorage.loadHostRegisteredCards() }
    func clearHostData() { BingoStorage.clearHostData() }
    func loadOrCreateHostID() -> String { BingoStorage.loadOrCreateHostID() }
    func loadOrCreateHostGameSessionID() -> String { BingoStorage.loadOrCreateHostGameSessionID() }
    @discardableResult func regenerateHostGameSessionID() -> String { BingoStorage.regenerateHostGameSessionID() }
    func saveHostSpinDurationMode(_ rawValue: String) { BingoStorage.saveHostSpinDurationMode(rawValue) }
    func loadHostSpinDurationMode() -> String? { BingoStorage.loadHostSpinDurationMode() }
    func archiveGameHistory(_ drawnNumbers: [Int], players: [PlayerToHostPayload]) {
        BingoStorage.archiveGameHistory(drawnNumbers, players: players)
    }
    func loadPastGameHistory() -> [PastGameRecord] { BingoStorage.loadPastGameHistory() }

    func loadOrCreatePlayerID() -> String { BingoStorage.loadOrCreatePlayerID() }
    func savePlayerCardCells(_ cells: [BingoCardCell]) { BingoStorage.savePlayerCardCells(cells) }
    func loadPlayerCardCells() -> [BingoCardCell]? { BingoStorage.loadPlayerCardCells() }
    func savePlayerIsAutoPunch(_ isAutoPunch: Bool) { BingoStorage.savePlayerIsAutoPunch(isAutoPunch) }
    func loadPlayerIsAutoPunch() -> Bool { BingoStorage.loadPlayerIsAutoPunch() }
    func savePlayerName(_ name: String) { BingoStorage.savePlayerName(name) }
    func loadPlayerName() -> String? { BingoStorage.loadPlayerName() }
    func clearPlayerCardCells() { BingoStorage.clearPlayerCardCells() }
    func savePlayerLockedHostID(_ hostID: String) { BingoStorage.savePlayerLockedHostID(hostID) }
    func loadPlayerLockedHostID() -> String? { BingoStorage.loadPlayerLockedHostID() }
    func clearPlayerLockedHostID() { BingoStorage.clearPlayerLockedHostID() }
    func savePlayerGameSessionID(_ sessionID: String) { BingoStorage.savePlayerGameSessionID(sessionID) }
    func loadPlayerGameSessionID() -> String? { BingoStorage.loadPlayerGameSessionID() }
    func savePlayerDrawnNumbers(_ numbers: [Int]) { BingoStorage.savePlayerDrawnNumbers(numbers) }
    func loadPlayerDrawnNumbers() -> [Int] { BingoStorage.loadPlayerDrawnNumbers() }
    func archivePlayerGameHistory(
        cardCells: [BingoCardCell],
        drawnNumbers: [Int],
        bingoLineCount: Int,
        reachLineCount: Int
    ) {
        BingoStorage.archivePlayerGameHistory(
            cardCells: cardCells,
            drawnNumbers: drawnNumbers,
            bingoLineCount: bingoLineCount,
            reachLineCount: reachLineCount
        )
    }
    func loadPlayerPastGameHistory() -> [PastPlayerGameRecord] { BingoStorage.loadPlayerPastGameHistory() }
}

enum BingoStorage {
    static let shared: BingoStorageProviding = DefaultBingoStorage.shared

    private static let keychainService = "com.naritamasayuki.bingomaster.anticheat"
    private static let maxHistoryCount = 20

    private static let activeRoleKey = "BingoMaster.activeRole"
    private static let hostIDKey = "BingoMaster.host.uniqueID"
    private static let hostDrawnNumbersKey = "BingoMaster.host.drawnNumbers"
    private static let hostPlayerStatusesKey = "BingoMaster.host.playerStatuses"
    private static let hostRegisteredCardsKey = "BingoMaster.host.registeredCards"
    private static let hostGameSessionIDKey = "BingoMaster.host.gameSessionID"
    private static let hostSpinDurationModeKey = "BingoMaster.host.spinDurationMode"
    private static let hostPastGameHistoryKey = "BingoMaster.host.pastGameHistory"

    private static let playerIDKey = "BingoMaster.player.uniqueID"
    private static let playerLockedHostIDKey = "BingoMaster.player.lockedHostID"
    private static let playerCardCellsKey = "BingoMaster.player.cardCells"
    private static let playerGameSessionIDKey = "BingoMaster.player.gameSessionID"
    private static let playerDrawnNumbersKey = "BingoMaster.player.drawnNumbers"
    private static let playerIsAutoPunchKey = "BingoMaster.player.isAutoPunch"
    private static let playerNameKey = "BingoMaster.player.playerName"
    private static let playerPastGameHistoryKey = "BingoMaster.player.pastGameHistory"

    /// DateFormatter の生成コストは高いため、一覧スクロール時のフレーム落ちを防ぐ目的で静的キャッシュして再利用する
    private static let japaneseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    static func formatJapaneseDate(_ date: Date) -> String {
        japaneseDateFormatter.string(from: date)
    }

    // MARK: - Generic JSON Storage Helpers (堅牢なエラーハンドリング＆ログ出力)

    private static func saveCodable<T: Encodable>(_ value: T, forKey key: String, mirrorToKeychain: Bool = false) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
            if mirrorToKeychain {
                saveToKeychain(data: data, account: key)
            }
        } catch {
            BingoLogger.logError(
                BingoLogger.storage,
                context: "JSONエンコード保存に失敗しました (key: \(key))",
                error: error
            )
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            BingoLogger.logError(
                BingoLogger.storage,
                context: "UserDefaultsからのJSONデコードに失敗しました (key: \(key))",
                error: error
            )
            return nil
        }
    }

    // MARK: - Active Role (アプリ強制終了時のモード自動復帰用)

    static func saveActiveRole(_ role: String) {
        UserDefaults.standard.set(role, forKey: activeRoleKey)
    }

    static func loadActiveRole() -> String? {
        UserDefaults.standard.string(forKey: activeRoleKey)
    }

    // MARK: - Keychain Helper (アプリ再インストールによる不正なカード引き直しを防ぐため Keychain にも二重保存する)

    private static func saveToKeychain(data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            BingoLogger.logWarning(
                BingoLogger.storage,
                context: "Keychain保存が非成功ステータスを返しました (account: \(account), OSStatus: \(status))"
            )
        }
    }

    private static func loadFromKeychain(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            BingoLogger.logWarning(
                BingoLogger.storage,
                context: "Keychain読み出し時に予期しないステータスが発生しました (account: \(account), OSStatus: \(status))"
            )
        }
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            BingoLogger.logWarning(
                BingoLogger.storage,
                context: "Keychain削除時に予期しないステータスが発生しました (account: \(account), OSStatus: \(status))"
            )
        }
    }

    // MARK: - Host Storage

    static func saveHostDrawnNumbers(_ numbers: [Int]) {
        saveCodable(numbers, forKey: hostDrawnNumbersKey)
    }

    static func loadHostDrawnNumbers() -> [Int] {
        loadCodable([Int].self, forKey: hostDrawnNumbersKey) ?? []
    }

    static func saveHostPlayerStatuses(_ statuses: [String: PlayerToHostPayload]) {
        saveCodable(statuses, forKey: hostPlayerStatusesKey)
    }

    static func loadHostPlayerStatuses() -> [String: PlayerToHostPayload] {
        loadCodable([String: PlayerToHostPayload].self, forKey: hostPlayerStatusesKey) ?? [:]
    }

    /// 参加者がゲーム途中でアプリを再インストールして有利なカードを引き直す不正を防ぐため、司会者側でも参加者の初期カードを台帳保存する
    static func saveHostRegisteredCards(_ cards: [String: [Int]]) {
        saveCodable(cards, forKey: hostRegisteredCardsKey)
    }

    static func loadHostRegisteredCards() -> [String: [Int]] {
        loadCodable([String: [Int]].self, forKey: hostRegisteredCardsKey) ?? [:]
    }

    static func clearHostData() {
        UserDefaults.standard.removeObject(forKey: hostDrawnNumbersKey)
        UserDefaults.standard.removeObject(forKey: hostPlayerStatusesKey)
        UserDefaults.standard.removeObject(forKey: hostRegisteredCardsKey)
    }

    static func loadOrCreateHostID() -> String {
        if let keychainData = loadFromKeychain(account: hostIDKey),
           let idString = String(data: keychainData, encoding: .utf8),
           !idString.isEmpty {
            UserDefaults.standard.set(idString, forKey: hostIDKey)
            return idString
        }
        if let existing = UserDefaults.standard.string(forKey: hostIDKey), !existing.isEmpty {
            if let data = existing.data(using: .utf8) {
                saveToKeychain(data: data, account: hostIDKey)
            }
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: hostIDKey)
        if let data = newID.data(using: .utf8) {
            saveToKeychain(data: data, account: hostIDKey)
        }
        return newID
    }

    static func loadOrCreateHostGameSessionID() -> String {
        if let existing = UserDefaults.standard.string(forKey: hostGameSessionIDKey), !existing.isEmpty {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: hostGameSessionIDKey)
        return newID
    }

    @discardableResult
    static func regenerateHostGameSessionID() -> String {
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: hostGameSessionIDKey)
        return newID
    }

    static func saveHostSpinDurationMode(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: hostSpinDurationModeKey)
    }

    static func loadHostSpinDurationMode() -> String? {
        UserDefaults.standard.string(forKey: hostSpinDurationModeKey)
    }

    static func archiveGameHistory(_ drawnNumbers: [Int], players: [PlayerToHostPayload]) {
        guard !drawnNumbers.isEmpty || !players.isEmpty else { return }
        var history = loadPastGameHistory()
        let sortedPlayers = players.sorted { $0.playerName < $1.playerName }
        let record = PastGameRecord(
            id: UUID(),
            savedAt: Date(),
            drawnNumbers: drawnNumbers,
            players: sortedPlayers
        )
        history.insert(record, at: 0)
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        saveCodable(history, forKey: hostPastGameHistoryKey)
    }

    static func loadPastGameHistory() -> [PastGameRecord] {
        loadCodable([PastGameRecord].self, forKey: hostPastGameHistoryKey) ?? []
    }

    // MARK: - Player Storage

    static func loadOrCreatePlayerID() -> String {
        if let keychainData = loadFromKeychain(account: playerIDKey),
           let idString = String(data: keychainData, encoding: .utf8),
           !idString.isEmpty {
            UserDefaults.standard.set(idString, forKey: playerIDKey)
            return idString
        }
        if let existing = UserDefaults.standard.string(forKey: playerIDKey), !existing.isEmpty {
            if let data = existing.data(using: .utf8) {
                saveToKeychain(data: data, account: playerIDKey)
            }
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: playerIDKey)
        if let data = newID.data(using: .utf8) {
            saveToKeychain(data: data, account: playerIDKey)
        }
        return newID
    }

    static func savePlayerCardCells(_ cells: [BingoCardCell]) {
        saveCodable(cells, forKey: playerCardCellsKey, mirrorToKeychain: true)
    }

    static func loadPlayerCardCells() -> [BingoCardCell]? {
        if let cells = loadCodable([BingoCardCell].self, forKey: playerCardCellsKey),
           cells.count == 25 {
            return cells
        }
        // アプリを削除・再インストールして UserDefaults を消去した場合でも Keychain から元のカードを復元し、不正な引き直しを防ぐ
        if let keychainData = loadFromKeychain(account: playerCardCellsKey) {
            do {
                let cells = try JSONDecoder().decode([BingoCardCell].self, from: keychainData)
                if cells.count == 25 {
                    UserDefaults.standard.set(keychainData, forKey: playerCardCellsKey)
                    BingoLogger.logInfo(BingoLogger.storage, message: "Keychainバックアップから参加者の5×5カードを復元しました")
                    return cells
                }
            } catch {
                BingoLogger.logError(
                    BingoLogger.storage,
                    context: "Keychain内の参加者カードデータのデコードに失敗しました",
                    error: error
                )
            }
        }
        return nil
    }

    static func savePlayerIsAutoPunch(_ isAutoPunch: Bool) {
        UserDefaults.standard.set(isAutoPunch, forKey: playerIsAutoPunchKey)
    }

    static func loadPlayerIsAutoPunch() -> Bool {
        UserDefaults.standard.bool(forKey: playerIsAutoPunchKey)
    }

    static func savePlayerName(_ name: String) {
        UserDefaults.standard.set(name, forKey: playerNameKey)
    }

    static func loadPlayerName() -> String? {
        UserDefaults.standard.string(forKey: playerNameKey)
    }

    static func clearPlayerCardCells() {
        UserDefaults.standard.removeObject(forKey: playerCardCellsKey)
        UserDefaults.standard.removeObject(forKey: playerDrawnNumbersKey)
        deleteFromKeychain(account: playerCardCellsKey)
        deleteFromKeychain(account: playerDrawnNumbersKey)
    }

    static func savePlayerLockedHostID(_ hostID: String) {
        UserDefaults.standard.set(hostID, forKey: playerLockedHostIDKey)
        if let data = hostID.data(using: .utf8) {
            saveToKeychain(data: data, account: playerLockedHostIDKey)
        }
    }

    static func loadPlayerLockedHostID() -> String? {
        if let existing = UserDefaults.standard.string(forKey: playerLockedHostIDKey), !existing.isEmpty {
            return existing
        }
        if let keychainData = loadFromKeychain(account: playerLockedHostIDKey),
           let hostID = String(data: keychainData, encoding: .utf8),
           !hostID.isEmpty {
            UserDefaults.standard.set(hostID, forKey: playerLockedHostIDKey)
            return hostID
        }
        return nil
    }

    static func clearPlayerLockedHostID() {
        UserDefaults.standard.removeObject(forKey: playerLockedHostIDKey)
        deleteFromKeychain(account: playerLockedHostIDKey)
    }

    static func savePlayerGameSessionID(_ sessionID: String) {
        UserDefaults.standard.set(sessionID, forKey: playerGameSessionIDKey)
        if let data = sessionID.data(using: .utf8) {
            saveToKeychain(data: data, account: playerGameSessionIDKey)
        }
    }

    static func loadPlayerGameSessionID() -> String? {
        if let existing = UserDefaults.standard.string(forKey: playerGameSessionIDKey), !existing.isEmpty {
            return existing
        }
        if let keychainData = loadFromKeychain(account: playerGameSessionIDKey),
           let sessionID = String(data: keychainData, encoding: .utf8),
           !sessionID.isEmpty {
            UserDefaults.standard.set(sessionID, forKey: playerGameSessionIDKey)
            return sessionID
        }
        return nil
    }

    static func savePlayerDrawnNumbers(_ numbers: [Int]) {
        saveCodable(numbers, forKey: playerDrawnNumbersKey, mirrorToKeychain: true)
    }

    static func loadPlayerDrawnNumbers() -> [Int] {
        if let numbers = loadCodable([Int].self, forKey: playerDrawnNumbersKey) {
            return numbers
        }
        if let keychainData = loadFromKeychain(account: playerDrawnNumbersKey) {
            do {
                return try JSONDecoder().decode([Int].self, from: keychainData)
            } catch {
                BingoLogger.logError(
                    BingoLogger.storage,
                    context: "Keychain内の出目配列デコードに失敗しました",
                    error: error
                )
            }
        }
        return []
    }

    static func archivePlayerGameHistory(
        cardCells: [BingoCardCell],
        drawnNumbers: [Int],
        bingoLineCount: Int,
        reachLineCount: Int
    ) {
        let punchedNonFreeCount = cardCells.filter { !$0.isFree && $0.isPunched }.count
        guard !drawnNumbers.isEmpty || punchedNonFreeCount > 0 else { return }

        var history = loadPlayerPastGameHistory()
        let record = PastPlayerGameRecord(
            id: UUID(),
            savedAt: Date(),
            cardCells: cardCells,
            drawnNumbers: drawnNumbers,
            bingoLineCount: bingoLineCount,
            reachLineCount: reachLineCount
        )
        history.insert(record, at: 0)
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        saveCodable(history, forKey: playerPastGameHistoryKey)
    }

    static func loadPlayerPastGameHistory() -> [PastPlayerGameRecord] {
        loadCodable([PastPlayerGameRecord].self, forKey: playerPastGameHistoryKey) ?? []
    }
}
