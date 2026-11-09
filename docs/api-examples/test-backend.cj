package cjtui_api_example

import core.*

main(): Int64 {
    let test = TestBackend(area: Rect(0, 0, 4, 1), captureSnapshots: true)
    let backend: Backend = test
    backend.clear()
    backend.moveTo(1, 0)
    backend.enterAlternateScreen()
    backend.leaveAlternateScreen()
    backend.hideCursor()
    backend.showCursor()
    backend.setCursorShape(CursorShape.Bar)
    backend.enableMouse()
    backend.disableMouse()
    backend.enableBracketedPaste()
    backend.disableBracketedPaste()
    backend.setInstrumentationEnabled(true)
    if (backend.size() != Rect(0, 0, 4, 1) || backend.diagnosticByteCount() != -1) {
        throw IllegalStateException("incorrect test backend")
    }
    test.setSize(Rect(0, 0, 4, 1))
    let buffer = Buffer(backend.size())
    buffer.setString(0, 0, "OK")
    backend.draw(buffer)
    backend.drawDiff(buffer, RenderDiffPlan(2, [RenderDiffSpan(0, 0, "OK", Style())]))
    let source = MediaSource("logo", "asset:logo", alt: "Logo")
    let placement = MediaPlacement("logo", source, Rect(0, 0, 1, 1))
    backend.drawMedia([MediaOp(MediaOpKind.Draw, placement)])
    backend.write("done")
    backend.flush()
    let snapshot = test.snapshot()
    if (test.lastBuffer().isNone() || test.lastDiffOps() != 2 || test.lastDiffWrites() != 1 ||
        test.lastMediaOps().size != 1 || test.mediaFrameCount() != 1 || test.snapshots().size != 2 ||
        test.snapshotAt(1) != snapshot || !test.assertCell(0, 0, "O") || !test.assertSnapshot(snapshot) ||
        !test.assertSnapshotAt(1, snapshot) || !test.assertLastMediaOpCount(1) || !test.output().contains("done")) {
        throw IllegalStateException("test backend inspection failed")
    }
    test.clearOutput()
    if (test.output() != "") { throw IllegalStateException("output was not cleared") }
    return 0
}
