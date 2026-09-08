package core

import std.unittest.*
import std.unittest.testmacro.*

private func round2InputBuffersEqual(left: Buffer, right: Buffer): Bool {
    if (left.area != right.area) { return false }
    for (y in left.area.y..left.area.bottom) {
        for (x in left.area.x..left.area.right) {
            if (left.getCell(x, y) != right.getCell(x, y)) { return false }
        }
    }
    true
}

private func round2InputWidePairsValid(buffer: Buffer): Bool {
    for (y in buffer.area.y..buffer.area.bottom) {
        for (x in buffer.area.x..buffer.area.right) {
            let cell = buffer.getCell(x, y)
            match (cell.kind) {
                case CellKind.WideLead =>
                    if (x + 1 >= buffer.area.right) { return false }
                    match (buffer.getCell(x + 1, y).kind) {
                        case CellKind.WideCont => ()
                        case _ => return false
                    }
                case CellKind.WideCont =>
                    if (x == buffer.area.x) { return false }
                    match (buffer.getCell(x - 1, y).kind) {
                        case CellKind.WideLead => ()
                        case _ => return false
                    }
                case CellKind.Normal => ()
            }
        }
    }
    true
}

@Test
class AuditInputRound2Test {
    @TestCase
    func shiftedWideTextRepairsBothOldPairsAcrossPublicWriters(): Unit {
        let area = Rect(0, 0, 6, 1)
        for (symbol in ["中", "🙂"]) {
            for (oldX in [0, 1]) {
                let newX = 1 - oldX
                let before = Buffer(area)
                before.setString(oldX, 0, "界")
                before.setString(5, 0, "z")
                let expected = Buffer(area)
                expected.setString(newX, 0, symbol)
                expected.setString(5, 0, "z")
                for (writer in [0, 1, 2]) {
                    let actual = before.copy()
                    if (writer == 0) { actual.setString(newX, 0, symbol) }
                    else if (writer == 1) { Canvas(actual, area).drawText(newX, 0, symbol, Style.default()) }
                    else {
                        let source = Buffer(Rect(0, 0, 2, 1))
                        source.setString(0, 0, symbol)
                        actual.blitFrom(source, source.area, newX, 0)
                    }
                    @Expect(round2InputWidePairsValid(actual))
                    @Expect(round2InputBuffersEqual(actual, expected))
                    @Expect(actual.diff(expected).size, 0)
                }
            }
        }
        let both = Buffer(area)
        both.setString(0, 0, "界界")
        both.setString(1, 0, "🙂")
        @Expect(round2InputWidePairsValid(both))
        @Expect(both.getCell(0, 0), Cell())
        @Expect(both.getCell(3, 0), Cell())
        @Expect(both.getCell(1, 0).symbol, "🙂")
    }

    @TestCase
    func shiftedWideTextHonorsTheWholeCanvasRepairBoundary(): Unit {
        let area = Rect(0, 0, 5, 1)
        for (oldX in [0, 1]) {
            let newX = 1 - oldX
            let actual = Buffer(area)
            actual.setString(oldX, 0, "界")
            let before = actual.copy()
            Canvas(actual, Rect(newX, 0, 2, 1)).drawText(newX, 0, "🙂", Style.default())
            @Expect(round2InputBuffersEqual(actual, before))
            @Expect(round2InputWidePairsValid(actual))
            Canvas(actual, Rect(0, 0, 3, 1)).drawText(newX, 0, "🙂", Style.default())
            let expected = Buffer(area)
            expected.setString(newX, 0, "🙂")
            @Expect(round2InputBuffersEqual(actual, expected))
            @Expect(round2InputWidePairsValid(actual))
        }
    }

