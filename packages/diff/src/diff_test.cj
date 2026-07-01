package diff

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DiffExtensionTest {
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
