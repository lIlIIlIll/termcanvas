package cjtui_data_browser

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DataBrowserTest {
    @TestCase
    func focusedPanelKeysRouteIndependentlyAndTreePersists(): Unit {
        let app = DataBrowser()
        let backend = TestBackend(area: Rect(0, 0, 72, 18))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(app.focus.current(), Some("rows"))
        @Expect(app.menuBar.selected, 1)
        @Assert(backend.snapshot().contains("focus: Rows"))

        let fileSelection = app.picker.selectedEntry()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.table.selectedRow, Some(3))
        @Expect(app.tree.selected, 0)
        @Expect(app.picker.selectedEntry(), fileSelection)

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        @Expect(app.focus.current(), Some("files"))
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(app.menuBar.selected, 2)
        @Assert(backend.snapshot().contains("focus: Files"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.BackTab)))
        @Expect(app.focus.current(), Some("rows"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.BackTab)))
        @Expect(app.focus.current(), Some("tree"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Expect(app.tree.selected, 1)
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(app.tree.selected, 1)
        @Expect(app.menuBar.selected, 0)
        @Assert(backend.snapshot().contains("focus: Tree"))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Tab)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        @Expect(app.table.filterText, "ready")
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(app.menuBar.selected, 1)
        @Assert(backend.snapshot().contains("filter: ready"))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        @Expect(app.table.filterText, "")
        _ = terminal.draw({ frame => app.render(frame) })
        @Assert(backend.snapshot().contains("filter: all"))
    }

    @TestCase
    func modalKeysStayIsolatedFromBackgroundPanels(): Unit {
        let app = DataBrowser()
        app.dialog.picker.path = "."
        app.dialog.picker.refresh()
        let backend = TestBackend(area: Rect(0, 0, 72, 18))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        let fileSelection = app.picker.selectedEntry()
        let dialogSelection = app.dialog.picker.selectedEntry()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'f'))))
        @Expect(app.showDialog)
        @Expect(app.focus.current(), Some("rows"))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Down)))
        @Assert(app.dialog.picker.selectedEntry() != dialogSelection)
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'h'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        @Expect(app.table.filterText, "")
        @Expect(app.table.selectedRow, Some(2))
        @Expect(app.picker.showHidden, false)
        @Expect(app.picker.selectedEntry(), fileSelection)

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        @Expect(!app.showDialog)
        @Expect(app.focus.current(), Some("rows"))
        match (app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }

    @TestCase
    func tablePagingUsesRenderedBodyHeight(): Unit {
        let app = DataBrowser()
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        let viewportRows = max(1, app.tableArea.height - 3)
        app.table.selectedRow = Some(0)
        app.table.offset = 0
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        @Expect(app.table.selectedRow, Some(viewportRows))
    }

}
