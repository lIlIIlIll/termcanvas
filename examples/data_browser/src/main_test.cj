package cjtui_data_browser

import core.*
import std.collection.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DataBrowserTest {
    @TestCase
    func focusedPanelKeysRouteIndependentlyAndTreePersists(): Unit {
        let app = loadedBrowser()
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
        let app = loadedBrowser()
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
        let app = loadedBrowser()
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        let viewportRows = max(1, app.tableArea.height - 3)
        app.model.selectIndex(0)
        app.table.selectedRow = Some(0)
        app.table.offset = 0
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.PageDown)))
        @Expect(app.table.selectedRow, Some(viewportRows))
    }

}

func loadedBrowser(): DataBrowser {
    let app = DataBrowser()
    for (request in app.model.requestViewport(0, 64)) { _ = app.model.accept(request, app.source.load(request)) }
    app.table.selectedRow = app.model.selectedIndex()
    app
}

@Test
class DataBrowserAsyncTest {
    @TestCase
    func appDispatchesAsyncPagesAndAppliesThemOnlyOnCompletion(): Unit {
        let app = DataBrowser()
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(backend.snapshot().contains("Loading"))
        let runtime = AsyncRuntime()
        let commands = ArrayList<Command>()
        commands.add(app.updateWithCommands(Event.Message("load")).command)
        _ = App.processCommandsWithEvents({ event => app.updateWithCommands(event) }, commands, asyncRuntime: runtime)
        @Expect(!app.model.hasTotal())
        let deadline = MonoTime.now() + 3 * Duration.second
        while (!app.model.hasTotal() && MonoTime.now() < deadline) {
            sleep(5 * Duration.millisecond)
            for (event in runtime.drain()) { _ = app.updateWithCommands(event) }
        }
        @Expect(app.model.totalRows(), 1000000)
        @Expect(app.model.cachedRowCount() <= 128)
        _ = terminal.draw({ frame => app.render(frame) })
        @Expect(backend.snapshot().contains("record-"))
    }

    @TestCase
    func replacedAsyncQueriesCannotOverwriteFailureOrRecovery(): Unit {
        let app = DataBrowser()
        let backend = TestBackend(area: Rect(0, 0, 80, 24))
        let terminal = Terminal(backend)
        _ = terminal.draw({ frame => app.render(frame) })
        let runtime = AsyncRuntime()
        dispatchBrowser(app, runtime, Event.Message("initial load"))
        dispatchBrowser(app, runtime, Event.KeyDown(KeyEvent(KeyCode.Char(r'e'))))
        drainBrowser(app, runtime)
        @Expect(!app.model.hasTotal())
        match (app.model.statusAt(0)) {
            case TableStatus.Error(message) => @Expect(message.contains("Provider unavailable"))
            case _ => @Expect(false)
        }
        dispatchBrowser(app, runtime, Event.KeyDown(KeyEvent(KeyCode.Char(r'r'))))
        @Expect(app.model.pendingPageCount(), 1)
        drainBrowser(app, runtime)
        @Expect(!app.model.hasTotal())
        dispatchBrowser(app, runtime, Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        drainBrowser(app, runtime)
        @Expect(app.model.totalRows(), 1000000)
        @Expect(app.model.query().filter, "")
        @Expect(app.model.row(0).getOrThrow().id, "record-0")
    }

    @TestCase
    func providerAppliesFiltersAndSortBeforePagingWithoutFullEnumeration(): Unit {
        let source = BrowserRows()
        let model = PagedTableModel(pageSize: 4)
        _ = model.setQuery(TableQuery(filter: "ready", sortColumn: Some(0), descending: true))
        let request = model.requestViewport(0, 4)[0]
        let page = source.load(request)
        @Expect(page.totalRows, 333334)
        @Expect(page.rows[0].id, "record-999999")
        @Expect(page.rows[1].id, "record-999996")
        @Expect(page.rows[0].cells[2], "ready")
    }
}

func dispatchBrowser(app: DataBrowser, runtime: AsyncRuntime, event: Event): Unit {
    let commands = ArrayList<Command>()
    commands.add(app.updateWithCommands(event).command)
    _ = App.processCommandsWithEvents({ next => app.updateWithCommands(next) }, commands, asyncRuntime: runtime)
}

func drainBrowser(app: DataBrowser, runtime: AsyncRuntime): Unit {
    let deadline = MonoTime.now() + 3 * Duration.second
    while (runtime.pendingCount() > 0 && MonoTime.now() < deadline) {
        sleep(5 * Duration.millisecond)
        for (event in runtime.drain()) { dispatchBrowser(app, runtime, event) }
    }
    if (runtime.pendingCount() > 0) { throw IllegalStateException("Timed out waiting for browser page tasks") }
}
