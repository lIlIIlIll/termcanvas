package cjtui_showcase_data

import core.*
import std.unittest.*
import std.unittest.testmacro.*

func press(app: DataShowcase, code: KeyCode): Unit {
    _ = app.update(Event.KeyDown(KeyEvent(code)))
}

func typeAndSubmit(app: DataShowcase, value: String): Unit {
    _ = app.update(Event.Paste(value))
    press(app, KeyCode.Enter)
}

func display(app: DataShowcase, width: Int64, height: Int64): String {
    let area = Rect(0, 0, width, height)
    let backend = TestBackend(area: area)
    let terminal = Terminal(backend)
    _ = terminal.draw { frame => app.render(frame) }
    backend.snapshot()
}

@Test
class DataShowcaseTest {
    @TestCase
    func tableEditingFilteringSortingAndReset(): Unit {
        let app = DataShowcase()
        @Expect(display(app, 80, 24).contains("Accessibility review"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "Keyboard")
        let filtered = display(app, 80, 24)
        @Expect(filtered.contains("Keyboard audit"))
        @Expect(!filtered.contains("Ship dashboard"))
        press(app, KeyCode.Char(r'e'))
        typeAndSubmit(app, "Keyboard tests")
        @Expect(display(app, 80, 24).contains("Keyboard tests"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "")
        @Expect(app.visibleRows()[0].name, "API integration")
        press(app, KeyCode.Char(r's'))
        @Expect(app.visibleRows()[0].name, "Ship dashboard")
        @Expect(display(app, 80, 24).contains("SELECTED  T-103"))
        @Expect(display(app, 80, 24).contains("Sorted by name descending"))
        let fresh = DataShowcase()
        press(fresh, KeyCode.Char(r'/'))
        typeAndSubmit(fresh, "Keyboard")
        @Expect(display(fresh, 80, 24).contains("Keyboard audit"))
        @Expect(!display(fresh, 80, 24).contains("Keyboard tests"))
    }

    @TestCase
    func virtualTreeMutationAndDuplicateProtection(): Unit {
        let app = DataShowcase()
        press(app, KeyCode.Tab)
        press(app, KeyCode.Char(r'n'))
        typeAndSubmit(app, "notes")
        @Expect(display(app, 120, 36).contains("notes"))
        press(app, KeyCode.Char(r'f'))
        typeAndSubmit(app, "draft.csv")
        @Expect(display(app, 120, 36).contains("draft.csv"))
        press(app, KeyCode.Char(r'n'))
        typeAndSubmit(app, "notes")
        @Expect(display(app, 120, 36).contains("sibling already"))
        press(app, KeyCode.Char(r'r'))
        typeAndSubmit(app, "work.csv")
        @Expect(display(app, 120, 36).contains("work.csv"))
        press(app, KeyCode.Char(r'd'))
        @Expect(display(app, 120, 36).contains("Deleted work.csv"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "")
        @Expect(!display(app, 120, 36).contains("work.csv"))
        @Expect(display(DataShowcase(), 120, 36).contains("tasks.csv"))
    }

    @TestCase
    func rendersAtPrimarySizesAndReportsMemoryOnly(): Unit {
        let app = DataShowcase()
        for ((width, height) in [(80, 24), (120, 36), (160, 45)]) {
            let screen = display(app, width, height)
            @Expect(screen.contains("DATA EXPLORER"))
            @Expect(screen.contains("IN-MEMORY DEMO"))
            @Expect(screen.contains("FILES"))
            @Expect(screen.contains("ROWS"))
            @Expect(screen.contains("Tab focus"))
            @Expect(screen.contains("12/12 rows"))
            @Expect(screen.contains("SELECTED"))
            @Expect(screen.contains("completed.csv"))
        }
    }

    @TestCase
    func asciiFallbackAndRootProtection(): Unit {
        let app = DataShowcase()
        _ = app.update(Event.Capabilities(TerminalCapabilities(unicode: false)))
        press(app, KeyCode.Tab)
        press(app, KeyCode.Up)
        press(app, KeyCode.Up)
        press(app, KeyCode.Char(r'd'))
        let area = Rect(0, 0, 80, 24)
        let buffer = Buffer(area)
        buffer.setCapabilities(TerminalCapabilities(unicode: false))
        app.render(Frame(area, buffer))
        let backend = TestBackend(area: area)
        backend.draw(buffer)
        let text = backend.snapshot()
        @Expect(text.contains("Workspace cannot be deleted"))
        @Expect(text.contains("workspace"))
        for (byte in unsafe { text.rawData() }) { @Expect(byte < 128) }
    }

    @TestCase
    func viewportRangeAndContextHelpFollowNavigation(): Unit {
        let app = DataShowcase()
        let initial = display(app, 80, 24)
        @Expect(initial.contains("ROWS 1-5/12"))
        @Expect(initial.contains("Rows: / filter"))
        @Expect(!initial.contains("Files: f new file"))
        for (_ in 0..8) { press(app, KeyCode.Down) }
        @Expect(display(app, 80, 24).contains("ROWS 5-9/12"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "no matching row")
        @Expect(display(app, 80, 24).contains("ROWS 0-0/0"))
        press(app, KeyCode.Tab)
        let tree = display(app, 80, 24)
        @Expect(tree.contains("Files: f new file"))
        @Expect(!tree.contains("Rows: / filter"))
    }

    @TestCase
    func wideStatusSummaryReflectsFilteredData(): Unit {
        let app = DataShowcase()
        let initial = display(app, 160, 45)
        @Expect(initial.contains("CURRENT RESULTS"))
        @Expect(initial.contains("Ready  3"))
        @Expect(initial.contains("In progress  3"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "Keyboard")
        let filtered = display(app, 160, 45)
        @Expect(filtered.contains("Ready  1"))
        @Expect(!filtered.contains("In progress  3"))
    }

    @TestCase
    func selectionsStayVisibleWhenFocusChanges(): Unit {
        let app = DataShowcase()
        let area = Rect(0, 0, 80, 24)
        let rowsFocused = Buffer(area)
        app.render(Frame(area, rowsFocused))
        @Expect(rowsFocused.getCell(2, 9).symbol, "›")
        @Expect(rowsFocused.getCell(28, 9).symbol, "›")
        @Expect(!rowsFocused.getCell(2, 9).style.modifier.underline)
        @Expect(rowsFocused.getCell(28, 9).style.modifier.underline)
        press(app, KeyCode.Tab)
        let filesFocused = Buffer(area)
        app.render(Frame(area, filesFocused))
        @Expect(filesFocused.getCell(2, 9).symbol, "›")
        @Expect(filesFocused.getCell(28, 9).symbol, "›")
        @Expect(filesFocused.getCell(2, 9).style.modifier.underline)
        @Expect(!filesFocused.getCell(28, 9).style.modifier.underline)
    }

    @TestCase
    func wideTableKeepsStatusNearNames(): Unit {
        let app = DataShowcase()
        for ((width, height) in [(120, 36), (160, 45)]) {
            let area = Rect(0, 0, width, height)
            let buffer = Buffer(area)
            app.render(Frame(area, buffer))
            let inset = max(0, (width - 120) / 2)
            @Expect(buffer.getCell(inset + 69, 7).symbol, "S")
            @Expect(buffer.getCell(inset + 1, height - 4).symbol, "M")
            @Expect(buffer.getCell(inset + 1, height - 2).symbol, "R")
        }
    }

    @TestCase
    func wideScreensCenterContentAndKeepFocusAndInputAligned(): Unit {
        for (width in [Int64(160), Int64(200)]) {
            let app = DataShowcase()
            let area = Rect(0, 0, width, 45)
            let inset = (width - 120) / 2
            let rowsFocused = Buffer(area)
            app.render(Frame(area, rowsFocused))
            @Expect(rowsFocused.getCell(inset + 1, 1).symbol, "T")
            @Expect(rowsFocused.getCell(inset + 2, 9).symbol, "›")
            @Expect(rowsFocused.getCell(inset + 34, 9).symbol, "›")
            @Expect(rowsFocused.getCell(inset + 34, 9).style.modifier.underline)
            press(app, KeyCode.Tab)
            let filesFocused = Buffer(area)
            app.render(Frame(area, filesFocused))
            @Expect(filesFocused.getCell(inset + 2, 9).style.modifier.underline)
            @Expect(!filesFocused.getCell(inset + 34, 9).style.modifier.underline)
            press(app, KeyCode.Char(r'/'))
            let inputFrame = Frame(area, Buffer(area))
            app.render(inputFrame)
            @Expect(inputFrame.getCursor().getOrThrow().x >= inset + 12)
            @Expect(inputFrame.getCursor().getOrThrow().y, 42)
        }
    }

    @TestCase
    func longNamesKeepStatusVisibleAndHelpAtScreenBottom(): Unit {
        let app = DataShowcase()
        press(app, KeyCode.Char(r'e'))
        typeAndSubmit(app, "Long project name that exceeds the table column width")
        for ((width, height, statusX) in [(80, 24, 65), (120, 36, 78)]) {
            let area = Rect(0, 0, width, height)
            let buffer = Buffer(area)
            app.render(Frame(area, buffer))
            @Expect(buffer.getCell(statusX, 7).symbol, "S")
            @Expect(buffer.getCell(1, height - 2).symbol, "R")
        }
    }

    @TestCase
    func editingAndSortingKeepSelectedRecord(): Unit {
        let app = DataShowcase()
        @Expect(display(app, 80, 24).contains("SELECTED  T-106"))
        press(app, KeyCode.Char(r'e'))
        typeAndSubmit(app, "zzz")
        let renamed = display(app, 80, 24)
        @Expect(renamed.contains("SELECTED  T-106  /  zzz"))
        @Expect(renamed.contains("ROWS 8-12/12"))
        press(app, KeyCode.Char(r's'))
        @Expect(display(app, 80, 24).contains("SELECTED  T-106  /  zzz"))
        press(app, KeyCode.Char(r'e'))
        typeAndSubmit(app, "zzz again")
        @Expect(display(app, 80, 24).contains("SELECTED  T-106  /  zzz again"))
        @Expect(app.visibleRows()[0].id, "T-106")
        for (row in app.visibleRows()) {
            if (row.id == "T-105") { @Expect(row.name, "Accessibility review") }
        }
    }

    @TestCase
    func filteringExplainsHiddenSelectionAndHandlesEmptyResults(): Unit {
        let app = DataShowcase()
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "Keyboard")
        let filtered = display(app, 80, 24)
        @Expect(filtered.contains("previous row hidden"))
        @Expect(filtered.contains("SELECTED  T-103"))
        press(app, KeyCode.Char(r'e'))
        typeAndSubmit(app, "other name")
        let hidden = display(app, 80, 24)
        @Expect(hidden.contains("Row updated; hidden by filter"))
        @Expect(hidden.contains("NO ROW SELECTED"))
        @Expect(hidden.contains("ROWS 0-0/0"))
        press(app, KeyCode.Char(r's'))
        @Expect(display(app, 80, 24).contains("NO ROW SELECTED"))
        press(app, KeyCode.Char(r'/'))
        typeAndSubmit(app, "")
        @Expect(!display(app, 80, 24).contains("NO ROW SELECTED"))
    }
}
