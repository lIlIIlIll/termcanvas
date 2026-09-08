package termcanvas_data_browser

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DataBrowserTest {
    @TestCase
    func filterAndPagingDriveTheRealTableState(): Unit {
        let app = DataBrowser()

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))

        @Expect(app.table.filterText, "ready")
        @Expect(app.pager.page, Int64(1))
        @Expect(app.table.offset, Int64(12))

        let backend = TestBackend(area: Rect(0, 0, 72, 18))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        @Assert(backend.snapshot().contains("record-36"))
        @Assert(backend.snapshot().contains("filter: ready"))
    }

    @TestCase
    func dialogFileAndNavigationKeysStayInTheApplicationState(): Unit {
        let app = DataBrowser()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'f'))))
        @Expect(app.showDialog)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/' ))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'h'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Up)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Right)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageUp)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'f'))))
        @Expect(!app.showDialog)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.render(frame) }
        @Assert(backend.snapshot().contains("Tree"))
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (quit) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