    @TestCase
    func partialAndFullFramesAgreeAfterLayeredWideOverwrites(): Unit {
        let area = Rect(0, 0, 8, 2)
        let partialBackend = TestBackend(area: area, captureSnapshots: false)
        let fullBackend = TestBackend(area: area, captureSnapshots: false)
        let partial = Terminal(partialBackend, renderMode: RenderMode.Diff)
        let full = Terminal(fullBackend, renderMode: RenderMode.Full)
        _ = partial.draw { frame => frame.canvas().drawText(1, 0, "界", Style.default()) }
        _ = full.draw { frame => frame.canvas().drawText(1, 0, "界", Style.default()) }
        let dirty = DirtyRects()
        dirty.add(Rect(0, 0, 3, 1))
        let draw: (Frame) -> Unit = { frame =>
            frame.canvas().drawText(1, 0, "界", Style.default())
            frame.canvas().drawText(0, 0, "🙂", Style.default())
        }
        _ = partial.draw(draw, dirtyRects: Some(dirty))
        _ = full.draw(draw)
        match ((partialBackend.lastBuffer(), fullBackend.lastBuffer())) {
            case (Some(actual), Some(expected)) =>
                @Expect(round2InputBuffersEqual(actual, expected))
                @Expect(round2InputWidePairsValid(actual))
                @Expect(round2InputWidePairsValid(expected))
                @Expect(actual.getCell(2, 0), Cell())
            case _ => @Expect(false)
        }
    }

    @TestCase
    func overlappingSelectionsDeleteTheirUnionInEitherOrder(): Unit {
        for (key in [KeyCode.Delete, KeyCode.Backspace]) {
            for (reverse in [false, true]) {
                let editor = TextArea(value: "abcdef")
                let left = TextAreaCaret(4, anchor: Some(1))
                let right = TextAreaCaret(3, anchor: Some(5))
                let carets = if (reverse) { [right, left] } else { [left, right] }
                editor.setCarets(carets)
                @Expect(editor.handle(KeyEvent(key)))
                @Expect(editor.value, "af")
                @Assert(editor.carets().size, 1)
                @Expect(editor.carets()[0].offset, 1)
                @Expect(editor.undo())
                @Expect(editor.value, "abcdef")
                @Assert(editor.carets().size, 2)
                @Expect(editor.carets()[0].offset, carets[0].offset)
                @Expect(editor.carets()[0].anchor, carets[0].anchor)
                @Expect(editor.carets()[1].offset, carets[1].offset)
                @Expect(editor.carets()[1].anchor, carets[1].anchor)
                @Expect(editor.redo())
                @Expect(editor.value, "af")
                @Expect(editor.carets().size, 1)
            }
        }
    }

    @TestCase
    func nestedAndDisjointDeletionsKeepUnselectedText(): Unit {
        for (key in [KeyCode.Delete, KeyCode.Backspace]) {
            let nested = TextArea(value: "abcdef")
            nested.setCarets([TextAreaCaret(4, anchor: Some(2)), TextAreaCaret(1, anchor: Some(5))])
            @Expect(nested.handle(KeyEvent(key)))
            @Expect(nested.value, "af")
            @Expect(nested.carets().size, 1)
            let disjoint = TextArea(value: "abcdef")
            disjoint.setCarets([TextAreaCaret(1, anchor: Some(3)), TextAreaCaret(5, anchor: Some(4))])
            @Expect(disjoint.handle(KeyEvent(key)))
            @Expect(disjoint.value, "adf")
            @Assert(disjoint.carets().size, 2)
            @Expect(disjoint.carets()[0].offset, 1)
            @Expect(disjoint.carets()[1].offset, 2)
        }
    }

    @TestCase
    func unicodeMultilineOverlapIsOneEditAndOneUndo(): Unit {
        let value = "A中\ne\u{0301}🙂Z"
        for (key in [KeyCode.Delete, KeyCode.Backspace]) {
            let editor = TextArea(value: value)
            editor.setCarets([TextAreaCaret(8, anchor: Some(1)), TextAreaCaret(5, anchor: Some(12))])
            @Expect(editor.handle(KeyEvent(key)))
            @Expect(editor.value, "AZ")
            @Assert(editor.carets().size, 1)
            @Expect(editor.carets()[0].offset, 1)
            @Expect(editor.undo())
            @Expect(editor.value, value)
            @Expect(!editor.undo())
            @Expect(editor.redo())
            @Expect(editor.value, "AZ")
        }
    }

