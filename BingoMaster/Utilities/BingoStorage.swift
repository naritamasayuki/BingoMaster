import Foundation

struct PastGameRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let savedAt: Date
    let drawnNumbers: [Int]

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: savedAt)
    }
}

enum BingoStorage {
    private static let hostDrawnNumbersKey = "BingoMaster.host.drawnNumbers"
    private static let hostSpinDurationModeKey = "BingoMaster.host.spinDurationMode"
    private static let hostPastGameHistoryKey = "BingoMaster.host.pastGameHistory"
    private static let playerCardCellsKey = "BingoMaster.player.cardCells"
    private static let playerIsAutoPunchKey = "BingoMaster.player.isAutoPunch"
    private static let playerNameKey = "BingoMaster.player.playerName"

    // MARK: - Host Storage (進行中の出目履歴＆過去ゲーム履歴の自動保存)

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

    static func clearHostData() {
        UserDefaults.standard.removeObject(forKey: hostDrawnNumbersKey)
        UserDefaults.standard.synchronize()
    }

    static func saveHostSpinDurationMode(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: hostSpinDurationModeKey)
        UserDefaults.standard.synchronize()
    }

    static func loadHostSpinDurationMode() -> String? {
        return UserDefaults.standard.string(forKey: hostSpinDurationModeKey)
    }

    /// ゲーム履歴をアーカイブとして自動保存（最新20件まで保持）
    static func archiveGameHistory(_ drawnNumbers: [Int]) {
        guard !drawnNumbers.isEmpty else { return }
        var history = loadPastGameHistory()
        let record = PastGameRecord(id: UUID(), savedAt: Date(), drawnNumbers: drawnNumbers)
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

    // MARK: - Player Storage

    static func savePlayerCardCells(_ cells: [BingoCardCell]) {
        if let data = try? JSONEncoder().encode(cells) {
            UserDefaults.standard.set(data, forKey: playerCardCellsKey)
            UserDefaults.standard.synchronize()
        }
    }

    static func loadPlayerCardCells() -> [BingoCardCell]? {
        guard let data = UserDefaults.standard.data(forKey: playerCardCellsKey),
              let cells = try? JSONDecoder().decode([BingoCardCell].self, from: data),
              cells.count == 25 else {
            return nil
        }
        return cells
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
        UserDefaults.standard.synchronize()
    }
}
