package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TerminalRenderRecoveryTest {
    @TestCase
    func widthMismatchDuringPartialRenderForcesACompleteRecoveryFrame(): Unit {
        let area = Rect(0, 0, 5, 1)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        terminal.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        _ = terminal.draw({ frame => frame.canvas().drawText(0, 0, "ABCDE", Style.default()) })
        let dirty = DirtyRects([Rect(1, 0, 1, 1)])
        let incompatible = Surface(area)
        @ExpectThrows[IllegalArgumentException](terminal.draw({ frame =>
            frame.canvas().composite(incompatible)
        }, dirtyRects: dirty))
        @Expect(backend.snapshots().size, 1)

        let recovered = terminal.draw({ frame =>
            frame.canvas().drawText(0, 0, "A CDE", Style.default())
        }, dirtyRects: dirty)
        @Expect(recovered.fullRedraw)
        @Expect(backend.snapshot(), "A CDE")
        @Expect(backend.lastDiffOps(), 5)

        let next = terminal.draw({ frame =>
            frame.canvas().drawText(0, 0, "A ZDE", Style.default())
        }, dirtyRects: DirtyRects([Rect(2, 0, 1, 1)]))
        @Expect(!next.fullRedraw)
        @Expect(backend.snapshot(), "A ZDE")
    }

    @TestCase
    func ordinaryRenderExceptionPropagatesAndRemovesDirtyClipOnRecovery(): Unit {
        let area = Rect(0, 0, 6, 1)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw({ frame => frame.canvas().drawText(0, 0, "ABCDEF", Style.default()) })
        try {
            _ = terminal.draw({ frame =>
                frame.canvas().drawText(2, 0, "X", Style.default())
                throw IllegalArgumentException("render callback failed")
            }, dirtyRects: DirtyRects([Rect(2, 0, 1, 1)]))
            @Expect(false)
        } catch (error: IllegalArgumentException) {
            @Expect(error.message, "render callback failed")
        }
        @Expect(backend.snapshots().size, 1)
        let recovered = terminal.draw({ frame =>
            frame.canvas().drawText(0, 0, "abcdef", Style.default())
        }, dirtyRects: DirtyRects([Rect(2, 0, 1, 1)]))
        @Expect(recovered.fullRedraw)
        @Expect(backend.snapshot(), "abcdef")
        @Expect(backend.lastDiffOps(), 6)
    }
}
