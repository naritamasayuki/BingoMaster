import Foundation

enum BingoStorage {
    private static let hostDrawnNumbersKey = "BingoMaster.host.drawnNumbers"
    private static let playerCardCellsKey = "BingoMaster.player.cardCells"
    private static let playerIsAutoPunchKey = "BingoMaster.player.isAutoPunch"
    private static let playerNameKey = "BingoMaster.player.playerName"

    // MARK: - Host Storage

    static func saveHostDrawnNumbers(_ numbers: [Int]) {
        if let data = try? JSONEncoder().encode(numbers) {
            UserDefaults.standard.set(data, forKey: hostDrawnNumbersKey)
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
    }

    // MARK: - Player Storage

    static func savePlayerCardCells(_ cells: [BingoCardCell]) {
        if let data = try? JSONEncoder().encode(cells) {
            UserDefaults.standard.set(data, forKey: playerCardCellsKey)
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
    }

    static func loadPlayerIsAutoPunch() -> Bool {
        return UserDefaults.standard.bool(forKey: playerIsAutoPunchKey)
    }

    static func savePlayerName(_ name: String) {
        UserDefaults.standard.set(name, forKey: playerNameKey)
    }

    static func loadPlayerName() -> String? {
        return UserDefaults.standard.string(forKey: playerNameKey)
    }

    static func clearPlayerCardCells() {
        UserDefaults.standard.removeObject(forKey: playerCardCellsKey)
    }
}
