package showcase_editor

import core.*
import diff.*
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class EditorShowcaseTest {
    @TestCase
    func detectsInsertDeleteReplacementAndMissingNewline(): Unit {
        let unchanged = documentDiff("a\n", "a\n")
        @Expect(unchanged.addedLines(), 0)
        @Expect(unchanged.deletedLines(), 0)
        let inserted = documentDiff("", "new\n")
        @Expect(inserted.addedLines(), 1)
        @Expect(inserted.deletedLines(), 0)
        let removed = documentDiff("old\n", "")
        @Expect(removed.addedLines(), 0)
        @Expect(removed.deletedLines(), 1)
        let changed = documentDiff("one\nold\nend\n", "one\nnew\nend\n")
        @Expect(changed.addedLines(), 1)
        @Expect(changed.deletedLines(), 1)
        @Expect(changed.files[0].hunks[0].lines[0].text, " one")
        @Expect(changed.files[0].hunks[0].lines[3].text, " end")
        let noNewline = documentDiff("a\n", "a")
        @Expect(noNewline.addedLines(), 1)
        @Expect(noNewline.deletedLines(), 1)
        @Expect(noNewline.files[0].hunks[0].lines[1].text, "+a [no newline]")
    }

    @TestCase
    func separatedChangesRetainRepeatedAndInteriorContext(): Unit {
        let diff = documentDiff("a\nsame\nc\n", "A\nsame\nC\n")
        @Expect(diff.addedLines(), 2)
        @Expect(diff.deletedLines(), 2)
        let lines = diff.files[0].hunks[0].lines
        @Expect(lines.size, 5)
        @Expect(lines[2].text, " same")
        @Expect(lines[2].oldLine, Some(2))
        @Expect(lines[2].newLine, Some(2))

        let repeats = documentDiff("a\nsame\nsame\nz\n", "A\nsame\nsame\nZ\n")
        @Expect(repeats.addedLines(), 2)
        @Expect(repeats.deletedLines(), 2)
        @Expect(repeats.files[0].hunks[0].lines[2].text, " same")
        @Expect(repeats.files[0].hunks[0].lines[3].text, " same")
        let insert = documentDiff("a\nb\na\n", "a\nx\nb\na\n")
        @Expect(insert.addedLines(), 1)
        @Expect(insert.deletedLines(), 0)
        let delete = documentDiff("a\nx\nb\na\n", "a\nb\na\n")
        @Expect(delete.addedLines(), 0)
        @Expect(delete.deletedLines(), 1)
    }

    @TestCase
    func smallRepeatedLineCombinationsMatchIndependentLcsOracle(): Unit {
        // Compare every pair of up-to-four-line binary documents against a
        // simple full-table oracle; production code never allocates that table.
        let texts = ArrayList<String>()
        var combinations: Int64 = 1
        for (length in 0..5) {
            for (number in 0..combinations) {
                var bits = number
                var text = ""
                for (_ in 0..length) {
                    text += if (bits % 2 == 0) { "a\n" } else { "b\n" }
                    bits /= 2
                }
                texts.add(text)
            }
            combinations *= 2
        }
        for (original in texts) {
            for (edited in texts) {
                let oldLines = sourceLines(original)
                let newLines = sourceLines(edited)
                let cols = newLines.size + 1
                let table = Array<Int64>((oldLines.size + 1) * cols, repeat: 0)
                for (i in 0..oldLines.size) {
                    for (j in 0..newLines.size) {
                        table[(i + 1) * cols + j + 1] = if (oldLines[i] == newLines[j]) {
                            table[i * cols + j] + 1
                        } else { max(table[i * cols + j + 1], table[(i + 1) * cols + j]) }
                    }
                }
                let expectedMatches = table[oldLines.size * cols + newLines.size]
                let diff = documentDiff(original, edited)
                @Expect(diff.deletedLines(), oldLines.size - expectedMatches)
                @Expect(diff.addedLines(), newLines.size - expectedMatches)
                var before = ""
                var after = ""
                for (line in diff.files[0].hunks[0].lines) {
                    let value = line.text[1..] + "\n"
                    match (line.kind) {
                        case DiffLineKind.Context => before += value; after += value
                        case DiffLineKind.Delete => before += value
                        case DiffLineKind.Add => after += value
                        case _ => @Expect(false)
                    }
                }
                @Expect(before, original)
                @Expect(after, edited)
            }
        }
    }

    @TestCase
    func cachedDiffTracksEditingAndUndo(): Unit {
        let app = EditorShowcase()
        app.refreshDiff()
        let initial = app.diffRevision
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        app.refreshDiff()
        @Expect(app.diffRevision, initial)
        _ = app.update(Event.Paste("x"))
        app.refreshDiff()
        @Expect(app.diffRevision > initial)
        @Expect(app.diff.addedLines(), 1)
        @Expect(app.diff.deletedLines(), 1)
        @Expect(app.textChanged)
        _ = app.editor.undo()
        app.refreshDiff()
        @Expect(app.diff.addedLines(), 0)
        @Expect(app.diff.deletedLines(), 0)
        @Expect(!app.textChanged)
    }

    @TestCase
    func keyboardEditingDiffNavigationAndExit(): Unit {
        let app = EditorShowcase()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        @Expect(app.editor.value, "x" + SAMPLE)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        @Expect(app.showingDiff, true)
        _ = app.update(Event.KeyRepeat(KeyEvent(KeyCode.F(2))))
        @Expect(app.showingDiff, true)
        @Expect(app.diff.addedLines(), 1)
        @Expect(app.diff.deletedLines(), 1)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.offset, 1)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        @Expect(app.showingDiff, false)
        _ = app.update(Event.Paste("中文"))
        @Expect(app.editor.value, "x中文" + SAMPLE)
        @Expect(EditorShowcase().editor.value, SAMPLE)
        match (app.update(Event.KeyDown(KeyEvent(KeyCode.CtrlC))).flow) {
            case ControlFlow.Exit => @Expect(true)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func rendersBothModesAtSupportedSizes(): Unit {
        let app = EditorShowcase()
        for (size in [(Int64(80), Int64(24)), (Int64(120), Int64(36)), (Int64(160), Int64(45))]) {
            let area = Rect(0, 0, size[0], size[1])
            let editBuffer = Buffer(area)
            app.render(Frame(area, editBuffer))
            @Expect(bufferText(editBuffer).contains("TERMCANVAS  /  EDITOR"))
            @Expect(bufferText(editBuffer).contains("Source / EDITING"))
            @Expect(bufferText(editBuffer).contains("Memory only; resets on exit"))
            @Expect(bufferText(editBuffer).contains("unchanged  Ln 1:1  Lines 1-"))
            @Expect(bufferText(editBuffer).contains("/22  +0 -0"))
            if (size[0] >= 100) { @Expect(bufferText(editBuffer).contains("No changes yet.")) }
            @Expect(bufferText(editBuffer).contains("Ctrl-C  quit without saving"))
            _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
            let diffBuffer = Buffer(area)
            app.render(Frame(area, diffBuffer))
            @Expect(bufferText(diffBuffer).contains("Changes against initial sample"))
            @Expect(bufferText(diffBuffer).contains("/ VIEWING"))
            @Expect(bufferText(diffBuffer).contains("F2  back to edit"))
            _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        }
    }

    @TestCase
    func editingUpdatesPositionSummaryAndWidePreview(): Unit {
        let app = EditorShowcase()
        _ = app.update(Event.Paste("中文"))
        let area = Rect(0, 0, 120, 36)
        let buffer = Buffer(area)
        app.render(Frame(area, buffer))
        let visible = bufferText(buffer)
        @Expect(visible.contains("modified  Ln 1:3  Lines 1-"))
        @Expect(visible.contains("/22  +1 -1"))
        @Expect(visible.contains("Change preview"))
        @Expect(visible.contains("+中文package pipeline"))
        @Expect(!visible.contains("No changes yet."))
        let narrow = Buffer(Rect(0, 0, 80, 24))
        app.render(Frame(narrow.area, narrow))
        @Expect(bufferText(narrow).contains("modified  Ln 1:3  Lines 1-16/22  +1 -1"))
        @Expect(!bufferText(narrow).contains("Change preview"))
    }

    @TestCase
    func scrollRangeFollowsActualViewportAndMouseMovesCursor(): Unit {
        let app = EditorShowcase()
        let area = Rect(0, 0, 80, 24)
        let first = Buffer(area)
        app.render(Frame(area, first))
        @Expect(bufferText(first).contains("Lines 1-16/22"))
        _ = app.update(Event.Mouse(MouseEvent(MouseKind.Down, MouseButton.Left, 6, 5)))
        @Expect(app.editor.cursor > 0)
        app.editor.cursor = app.editor.textModel.byteLength()
        let last = Buffer(area)
        app.render(Frame(area, last))
        @Expect(bufferText(last).contains("Lines 7-22/22"))
        _ = app.update(Event.Paste("\nmore"))
        let edited = Buffer(area)
        app.render(Frame(area, edited))
        @Expect(bufferText(edited).contains("Lines 8-23/23"))
    }

    @TestCase
    func diffEndShowsLastPageAndResizeClampsOffset(): Unit {
        let app = EditorShowcase()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(2))))
        let small = Rect(0, 0, 80, 24)
        app.render(Frame(small, Buffer(small)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.End)))
        @Expect(app.offset, app.lastDiffOffset())
        let lastPage = Buffer(small)
        app.render(Frame(small, lastPage))
        let text = bufferText(lastPage)
        @Expect(text.contains("func describe(step: Step)"))
        @Expect(text.contains("step.name +"))
        let large = Rect(0, 0, 120, 36)
        app.render(Frame(large, Buffer(large)))
        @Expect(app.offset, 0)
    }
}

func bufferText(buffer: Buffer): String {
    var text = ""
    for (y in 0..buffer.area.height) {
        for (x in 0..buffer.area.width) { text += buffer.getCell(x, y).symbol }
        text += "\n"
    }
    text
}