    @TestCase
    func overlappingReplacementIsInsertedOnceAndRetainsThePrimaryCaret(): Unit {
        for (reverse in [false, true]) {
            let editor = TextArea(value: "abcdef")
            let left = TextAreaCaret(1, anchor: Some(4))
            let right = TextAreaCaret(5, anchor: Some(3))
            editor.setCarets(if (reverse) { [right, left] } else { [left, right] })
            editor.paste("🙂")
            @Expect(editor.value, "a🙂f")
            @Assert(editor.carets().size, 1)
            @Expect(editor.carets()[0].offset, 5)
            @Expect(editor.handle(KeyEvent(KeyCode.Char(r'x'))))
            @Expect(editor.value, "a🙂xf")
            @Expect(editor.undo())
            @Expect(editor.value, "a🙂f")
            @Expect(editor.undo())
            @Expect(editor.value, "abcdef")
            @Expect(editor.carets().size, 2)
        }
    }

    @TestCase
    func enclosingSelectionMergesMultiplePreviouslyDisjointEdits(): Unit {
        for (replacement in ["", "x"]) {
            let editor = TextArea(value: "abcdefgh")
            editor.setCarets([TextAreaCaret(6, anchor: Some(5)), TextAreaCaret(3, anchor: Some(4)),
                TextAreaCaret(7, anchor: Some(1))])
            if (replacement.isEmpty()) { _ = editor.handle(KeyEvent(KeyCode.Delete)) }
            else { editor.paste(replacement) }
            @Expect(editor.value, "a${replacement}h")
            @Assert(editor.carets().size, 1)
            @Expect(editor.carets()[0].offset, 1 + replacement.size)
            @Expect(editor.undo())
            @Expect(editor.value, "abcdefgh")
            @Assert(editor.carets().size, 3)
            @Expect(editor.carets()[0].offset, 6)
        }
    }

    @TestCase
    func caretInsideASelectionDoesNotDuplicateTheReplacement(): Unit {
        for (reverse in [false, true]) {
            let editor = TextArea(value: "abcdef")
            let selection = TextAreaCaret(5, anchor: Some(1))
            let insertion = TextAreaCaret(3)
            editor.setCarets(if (reverse) { [insertion, selection] } else { [selection, insertion] })
            editor.paste("x")
            @Expect(editor.value, "axf")
            @Assert(editor.carets().size, 1)
            @Expect(editor.carets()[0].offset, 2)
            @Expect(editor.handle(KeyEvent(KeyCode.Char(r'y'))))
            @Expect(editor.value, "axyf")
        }
    }

    @TestCase
    func adjacentSelectionDeletesCoalesceBeforeSubsequentInput(): Unit {
        for (key in [KeyCode.Delete, KeyCode.Backspace]) {
            for (reverse in [false, true]) {
                let editor = TextArea(value: "ab")
                let left = TextAreaCaret(1, anchor: Some(0))
                let right = TextAreaCaret(1, anchor: Some(2))
                editor.setCarets(if (reverse) { [right, left] } else { [left, right] })
                @Expect(editor.handle(KeyEvent(key)))
                @Expect(editor.value, "")
                @Assert(editor.carets().size, 1)
                @Expect(editor.carets()[0].offset, 0)
                editor.paste("x")
                @Expect(editor.value, "x")
                @Expect(editor.undo())
                @Expect(editor.value, "")
                @Expect(editor.carets().size, 1)
                @Expect(editor.undo())
                @Expect(editor.value, "ab")
                @Expect(editor.carets().size, 2)
                @Expect(editor.redo())
                @Expect(editor.value, "")
                @Expect(editor.carets().size, 1)
                @Expect(editor.redo())
                @Expect(editor.value, "x")
            }
        }
    }

