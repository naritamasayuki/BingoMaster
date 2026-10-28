import Foundation

struct BingoCardCell: Identifiable, Codable, Equatable {
    var id: Int               // 0〜24 のインデックス (12が中央FREEマス)
    var number: Int           // 1〜75 (FREEマスは 0)
    var isFree: Bool          // 中央マスのみ true
    var isDrawn: Bool         // 司会者がすでに引いた数字か？
    var isPunched: Bool       // 参加者が穴を開けたか？（初期値は isFree と同じ）
    
    /// 手動タップモード時に「出た数字だがまだ開けていない」ハイライト対象か判定
    var shouldHighlight: Bool {
        return isDrawn && !isPunched && !isFree
    }
}
