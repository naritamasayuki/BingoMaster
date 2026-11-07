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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: savedAt)
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: savedAt)
    }
}

enum BingoStorage {
    private static let keychainService = "com.naritamasayuki.bingomaster.anticheat"

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

    // MARK: - Active Role (アプリ強制終了時のモード自動復帰用)

    static func saveActiveRole(_ role: String) {
        UserDefaults.standard.set(role, forKey: activeRoleKey)
        UserDefaults.standard.synchronize()
    }

    static func loadActiveRole() -> String? {
        return UserDefaults.standard.string(forKey: activeRoleKey)
    }

    // MARK: - Keychain Helper (アプリを落としても・再インストールしても消えない不正防止領域)

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
        SecItemAdd(addQuery as CFDictionary, nil)
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
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Host Storage (進行中の出目履歴・参加者一覧・参加者カード台帳の自動保存)

    static func saveHostDrawnNumbers(_ numbers: [Int]) {
        if let data = try? JSONEncoder().encode(numbers) {
            UserDefaults.standard.set(data, forKey: hostDrawnNumbersKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadHostDrawnNumbers() -> [Int] {
        guard let data = UserDefaults.standard.data(forKey: hostDrawnNumbersKey),
              let numbers = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return numbers
    }

    /// 司会者側で把握している参加者一覧＆ステータス（リーチ・ビンゴ・参加中）を自動保存
    static func saveHostPlayerStatuses(_ statuses: [String: PlayerToHostPayload]) {
        if let data = try? JSONEncoder().encode(statuses) {
            UserDefaults.standard.set(data, forKey: hostPlayerStatusesKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadHostPlayerStatuses() -> [String: PlayerToHostPayload] {
        guard let data = UserDefaults.standard.data(forKey: hostPlayerStatusesKey),
              let statuses = try? JSONDecoder().decode([String: PlayerToHostPayload].self, from: data) else {
            return [:]
        }
        return statuses
    }

    /// 司会者側でロック保存する「参加者ごとの5×5カード数字配列（不正引き直し防止台帳）」
    static func saveHostRegisteredCards(_ cards: [String: [Int]]) {
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: hostRegisteredCardsKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadHostRegisteredCards() -> [String: [Int]] {
        guard let data = UserDefaults.standard.data(forKey: hostRegisteredCardsKey),
              let cards = try? JSONDecoder().decode([String: [Int]].self, from: data) else {
            return [:]
        }
        return cards
    }

    static func clearHostData() {
        UserDefaults.standard.removeObject(forKey: hostDrawnNumbersKey)
        UserDefaults.standard.removeObject(forKey: hostPlayerStatusesKey)
        UserDefaults.standard.removeObject(forKey: hostRegisteredCardsKey)
        UserDefaults.standard.synchronize()
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
        UserDefaults.standard.synchronize()
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
        UserDefaults.standard.synchronize()
        return newID
    }

    @discardableResult
    static func regenerateHostGameSessionID() -> String {
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: hostGameSessionIDKey)
        UserDefaults.standard.synchronize()
        return newID
    }

    static func saveHostSpinDurationMode(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: hostSpinDurationModeKey)
        UserDefaults.standard.synchronize()
    }

    static func loadHostSpinDurationMode() -> String? {
        return UserDefaults.standard.string(forKey: hostSpinDurationModeKey)
    }

    /// ゲーム履歴（出目＋参加者一覧）をアーカイブとして自動保存（最新20件まで保持）
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
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: hostPastGameHistoryKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadPastGameHistory() -> [PastGameRecord] {
        guard let data = UserDefaults.standard.data(forKey: hostPastGameHistoryKey),
              let history = try? JSONDecoder().decode([PastGameRecord].self, from: data) else {
            return []
        }
        return history
    }

    // MARK: - Player Storage (UserDefaults + Keychain 二重ロック保存でアプリ強制終了・再インストール時の不正を防止)

    /// 参加者端末の固有IDを取得（Keychainにも保存するためアプリ削除・再起動でも不変）
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
        UserDefaults.standard.synchronize()
        if let data = newID.data(using: .utf8) {
            saveToKeychain(data: data, account: playerIDKey)
        }
        return newID
    }

    /// 参加者の5×5カードを UserDefaults と Keychain の両方に即時自動保存（アプリを落としても絶対に変わらない）
    static func savePlayerCardCells(_ cells: [BingoCardCell]) {
        if let data = try? JSONEncoder().encode(cells) {
            UserDefaults.standard.set(data, forKey: playerCardCellsKey)
            UserDefaults.standard.synchronize()
            saveToKeychain(data: data, account: playerCardCellsKey)
        }
    }

    static func loadPlayerCardCells() -> [BingoCardCell]? {
        if let data = UserDefaults.standard.data(forKey: playerCardCellsKey),
           let cells = try? JSONDecoder().decode([BingoCardCell].self, from: data),
           cells.count == 25 {
            return cells
        }
        // UserDefaults が消去されていた場合でも Keychain から強制復元（不正防止）
        if let keychainData = loadFromKeychain(account: playerCardCellsKey),
           let cells = try? JSONDecoder().decode([BingoCardCell].self, from: keychainData),
           cells.count == 25 {
            UserDefaults.standard.set(keychainData, forKey: playerCardCellsKey)
            UserDefaults.standard.synchronize()
            return cells
        }
        return nil
    }

    static func savePlayerIsAutoPunch(_ isAutoPunch: Bool) {
        UserDefaults.standard.set(isAutoPunch, forKey: playerIsAutoPunchKey)
        UserDefaults.standard.synchronize()
    }

    static func loadPlayerIsAutoPunch() -> Bool {
        return UserDefaults.standard.bool(forKey: playerIsAutoPunchKey)
    }

    static func savePlayerName(_ name: String) {
        UserDefaults.standard.set(name, forKey: playerNameKey)
        UserDefaults.standard.synchronize()
    }

    static func loadPlayerName() -> String? {
        return UserDefaults.standard.string(forKey: playerNameKey)
    }

    static func clearPlayerCardCells() {
        UserDefaults.standard.removeObject(forKey: playerCardCellsKey)
        UserDefaults.standard.removeObject(forKey: playerDrawnNumbersKey)
        UserDefaults.standard.synchronize()
        deleteFromKeychain(account: playerCardCellsKey)
        deleteFromKeychain(account: playerDrawnNumbersKey)
    }

    static func savePlayerLockedHostID(_ hostID: String) {
        UserDefaults.standard.set(hostID, forKey: playerLockedHostIDKey)
        UserDefaults.standard.synchronize()
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
        UserDefaults.standard.synchronize()
        deleteFromKeychain(account: playerLockedHostIDKey)
    }

    static func savePlayerGameSessionID(_ sessionID: String) {
        UserDefaults.standard.set(sessionID, forKey: playerGameSessionIDKey)
        UserDefaults.standard.synchronize()
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
        if let data = try? JSONEncoder().encode(numbers) {
            UserDefaults.standard.set(data, forKey: playerDrawnNumbersKey)
            UserDefaults.standard.synchronize()
            saveToKeychain(data: data, account: playerDrawnNumbersKey)
        }
    }

    static func loadPlayerDrawnNumbers() -> [Int] {
        if let data = UserDefaults.standard.data(forKey: playerDrawnNumbersKey),
           let numbers = try? JSONDecoder().decode([Int].self, from: data) {
            return numbers
        }
        if let keychainData = loadFromKeychain(account: playerDrawnNumbersKey),
           let numbers = try? JSONDecoder().decode([Int].self, from: keychainData) {
            return numbers
        }
        return []
    }

    /// 参加者側のゲーム結果・カード履歴を自動アーカイブ保存（最新20件まで保持）
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
        if history.count > 20 {
            history = Array(history.prefix(20))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: playerPastGameHistoryKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadPlayerPastGameHistory() -> [PastPlayerGameRecord] {
        guard let data = UserDefaults.standard.data(forKey: playerPastGameHistoryKey),
              let history = try? JSONDecoder().decode([PastPlayerGameRecord].self, from: data) else {
            return []
        }
        return history
    }
}
