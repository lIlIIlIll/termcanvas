package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PieceTableTextModelTest {
    @TestCase
    func localEditDoesNotScanOrCopyTheDocument(): Unit {
        let input = StringBuilder()
        for (_ in 0..100000) { input.append("alpha beta\n") }
        let model = PieceTableTextModel(text: input.toString())
        let middle = model.lineStart(50000)
        let before = model.metrics()
        model.replace(middle + 2, middle + 3, "XYZ")
        let after = model.metrics()
        @Expect(after.bytesScanned - before.bytesScanned <= 16)
        @Expect(after.bytesCopied - before.bytesCopied <= 16)
        @Expect(after.materializations, before.materializations)
        @Expect(after.nodeVisits - before.nodeVisits < 256)
        @Expect(model.lineCount(), 100001)
        @Expect(model.line(50000), "alXYZha beta")
        @Expect(model.lineStart(50001), middle + 13)
        let beforeHistory = model.metrics()
        @Expect(model.undo())
        let afterUndo = model.metrics()
        @Expect(afterUndo.bytesCopied, beforeHistory.bytesCopied)
        @Expect(afterUndo.bytesScanned, beforeHistory.bytesScanned)
        @Expect(afterUndo.materializations, beforeHistory.materializations)
        @Expect(model.line(50000), "alpha beta")
        @Expect(model.redo())
        @Expect(model.line(50000), "alXYZha beta")
    }

    @TestCase
    func appendHistoryAndLargeDeletionKeepBalancedSharedPieces(): Unit {
        let model = PieceTableTextModel()
        for (_ in 0..4096) {
            let before = model.metrics()
            model.replace(model.byteLength(), model.byteLength(), "x\n")
            let after = model.metrics()
            @Expect(after.bytesScanned - before.bytesScanned, 2)
            @Expect(after.bytesCopied, before.bytesCopied)
            @Expect(after.nodeVisits - before.nodeVisits < 128)
        }
        @Expect(model.byteLength(), 8192)
        @Expect(model.lineCount(), 4097)
        @Expect(model.metrics().pieceCount, 4096)
        @Expect(model.metrics().treeHeight < 16)
        @Expect(model.lineStart(4000), 8000)
        let before = model.metrics()
        model.replace(2, 8190, "")
        let after = model.metrics()
        @Expect(after.bytesCopied, before.bytesCopied)
        @Expect(after.bytesScanned - before.bytesScanned <= 2)
        @Expect(after.nodeVisits - before.nodeVisits < 128)
        @Expect(model.text(), "x\nx\n")
        @Expect(model.undo())
        @Expect(model.lineCount(), 4097)
        @Expect(model.metrics().treeHeight < 16)
        @Expect(model.undo())
        @Expect(model.byteLength(), 8190)
        @Expect(model.lineCount(), 4096)
        @Expect(model.redo())
        @Expect(model.byteLength(), 8192)
    }

    @TestCase
    func reversedAndEmptyEditsPreserveHistoryAtUtf8Boundaries(): Unit {
        let model = PieceTableTextModel(text: "é😀x")
        @Expect(model.clampOffset(-1), 0)
        @Expect(model.clampOffset(1), 0)
        @Expect(model.clampOffset(5), 2)
        @Expect(model.clampOffset(Int64.Max), 7)
        @Expect(model.slice(1, 5), "é")
        model.replace(6, 2, "中")
        @Expect(model.text(), "é中x")
        @Expect(model.undo())
        let revision = model.revision()
        model.beginUndoGroup()
        model.replace(5, 3, "")
        model.endUndoGroup()
        @Expect(model.revision(), revision)
        @Expect(model.redo())
        @Expect(model.text(), "é中x")
        model.beginUndoGroup()
        model.replace(0, 0, "!")
        @Expect(model.undo())
        @Expect(model.text(), "é中x")
        model.endUndoGroup()
        @Expect(model.redo())
        @Expect(model.text(), "!é中x")
    }

    @TestCase
    func indexesAndUtf8BoundariesRemainCorrectAfterSplices(): Unit {
        let model = PieceTableTextModel(text: "a\n中文\n")
        @Expect(model.lineCount(), 3)
        @Expect(model.lineStart(1), 2)
        @Expect(model.lineStart(2), 9)
        @Expect(model.lineStart(Int64.Max), 9)
        @Expect(model.lineForOffset(1), 0)
        @Expect(model.lineForOffset(2), 1)
        @Expect(model.lineForOffset(8), 1)
        @Expect(model.lineForOffset(9), 2)
        @Expect(model.clampOffset(4), 2)
        model.replace(4, 6, "x\ny")
        @Expect(model.text(), "a\nx\ny文\n")
        @Expect(model.lineCount(), 4)
        @Expect(model.line(2), "y文")
        @Expect(model.lineForOffset(6), 2)
        @Expect(model.slice(8, 4), "y文")
        model.replace(Int64.Min, Int64.Max, "")
        @Expect(model.text(), "")
        @Expect(model.lineCount(), 1)
        @Expect(model.line(0), "")
        @Expect(model.lineStart(1), 0)
    }

    @TestCase
    func transactionsRetainRootsAndNoOpsPreserveRedo(): Unit {
        let model = PieceTableTextModel(text: "abc")
        model.beginUndoGroup()
        model.replace(1, 1, "1")
        model.beginUndoGroup()
        model.replace(2, 2, "2")
        model.endUndoGroup()
        model.replace(3, 3, "3")
        model.endUndoGroup()
        @Expect(model.text(), "a123bc")
        @Expect(model.undo())
        @Expect(model.text(), "abc")
        @Expect(!model.undo())
        let revision = model.revision()
        model.replace(0, 3, "abc")
        @Expect(model.revision(), revision)
        @Expect(model.redo())
        @Expect(model.text(), "a123bc")
        model.clearHistory()
        @Expect(!model.undo())
        @Expect(!model.redo())
    }

    @TestCase
    func repeatedSplicesStayBalancedAndMatchAStringOracle(): Unit {
        let model = PieceTableTextModel(text: "begin\nend")
        var expected = "begin\nend"
        for (step in 0..1200) {
            let offset = (step * 97 + 3) % (expected.size + 1)
            let inserted = if (step % 7 == 0) { "\nx" } else { "z" }
            let end = min(expected.size, offset + step % 3)
            model.replace(offset, end, inserted)
            expected = expected[..offset] + inserted + expected[end..]
            if (step % 37 == 0) {
                @Expect(model.text(), expected)
                let lines = splitLines(expected)
                @Expect(model.lineCount(), lines.size)
                var start: Int64 = 0
                for (index in 0..lines.size) {
                    @Expect(model.line(index), lines[index])
                    @Expect(model.lineStart(index), start)
                    @Expect(model.lineForOffset(start), index)
                    start += lines[index].size + 1
                }
                @Expect(model.metrics().treeHeight < 32)
            }
        }
        @Expect(model.text(), expected)
    }
}
