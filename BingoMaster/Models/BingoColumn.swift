import SwiftUI

enum BingoColumn: String, CaseIterable, Identifiable, Codable {
    case b = "B"
    case i = "I"
    case n = "N"
    case g = "G"
    case o = "O"

    var id: String { rawValue }

    /// 各列が担当する数値範囲
    var numberRange: ClosedRange<Int> {
        switch self {
        case .b: return 1...15
        case .i: return 16...30
        case .n: return 31...45
        case .g: return 46...60
        case .o: return 61...75
        }
    }

    /// 各列のテーマカラー
    /// - B列 (1〜15): ブルー (#1E88E5)
    /// - I列 (16〜30): ピンク (#E91E63)
    /// - N列 (31〜45): オレンジ (#FF9800)
    /// - G列 (46〜60): グリーン (#43A047)
    /// - O列 (61〜75): パープル (#8E24AA)
    var color: Color {
        switch self {
        case .b:
            return Color(red: 0x1E / 255.0, green: 0x88 / 255.0, blue: 0xE5 / 255.0)
        case .i:
            return Color(red: 0xE9 / 255.0, green: 0x1E / 255.0, blue: 0x63 / 255.0)
        case .n:
            return Color(red: 0xFF / 255.0, green: 0x98 / 255.0, blue: 0x00 / 255.0)
        case .g:
            return Color(red: 0x43 / 255.0, green: 0xA0 / 255.0, blue: 0x47 / 255.0)
        case .o:
            return Color(red: 0x8E / 255.0, green: 0x24 / 255.0, blue: 0xAA / 255.0)
        }
    }

    /// 数字 (1...75) に対応する BingoColumn を返す
    static func column(for number: Int) -> BingoColumn {
        switch number {
        case 1...15: return .b
        case 16...30: return .i
        case 31...45: return .n
        case 46...60: return .g
        case 61...75: return .o
        default: return .n
        }
    }
}
