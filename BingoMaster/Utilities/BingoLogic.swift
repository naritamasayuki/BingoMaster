import Foundation

struct BingoEvaluationResult: Equatable {
    let status: PlayerToHostPayload.PlayerStatus
    let bingoLineCount: Int
    let reachLineCount: Int
    let bingoCellIDs: Set<Int>
    let reachCellIDs: Set<Int>
}

enum BingoLogic {
    /// 縦5列・横5行・斜め2本の計12ラインのインデックス定義 (0〜24)
    static let allLines: [[Int]] = [
        // 横5行
        [0, 1, 2, 3, 4],
        [5, 6, 7, 8, 9],
        [10, 11, 12, 13, 14],
        [15, 16, 17, 18, 19],
        [20, 21, 22, 23, 24],
        // 縦5列
        [0, 5, 10, 15, 20],
        [1, 6, 11, 16, 21],
        [2, 7, 12, 17, 22],
        [3, 8, 13, 18, 23],
        [4, 9, 14, 19, 24],
        // 斜め2本
        [0, 6, 12, 18, 24],
        [4, 8, 12, 16, 20]
    ]

    static let columnRanges: [ClosedRange<Int>] = [
        1...15,
        16...30,
        31...45,
        46...60,
        61...75
    ]

    /// 5×5 のビンゴカード（25マス）を生成する
    /// - Col 0 (B): 1...15 から重複なし5個
    /// - Col 1 (I): 16...30 から重複なし5個
    /// - Col 2 (N): 31...45 から重複なし5個（中央 index = 12 は number = 0, isFree = true, isPunched = true）
    /// - Col 3 (G): 46...60 から重複なし5個
    /// - Col 4 (O): 61...75 から重複なし5個
    static func generateCard() -> [BingoCardCell] {
        // 各列ごとにシャッフルした5個の数字を用意
        let columnNumbers: [[Int]] = columnRanges.map { range in
            Array(range.shuffled().prefix(5))
        }

        var cells: [BingoCardCell] = []
        cells.reserveCapacity(25)

        for row in 0..<5 {
            for col in 0..<5 {
                let index = row * 5 + col
                if index == 12 {
                    cells.append(
                        BingoCardCell(
                            id: index,
                            number: 0,
                            isFree: true,
                            isDrawn: true,
                            isPunched: true
                        )
                    )
                } else {
                    let number = columnNumbers[col][row]
                    cells.append(
                        BingoCardCell(
                            id: index,
                            number: number,
                            isFree: false,
                            isDrawn: false,
                            isPunched: false
                        )
                    )
                }
            }
        }

        return cells
    }

    /// 参加者の5×5カード数字配列（25個）が正規のBINGOルール（列ごとの範囲・重複なし・中央FREE）に適合しているか検証（改ざんカード防止）
    static func isValidCardNumbers(_ numbers: [Int]) -> Bool {
        guard numbers.count == 25 else { return false }
        var seenNumbers = Set<Int>()

        for index in 0..<25 {
            let col = index % 5
            let num = numbers[index]
            if index == 12 {
                if num != 0 { return false }
                continue
            }
            guard columnRanges[col].contains(num) else { return false }
            if seenNumbers.contains(num) { return false }
            seenNumbers.insert(num)
        }
        return true
    }

    /// 司会者側での検算用：参加者のロック済み25マス数字と「司会者が実際に引いた出目」を照合し、正当な穴あけ状態のみを反映した25マスを復元する
    static func reconstructVerifiedCells(
        cardNumbers: [Int],
        punchedIndices: Set<Int>,
        hostDrawnNumbers: [Int]
    ) -> [BingoCardCell] {
        guard cardNumbers.count == 25 else { return [] }
        let drawnSet = Set(hostDrawnNumbers)
        return cardNumbers.enumerated().map { index, num in
            let isFree = (index == 12 || num == 0)
            let isDrawn = isFree || drawnSet.contains(num)
            // 司会者がまだ引いていない数字は、万が一参加者が穴あけ申告してきても絶対に isPunched = false とする
            let isPunched = isFree || (isDrawn && punchedIndices.contains(index))
            return BingoCardCell(
                id: index,
                number: isFree ? 0 : num,
                isFree: isFree,
                isDrawn: isDrawn,
                isPunched: isPunched
            )
        }
    }

    /// 司会者側での理論値検算用：手動タップ忘れ・温存を含め、司会者が引いた出目をすべて開けた場合の25マスを復元する
    static func reconstructTheoreticalCells(
        cardNumbers: [Int],
        hostDrawnNumbers: [Int]
    ) -> [BingoCardCell] {
        guard cardNumbers.count == 25 else { return [] }
        let drawnSet = Set(hostDrawnNumbers)
        return cardNumbers.enumerated().map { index, num in
            let isFree = (index == 12 || num == 0)
            let isDrawn = isFree || drawnSet.contains(num)
            return BingoCardCell(
                id: index,
                number: isFree ? 0 : num,
                isFree: isFree,
                isDrawn: isDrawn,
                isPunched: isDrawn
            )
        }
    }

    /// 25マスの状態から縦・横・斜め12ラインを走査し、リーチ・ビンゴ判定を行う
    static func evaluate(cells: [BingoCardCell]) -> BingoEvaluationResult {
        guard cells.count == 25 else {
            return BingoEvaluationResult(
                status: .normal,
                bingoLineCount: 0,
                reachLineCount: 0,
                bingoCellIDs: [],
                reachCellIDs: []
            )
        }

        var bingoCount = 0
        var reachCount = 0
        var bingoIDs = Set<Int>()
        var reachIDs = Set<Int>()

        for line in allLines {
            let punchedInLine = line.filter { cells[$0].isPunched }
            if punchedInLine.count == 5 {
                bingoCount += 1
                bingoIDs.formUnion(line)
            } else if punchedInLine.count == 4 {
                reachCount += 1
                reachIDs.formUnion(line)
            }
        }

        let status: PlayerToHostPayload.PlayerStatus
        if bingoCount > 0 {
            status = .bingo
        } else if reachCount > 0 {
            status = .reach
        } else {
            status = .normal
        }

        return BingoEvaluationResult(
            status: status,
            bingoLineCount: bingoCount,
            reachLineCount: reachCount,
            bingoCellIDs: bingoIDs,
            reachCellIDs: reachIDs
        )
    }
}
