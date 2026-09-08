package cjtui_data_browser

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
}
