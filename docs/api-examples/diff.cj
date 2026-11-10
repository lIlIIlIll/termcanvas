package cjtui_api_example

import core.*
import diff.*
import cjtui_testing.*

main(): Int64 {
    let context = DiffLine(DiffLineKind.Context, " same", oldLine: Some(1), newLine: Some(1))
    let added = DiffLine(DiffLineKind.Add, "+new", newLine: Some(2))
    let removed = DiffLine(DiffLineKind.Delete, "-old", oldLine: Some(2))
    let header = DiffLine(DiffLineKind.Header, "@@ -1,2 +1,2 @@")
    let lines = [context, added, removed, header]
    let hunk = DiffHunk("@@ -1,2 +1,2 @@", lines: lines, collapsed: false)
    let file = DiffFile("old.txt", "new.txt", hunks: [hunk])
    let document = DiffDocument([file])

    if (context.text != " same" || context.oldLine != Some(1) || context.newLine != Some(1)) {
        throw IllegalStateException("incorrect context line")
    }
    if (hunk.header != "@@ -1,2 +1,2 @@" || hunk.lines.size != 4 || hunk.collapsed) {
        throw IllegalStateException("incorrect hunk")
    }
    if (file.oldPath != "old.txt" || file.newPath != "new.txt" || file.hunks.size != 1 || document.files.size != 1) {
        throw IllegalStateException("incorrect file")
    }
    if (file.addedLines() != 1 || file.deletedLines() != 1 || document.addedLines() != 1 || document.deletedLines() != 1) {
        throw IllegalStateException("incorrect diff counts")
    }
    let contextKind = match (context.kind) { case DiffLineKind.Context => true; case _ => false }
    let addedKind = match (added.kind) { case DiffLineKind.Add => true; case _ => false }
    let removedKind = match (removed.kind) { case DiffLineKind.Delete => true; case _ => false }
    let headerKind = match (header.kind) { case DiffLineKind.Header => true; case _ => false }
    if (!contextKind || !addedKind || !removedKind || !headerKind) { throw IllegalStateException("incorrect line kind") }

    let parsed = parseUnifiedDiff("--- a/example.txt\n+++ b/example.txt\n@@ -1 +1 @@\n-old\n+new\n")
    if (parsed.addedLines() != 1 || parsed.deletedLines() != 1) { throw IllegalStateException("incorrect parsed diff") }
    let styles = DiffViewStyles(summary: StyleOverride(), hunk: StyleOverride(), context: StyleOverride(),
        add: StyleOverride(), delete: StyleOverride(), header: StyleOverride())
    if (styles.summary.bold.isSome() || styles.hunk.bold.isSome() || styles.context.bold.isSome() ||
        styles.add.bold.isSome() || styles.delete.bold.isSome() || styles.header.bold.isSome()) {
        throw IllegalStateException("unexpected style override")
    }
    let view = DiffView(parsed, selectedFile: 0, selectedLine: 0, offset: 0, styles: styles)
    view.selectedFile = 0
    view.selectedLine = 0
    view.offset = 0
    let buffer = Buffer(Rect(0, 0, 40, 4))
    view.render(buffer.area, buffer)
    if (view.selectedFile != 0 || view.selectedLine != 0 || view.offset != 0) { throw IllegalStateException("incorrect view state") }
    let report = TestScenario().run({ frame => frame.renderWidget(view, frame.area) }, { _ => UpdateResult.unchanged() })
    if (!report.passed || !report.lastSnapshot().contains("+1 -1")) { throw IllegalStateException("incorrect diff rendering") }
    return 0
}