    @TestCase
    func adjacentReplacementsRetainDistinctInsertionEnds(): Unit {
        let editor = TextArea(value: "ab")
        editor.setCarets([TextAreaCaret(2, anchor: Some(1)), TextAreaCaret(1, anchor: Some(0))])
        editor.paste("x")
        @Expect(editor.value, "xx")
        @Assert(editor.carets().size, 2)
        @Expect(editor.carets()[0].offset, 2)
        @Expect(editor.carets()[1].offset, 1)
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'y'))))
        @Expect(editor.value, "xyxy")
        @Expect(editor.undo())
        @Expect(editor.value, "xx")
    }

    @TestCase
    func samePointCaretsInsertOnlyOnceAndNormalizeAfterEditing(): Unit {
        let editor = TextArea(value: "ab")
        editor.setCarets([TextAreaCaret(1), TextAreaCaret(1, anchor: Some(1))])
        editor.addCaret(TextAreaCaret(1))
        editor.paste("🙂")
        @Expect(editor.value, "a🙂b")
        @Assert(editor.carets().size, 1)
        @Expect(editor.carets()[0].offset, 5)
        @Expect(editor.handle(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(editor.value, "a🙂xb")
    }

    @TestCase
    func adjacentUnicodeSelectionsJoinBeforeLaterInput(): Unit {
        let value = "A中🙂e\u{0301}Z"
        let editor = TextArea(value: value)
        editor.setCarets([TextAreaCaret(4, anchor: Some(1)), TextAreaCaret(8, anchor: Some(4)),
            TextAreaCaret(11, anchor: Some(8))])
        @Expect(editor.handle(KeyEvent(KeyCode.Delete)))
        @Expect(editor.value, "AZ")
        @Assert(editor.carets().size, 1)
        @Expect(editor.carets()[0].offset, 1)
        editor.paste("🙂")
        @Expect(editor.value, "A🙂Z")
        @Assert(editor.carets().size, 1)
        @Expect(editor.carets()[0].offset, 5)
        @Expect(editor.undo())
        @Expect(editor.value, "AZ")
        @Expect(editor.carets().size, 1)
        @Expect(editor.undo())
        @Expect(editor.value, value)
        @Expect(editor.carets().size, 3)
    }

    @TestCase
    func foldedExtraCaretsAreOmittedWithoutChangingTheViewport(): Unit {
        let state = DocumentViewState()
        let editor = TextArea(value: "0\n1\n2\n3", foldState: Some(state))
        editor.setCarets([TextAreaCaret(0), TextAreaCaret(3), TextAreaCaret(4)])
        let area = Rect(2, 3, 6, 2)
        editor.render(area, Buffer(area))
        let visible = editor.cursorPositions(area)
        @Assert(visible.size, 2)
        @Expect(visible[1].x, 3)
        @Expect(visible[1].y, 4)
        state.setFolded(0, 3, true)
        let folded = editor.cursorPositions(area)
        @Assert(folded.size, 2)
        @Expect(folded[0].x, 2)
        @Expect(folded[0].y, 3)
        @Expect(folded[1].x, 2)
        @Expect(folded[1].y, 4)
        @Expect(editor.scroll, 0)
        @Expect(editor.cursor, 0)
        @Expect(editor.carets().size, 3)
        state.clearFolds()
        let unfolded = editor.cursorPositions(area)
        @Assert(unfolded.size, 2)
        @Expect(unfolded[1].x, 3)
        @Expect(unfolded[1].y, 4)
        @Expect(editor.scroll, 0)
    }

    @TestCase
    func foldedPrimaryStillUsesTheHeaderAndVisibleExtrasKeepDecoratedCoordinates(): Unit {
        let state = DocumentViewState()
        state.setFolded(0, 3, true)
        let editor = TextArea(value: "0\n1\n2\n3", foldState: Some(state), block: Some(Block()), lineNumbers: true)
        editor.setCarets([TextAreaCaret(3), TextAreaCaret(5)])
        let area = Rect(2, 3, 12, 4)
        editor.render(area, Buffer(area))
        let positions = editor.cursorPositions(area)
        @Assert(positions.size, 2)
        @Expect(positions[0].x, 7)
        @Expect(positions[0].y, 4)
        @Expect(positions[1].x, 7)
        @Expect(positions[1].y, 5)
        @Expect(editor.cursor, 3)
        @Expect(editor.scroll, 0)
    }
}
