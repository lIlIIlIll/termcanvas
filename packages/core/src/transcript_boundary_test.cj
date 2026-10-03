package core

import std.unittest.*
import std.unittest.testmacro.*

class BoundaryTranscriptSource <: VirtualTranscriptSource {
    var count: Int64 = 8
    var reversed = false
    var revisionValue: Int64 = 0
    var generationValue: Int64 = 0
    var calls: Int64 = 0
    var body: String = "body"
    var chrome = true
    var compact = false
    public func size(): Int64 { count }
    public func generation(): Int64 { generationValue }
    public func itemId(index: Int64): String {
        let identity = if (reversed) { count - 1 - index } else { index }
        "boundary-${identity}"
    }
    public func revision(_: Int64): Int64 { revisionValue }
    public func itemTitle(_: Int64): String { "Title" }
    public func itemFooter(_: Int64): String { "Footer" }
    public func itemUsesCardChrome(_: Int64): Bool { chrome }
    public func itemUsesCompactCardChrome(_: Int64): Bool { compact }
    public func document(_: Int64, _: Int64, _: String): Document {
        calls++
        Document([
            DocumentLine(DocumentLineKind.Paragraph, body),
            DocumentLine(DocumentLineKind.HorizontalRule, "Rule"),
            DocumentLine(DocumentLineKind.Paragraph, "tail")
        ])
    }
}

@Test
class TranscriptBoundaryTest {
    @TestCase
    func backgroundMeasurementsAndExplicitInvalidationRemainBoundedByItems(): Unit {
        for (instrumented in [false, true]) {
            let source = BoundaryTranscriptSource()
            let state = VirtualTranscriptState(followBottom: false)
            let view = VirtualTranscriptView(source, state: state, overscanViewports: 0,
                backgroundBatch: 100, instrumentationEnabled: instrumented)
            let rect = Rect(0, 0, 16, 4)
            view.render(rect, Buffer(rect))
            @Expect(source.calls, 8)
            @Expect(view.metrics().measuredEntries, 8)
            @Expect(!view.invalidateItem("absent"))
            @Expect(view.invalidateItem("boundary-0"))
            view.render(rect, Buffer(rect))
            @Expect(source.calls, 9)
            @Expect(view.metrics().measuredEntries, 8)
            @Expect(view.totalRows() >= 8)
            @Expect(view.materializedCount() >= 1)
        }
    }

    @TestCase
    func themeIdentityAvoidsRedundantLayoutsAndGeometryChangesInvalidate(): Unit {
        let source = BoundaryTranscriptSource()
        source.count = 1
        let view = VirtualTranscriptView(source, themeKey: "same", instrumentationEnabled: true)
        let rect = Rect(0, 0, 20, 10)
        view.render(rect, Buffer(rect))
        let initial = source.calls
        let invalidations = view.instrumentationMetrics().measurementInvalidations
        view.setThemeKey("same"); view.setUnicode(true); view.setCardChrome(false)
        view.setCardTheme(TranscriptCardTheme(borderStyle: Style(fg: Color.Red)))
        view.render(rect, Buffer(rect))
        @Expect(source.calls, initial)
        view.setThemeKey("changed")
        view.render(rect, Buffer(rect))
        @Expect(source.calls, initial + 1)
        view.setUnicode(false)
        view.render(rect, Buffer(rect))
        @Expect(source.calls, initial + 2)
        view.setCardChrome(true)
        view.render(rect, Buffer(rect))
        @Expect(source.calls, initial + 3)
        view.setCardTheme(TranscriptCardTheme(fullFrame: true, contentPadding: Spacing.all(1)))
        view.render(rect, Buffer(rect))
        @Expect(source.calls, initial + 4)
        @Expect(view.instrumentationMetrics().measurementInvalidations, invalidations + 4)
    }

    @TestCase
    func reorderedAndMissingStableAnchorsRecoverWithoutDiscardingTheViewport(): Unit {
        let source = BoundaryTranscriptSource()
        let state = VirtualTranscriptState(followBottom: false)
        let view = VirtualTranscriptView(source, state: state, backgroundBatch: 100, instrumentationEnabled: true)
        let rect = Rect(0, 0, 20, 4)
        view.render(rect, Buffer(rect))
        @Expect(state.anchorId, "boundary-0")
        source.reversed = true
        source.generationValue++
        view.render(rect, Buffer(rect))
        @Expect(state.anchorId, "boundary-0")
        @Expect(state.scrollTop > 0)
        @Expect(view.lastVisibleRanges.size > 0)
        state.anchorId = "removed"
        view.render(rect, Buffer(rect))
        @Expect(state.scrollTop >= 0 && state.scrollTop < view.totalRows())
        source.count = 0; source.generationValue++
        view.render(rect, Buffer(rect))
        @Expect(view.totalRows(), 0)
        @Expect(view.lastVisibleRanges.size, 0)
        @Expect(!view.invalidateItem("removed"))
    }

