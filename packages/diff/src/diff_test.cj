package diff

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DiffExtensionTest {
    @TestCase
    func narrowViewsPreserveExistingWideGlyphsAcrossBothAreaEdges(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -0,0 +1 @@\n+new\n")
        for (sideBySide in [false, true]) {
            for (left in [Int64(0), 1]) {
                // Exercise the summary, hunk heading and added source line.
                for (row in 0..3) {
                    let buffer = Buffer(Rect(0, 0, 5, 4))
                    buffer.setString(0, row, "界", style: Style(bg: Color.Blue))
                    let lead = buffer.getCell(0, row)
                    let continuation = buffer.getCell(1, row)
                    DiffView(doc, sideBySide: sideBySide).render(Rect(left, 0, 1, 4), buffer)
                    @Expect(buffer.getCell(0, row), lead)
                    @Expect(buffer.getCell(1, row), continuation)
                }
            }
        }
        // A glyph entirely inside the target can still be replaced.
        let complete = Buffer(Rect(0, 0, 5, 4))
        complete.setString(0, 0, "界")
        DiffView(doc, sideBySide: true).render(Rect(0, 0, 3, 4), complete)
        @Expect(complete.getCell(0, 0), Cell("a", style: Style(fg: Color.Cyan)))
        @Expect(complete.getCell(1, 0), Cell(".", style: Style(fg: Color.Cyan)))
    }

    @TestCase
    func bothDiffLayoutsClipWideGlyphRepairsAtTheirOuterEdges(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n same\n")
        for (sideBySide in [false, true]) {
            let buffer = Buffer(Rect(0, 0, 16, 4))
            for (row in 0..3) {
                buffer.setString(0, row, "界", style: Style(bg: Color.Blue))
                buffer.setString(12, row, "中", style: Style(bg: Color.Blue))
            }
            DiffView(doc, sideBySide: sideBySide).render(Rect(1, 0, 12, 3), buffer)
            for (row in 0..3) {
                @Expect(buffer.getCell(0, row), Cell("界", style: Style(bg: Color.Blue), kind: CellKind.WideLead))
                @Expect(buffer.getCell(1, row), Cell("", style: Style(bg: Color.Blue), kind: CellKind.WideCont))
                @Expect(buffer.getCell(12, row), Cell("中", style: Style(bg: Color.Blue), kind: CellKind.WideLead))
                @Expect(buffer.getCell(13, row), Cell("", style: Style(bg: Color.Blue), kind: CellKind.WideCont))
            }
        }
    }

    @TestCase
    func diffBlockAlsoPreservesWideGlyphsAcrossTheOuterArea(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -0,0 +1 @@\n+new\n")
        for (left in [Int64(0), 1]) {
            for (row in 0..4) {
                let buffer = Buffer(Rect(0, 0, 5, 4))
                buffer.setString(0, row, "界", style: Style(bg: Color.Blue))
                let lead = buffer.getCell(0, row)
                let continuation = buffer.getCell(1, row)
                DiffView(doc, sideBySide: true, block: Block(title: "diff")).render(Rect(left, 0, 1, 4), buffer)
                @Expect(buffer.getCell(0, row), lead)
                @Expect(buffer.getCell(1, row), continuation)
            }
        }
    }

    @TestCase
    func oneColumnSideBySideViewUsesTheUnifiedColumn(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -0,0 +1 @@\n+new\n")
        let target = Rect(1, 1, 1, 3)
        let sentinel = Cell("Z", style: Style(bg: Color.Blue))
        let side = Buffer(Rect(0, 0, 4, 5))
        let unified = Buffer(side.area)
        side.fill(side.area, sentinel)
        unified.fill(unified.area, sentinel)
        DiffView(doc, sideBySide: true).render(target, side)
        DiffView(doc).render(target, unified)
        for (y in 0..side.area.height) {
            for (x in 0..side.area.width) { @Expect(side.getCell(x, y), unified.getCell(x, y)) }
        }
        @Expect(side.getCell(1, 3), Cell(" ", style: Style(fg: Color.Green)))
        @Expect(side.getCell(2, 3), sentinel)
    }

    @TestCase
    func twoColumnSideBySideViewKeepsBothSidesInsideTheArea(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-old\n+new\n")
        let sentinel = Cell("Z", style: Style(bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 5, 5))
        buffer.fill(buffer.area, sentinel)
        DiffView(doc, sideBySide: true).render(Rect(1, 0, 2, 5), buffer)
        @Expect(buffer.getCell(1, 2), Cell(" ", style: Style(fg: Color.Red)))
        @Expect(buffer.getCell(2, 3), Cell(" ", style: Style(fg: Color.Green)))
        for (y in 0..buffer.area.height) {
            @Expect(buffer.getCell(0, y), sentinel)
            @Expect(buffer.getCell(3, y), sentinel)
        }
    }

    @TestCase
    func hunkContentAndNoNewlineMarkersDoNotBecomeFileHeaders(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n--- old\n\\ No newline at end of file\n+++ new\n\\ No newline at end of file\n--- a/b.txt\n+++ b/b.txt\n@@ -0,0 +1 @@\n+next\n")
        @Assert(doc.files.size, 2)
        @Expect(doc.files[0].newPath, "a.txt")
        @Expect(doc.files[0].addedLines(), 1)
        @Expect(doc.files[0].deletedLines(), 1)
        @Assert(doc.files[0].hunks[0].lines.size, 2)
        @Expect(doc.files[0].hunks[0].lines[1].newLine, Some(1))
        @Expect(doc.files[1].newPath, "b.txt")
        @Expect(doc.files[1].addedLines(), 1)
    }

    @TestCase
    func viewClampsSelectionAndClipsUnicodeAtDisplayBoundaries(): Unit {
        let doc = parseUnifiedDiff("--- a/中文.txt\n+++ b/中文.txt\n@@ -1 +1 @@\n-a\n+b\n")
        let view = DiffView(doc)
        view.selectedFile = -1
        let narrow = Buffer(Rect(0, 0, 1, 4))
        view.render(narrow.area, narrow)
        @Expect(view.selectedFile, 0)
        @Expect(narrow.getCell(0, 0).symbol, " ")
        view.selectedFile = 100
        let wide = Buffer(Rect(0, 0, 2, 4))
        view.render(wide.area, wide)
        @Expect(view.selectedFile, 0)
        @Expect(wide.getCell(0, 0).symbol, "中")
    }

    @TestCase
    func parsesUnifiedDiffFilesAndHunks(): Unit {
        let doc = parseUnifiedDiff("diff --git a/a.txt b/a.txt\n--- a/a.txt\n+++ b/a.txt\n@@ -1,2 +1,2 @@\n old\n-del\n+add\n")
        @Expect(doc.files.size, 1)
        @Expect(doc.files[0].newPath, "a.txt")
        @Expect(doc.files[0].hunks.size, 1)
        @Expect(doc.files[0].hunks[0].lines.size, 3)
        @Expect(doc.addedLines(), 1)
        @Expect(doc.deletedLines(), 1)
        match (doc.files[0].hunks[0].lines[1].kind) {
            case DiffLineKind.Delete => @Expect(true)
            case _ => @Expect(false)
        }
        match (doc.files[0].hunks[0].lines[2].newLine) {
            case Some(line) => @Expect(line, 2)
            case None => @Expect(false)
        }
    }

    @TestCase
    func rendersDiffViewWithStyles(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-old\n+new\n")
        let buffer = Buffer(Rect(0, 0, 20, 5))
        DiffView(doc).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(buffer.getCell(10, 2).symbol, "-")
        @Expect(buffer.getCell(0, 2).style, Style(fg: Color.Red))
        @Expect(buffer.getCell(10, 3).symbol, "+")
        @Expect(buffer.getCell(0, 3).style, Style(fg: Color.Green))
    }

    @TestCase
    func rendersSideBySideDiffWithLineNumbers(): Unit {
        let doc = parseUnifiedDiff("--- a/a.txt\n+++ b/a.txt\n@@ -7 +7 @@\n-old\n+new\n")
        let buffer = Buffer(Rect(0, 0, 32, 5))
        DiffView(doc, sideBySide: true).render(buffer.area, buffer)
        @Expect(buffer.getCell(3, 2).symbol, "7")
        @Expect(buffer.getCell(16 + 3, 3).symbol, "7")
        @Expect(buffer.getCell(0, 2).style, Style(fg: Color.Red))
        @Expect(buffer.getCell(16, 3).style, Style(fg: Color.Green))
    }
}
