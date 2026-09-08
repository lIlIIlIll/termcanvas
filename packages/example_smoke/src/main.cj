package cjtui_example_smoke

import core.*
import std.collection.ArrayList

class ScenarioFailures {
    let items = ArrayList<String>()

    func add(message: String): Unit {
        items.add(message)
    }

    func any(): Bool {
        items.size > 0
    }

    func printAll(): Unit {
        for (message in items) {
            eprintln(message)
        }
    }
}

class TextState {
    var value: String

    init(value!: String = "") {
        this.value = value
    }
}

func lastSnapshot(result: HeadlessRunResult): String {
    if (result.snapshots.size == 0) { return "" }
    result.snapshots[result.snapshots.size - 1]
}

func assertComposition(name: String, result: HeadlessRunResult, expected: Array<String>, failures: ScenarioFailures): Unit {
    if (!result.passed()) {
        for (failure in result.failures) {
            failures.add("${name}: ${failure}")
        }
    }
    let snapshot = lastSnapshot(result)
    for (token in expected) {
        if (!snapshot.contains(token)) {
            failures.add("${name}: final snapshot missing '${token}'\n${snapshot}")
        }
    }
}

func runComposerComposition(failures: ScenarioFailures): Unit {
    let composer = Composer(value: "ready", block: Block(title: "Composer"))
    composer.area.setValue("ready", cursor: 5)
    let script = HeadlessScript()
        .paste(" copied")
        .render()

    let result = AppTestRunner.run(
        script,
        { frame => frame.renderWidget(composer, frame.area) },
        { event =>
            match (event) {
                case Event.Paste(text) => _ = composer.paste(text)
                case Event.KeyDown(key) => _ = composer.handle(key)
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 48, 6))
    )
    assertComposition("composer", result, ["Composer", "ready copied"], failures)
}

func runPaletteComposition(failures: ScenarioFailures): Unit {
    let action = TextState(value: "none")
    let palette = CommandPalette([
        MenuItem("Toggle busy state", action: "busy"),
        MenuItem("Switch model", action: "model")
    ])
    let script = HeadlessScript()
        .key(KeyEvent(KeyCode.Char(r'b')))
        .key(KeyEvent(KeyCode.Enter))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Min(4), Constraint.Length(1)]).split(frame.area)
            frame.renderWidget(palette, rows[0])
            frame.renderWidget(StatusBar(left: "selected action", right: action.value), rows[1])
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) =>
                    match (palette.handle(key)) {
                        case Some(value) => action.value = value
                        case None => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 48, 8))
    )
    assertComposition("palette", result, ["> b", "Toggle busy state", "busy"], failures)
}

func runRequestComposition(failures: ScenarioFailures): Unit {
    let action = TextState(value: "pending")
    let request = RequestDialog(title: "Request", body: "Run checks?")
    let script = HeadlessScript()
        .key(KeyEvent(KeyCode.Enter))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            frame.renderWidget(request, Rect(2, 1, max(4, frame.area.width - 4), max(4, frame.area.height - 3)))
            frame.renderWidget(StatusBar(left: "request result", right: action.value), Rect(0, frame.area.bottom - 1, frame.area.width, 1))
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) =>
                    match (request.handle(key)) {
                        case Some(value) => action.value = value
                        case None => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 48, 10))
    )
    assertComposition("request", result, ["Request", "request result", "Cancel"], failures)
}

func runTableComposition(failures: ScenarioFailures): Unit {
    let pager = Paginator(pageSize: 5, total: 30)
    let table = VirtualTable(
        [TableColumn("ID", width: 5), TableColumn("Name", width: 16)],
        30,
        { row => ["${row}", "record-${row}"] },
        selectedRow: Some(0),
        block: Block(title: "VirtualTable")
    )
    let script = HeadlessScript()
        .key(KeyEvent(KeyCode.PageDown))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Min(6), Constraint.Length(1)]).split(frame.area)
            frame.renderWidget(table, rows[0])
            frame.renderWidget(StatusBar(left: "component table", right: "page ${pager.page + 1}"), rows[1])
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) =>
                    if (pager.handle(key)) {
                        table.offset = pager.offset()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 48, 10))
    )
    assertComposition("table", result, ["VirtualTable", "record-5", "page 2"], failures)
}

main(): Int64 {
    let failures = ScenarioFailures()
    runComposerComposition(failures)
    runPaletteComposition(failures)
    runRequestComposition(failures)
    runTableComposition(failures)

    if (failures.any()) {
        failures.printAll()
        return 1
    }
    println("component composition smoke scenarios ok: 4")
    0
}