    @TestCase
    func narrowFramedCardsAndFootersNeverPaintOutsideTheirCanvas(): Unit {
        let source = BoundaryTranscriptSource()
        source.count = 1
        for (unicode in [false, true]) {
            for (width in [Int64(1), 2, 6, 7, 8, 10]) {
                let view = VirtualTranscriptView(source, state: VirtualTranscriptState(followBottom: false), instrumentationEnabled: true)
                view.setCardChrome(true)
                view.setUnicode(unicode)
                view.setCardTheme(TranscriptCardTheme(fullFrame: true, contentPadding: Spacing(left: 1, right: 1, top: 1, bottom: 1)))
                let outer = Rect(0, 0, 14, 16)
                let target = Rect(2, 1, width, 14)
                let buffer = Buffer(outer)
                for (y in 0..outer.height) { buffer.setString(0, y, repeat("#", outer.width)) }
                buffer.beginWorkMetrics(true)
                view.render(target, buffer)
                for (y in 0..outer.height) {
                    for (x in 0..outer.width) {
                        if (x < target.x || x >= target.right || y < target.y || y >= target.bottom) {
                            @Expect(buffer.getCell(x, y).symbol, "#")
                        }
                    }
                }
                @Expect(view.instrumentationMetrics().rowsPainted > 0)
                @Expect(view.lastVisibleRanges.size, 1)
            }
        }
    }

    @TestCase
    func backgroundPaddingAndAsciiRailsPaintWithInstrumentation(): Unit {
        let source = BoundaryTranscriptSource()
        source.count = 1
        source.chrome = false
        let view = VirtualTranscriptView(source, state: VirtualTranscriptState(followBottom: false), instrumentationEnabled: true)
        view.setCardTheme(TranscriptCardTheme(fillBackground: true,
            contentPadding: Spacing.all(1), borderBackground: Style(bg: Color.Blue)))
        let rect = Rect(2, 1, 18, 10)
        let buffer = Buffer(rect)
        buffer.beginWorkMetrics(true)
        view.render(rect, buffer)
        @Expect(buffer.getCell(3, 2).symbol, "b")
        @Expect(colorEquals(buffer.getCell(2, 1).style.bg, Color.Blue))
        @Expect(view.instrumentationMetrics().itemBackgroundCellAttempts > 0)
        @Expect(view.instrumentationMetrics().contentCellAttempts > 0)
        source.chrome = true; source.revisionValue++
        view.setCardChrome(true); view.setUnicode(false)
        view.render(rect, buffer)
        @Expect(view.instrumentationMetrics().rowsPainted > 0)
        source.compact = true; source.revisionValue++
        view.render(rect, buffer)
        @Expect(view.totalRows(), 2)
    }

    @TestCase
    func selectiveDirtyRequestsDistinguishNoViewportOffscreenAndHeightChanges(): Unit {
        let source = BoundaryTranscriptSource()
        let state = VirtualTranscriptState(followBottom: false)
        let view = VirtualTranscriptView(source, state: state, overscanViewports: 0, instrumentationEnabled: true)
        @Expect(view.dirtyRectForItemRevision("boundary-0").isNone())
        view.render(Rect(0, 0, 0, 2), Buffer(Rect(0, 0, 0, 2)))
        @Expect(view.dirtyRectForItemRevision("boundary-0").isNone())
        view.render(Rect(0, 0, 2, 0), Buffer(Rect(0, 0, 2, 0)))
        let rect = Rect(0, 0, 10, 4)
        view.render(rect, Buffer(rect))
        @Expect(view.dirtyRectForItemRevision("not-visible").isNone())
        @Expect(view.instrumentationMetrics().selectiveOffscreenInvalidations, 1)
        @Expect(view.dirtyRectForItemRevision("boundary-0").isSome())
        source.body = repeat("changed ", 12)
        source.revisionValue++
        @Expect(view.dirtyRectForItemRevision("boundary-0"), Some(rect))
        @Expect(view.instrumentationMetrics().fallbackFullViewportPaints, 1)
    }

    @TestCase
    func transcriptKeyboardNavigationUpdatesFollowBottomAndResetsAnchors(): Unit {
        let source = BoundaryTranscriptSource()
        let state = VirtualTranscriptState()
        let view = VirtualTranscriptView(source, state: state, backgroundBatch: 100)
        let rect = Rect(0, 0, 20, 4)
        view.render(rect, Buffer(rect))
        @Expect(state.followBottom)
        @Expect(view.handle(KeyEvent(KeyCode.PageUp)))
        @Expect(!state.followBottom)
        @Expect(state.anchorId, "")
        @Expect(view.handle(KeyEvent(KeyCode.Up)))
        @Expect(view.handle(KeyEvent(KeyCode.Down)))
        @Expect(view.handle(KeyEvent(KeyCode.PageDown)))
        @Expect(state.followBottom)
        @Expect(view.handle(KeyEvent(KeyCode.Home)))
        @Expect(state.scrollTop, 0)
        @Expect(!state.followBottom)
        @Expect(view.handle(KeyEvent(KeyCode.End)))
        @Expect(state.followBottom)
        @Expect(!view.handle(KeyEvent(KeyCode.Esc)))
    }
}
