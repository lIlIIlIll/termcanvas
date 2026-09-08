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

func assertScenario(name: String, result: HeadlessRunResult, expected: Array<String>, failures: ScenarioFailures): Unit {
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

func runTaskpadSmoke(failures: ScenarioFailures): Unit {
    let input = TextState()
    let status = TextState(value: "ready")
    let tasks = ArrayList<String>()
    tasks.add("[ ] Review release gate")
    let script = HeadlessScript()
        .paste("Ship smoke gate")
        .key(KeyEvent(KeyCode.Enter))
        .key(KeyEvent(KeyCode.Down))
        .key(KeyEvent(KeyCode.Char(r' ')))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Length(3), Constraint.Min(6), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            frame.renderWidget(Paragraph(input.value, block: Block(title: "TaskPad")), rows[0])
            frame.renderWidget(List(tasks.toArray(), state: Some(ListState(selected: Some(max(0, tasks.size - 1)))), block: Block(title: "Tasks")), rows[1])
            frame.renderWidget(StatusBar(left: status.value, right: "${tasks.size} tasks"), rows[2])
        },
        { event =>
            match (event) {
                case Event.Paste(text) => input.value = input.value + text
                case Event.KeyDown(key) =>
                    match (key.code) {
                        case KeyCode.Enter =>
                            if (!input.value.isEmpty()) {
                                tasks.add("[ ] " + input.value)
                                status.value = "added: " + input.value
                                input.value = ""
                            }
                        case KeyCode.Char(r' ') =>
                            if (tasks.size > 0) {
                                tasks[tasks.size - 1] = "[x] Ship smoke gate"
                                status.value = "toggled: Ship smoke gate"
                            }
                        case _ => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 64, 16))
    )
    assertScenario("taskpad", result, ["TaskPad", "[x] Ship smoke gate", "toggled"], failures)
}

func runDataBrowserSmoke(failures: ScenarioFailures): Unit {
    let filter = TextState(value: "all")
    let selected = TextState(value: "record-2")
    let script = HeadlessScript()
        .key(KeyEvent(KeyCode.Char(r'/')))
        .key(KeyEvent(KeyCode.PageDown))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Length(1), Constraint.Min(8), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            let cols = Layout.horizontal([Constraint.Percent(35), Constraint.Min(24)]).withGap(1).split(rows[1])
            frame.renderWidget(MenuBar(["Tree", "Rows", "Files"], selected: 1), rows[0])
            frame.renderWidget(Tree([TreeNode("root", "workspace", expanded: true, children: [TreeNode("src", "src"), TreeNode("examples", "examples")])], block: Block(title: "Tree")), cols[0])
            frame.renderWidget(VirtualTable(
                [TableColumn("ID", width: 5), TableColumn("Name", width: 14), TableColumn("State", width: 10)],
                120,
                { row => ["${row}", "record-${row}", if (row % 3 == 0) { "ready" } else { "pending" }] },
                selectedRow: Some(2),
                selectedColumn: 1,
                block: Block(title: "VirtualTable")
            ), cols[1])
            frame.renderWidget(StatusBar(left: "filter: ${filter.value}", right: selected.value), rows[2])
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) =>
                    match (key.code) {
                        case KeyCode.Char(r'/') => filter.value = "ready"; selected.value = "record-3"
                        case KeyCode.PageDown => selected.value = "record-15"
                        case _ => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 72, 18))
    )
    assertScenario("data_browser", result, ["VirtualTable", "filter: ready", "record-15"], failures)
}

func runOpsDashboardSmoke(failures: ScenarioFailures): Unit {
    let tickLabel = TextState(value: "tick 0")
    let script = HeadlessScript()
        .tick(count: 2)
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Length(3), Constraint.Min(5), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            frame.renderWidget(Gauge(82, total: 100, label: "82%"), rows[0])
            frame.renderWidget(LogView(["deploy ok", "queue stable", tickLabel.value], block: Block(title: "Ops Log")), rows[1])
            frame.renderWidget(StatusBar(left: "ops_dashboard", right: tickLabel.value), rows[2])
        },
        { event =>
            match (event) {
                case Event.Tick(tick) => tickLabel.value = "tick ${tick.frameIndex}"
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 60, 12), tickDeltaMillis: 50)
    )
    assertScenario("ops_dashboard", result, ["Ops Log", "queue stable", "tick 2"], failures)
}

func runTerminalLabSmoke(failures: ScenarioFailures): Unit {
    let transcript = TextState(value: "stdout: ready")
    let script = HeadlessScript()
        .message("stderr: warning")
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let cols = Layout.horizontal([Constraint.Percent(50), Constraint.Min(20)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            frame.renderWidget(LogView(["$ echo ready", transcript.value], block: Block(title: "Terminal")), cols[0])
            frame.renderWidget(Paragraph("--- a\n+++ b\n@@\n-ready\n+ready", block: Block(title: "Diff")), cols[1])
        },
        { event =>
            match (event) {
                case Event.Message(text) => transcript.value = text
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 74, 12))
    )
    assertScenario("terminal_lab", result, ["Terminal", "stderr: warning", "ready"], failures)
}

func runMarkdownStudioSmoke(failures: ScenarioFailures): Unit {
    let status = TextState(value: "editing")
    let document = TextState(value: "# Notes")
    let script = HeadlessScript()
        .paste("\n- release gate")
        .key(KeyEvent(KeyCode.Char(r's'), modifiers: KeyModifier(ctrl: true)))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Min(6), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            frame.renderWidget(DocumentView(Document([DocumentLine(DocumentLineKind.Heading(1), "Notes"), DocumentLine(DocumentLineKind.ListItem(false), "release gate")])), rows[0])
            frame.renderWidget(StatusBar(left: "markdown_studio", right: status.value), rows[1])
        },
        { event =>
            match (event) {
                case Event.Paste(text) => document.value = document.value + text
                case Event.KeyDown(key) =>
                    match (key.code) {
                        case KeyCode.Char(r's') =>
                            if (key.modifiers.ctrl) { status.value = "saved ${document.value.size} bytes" }
                        case _ => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 56, 12))
    )
    assertScenario("markdown_studio", result, ["Notes", "release gate", "saved"], failures)
}

func runAssistantConsoleSmoke(failures: ScenarioFailures): Unit {
    let status = TextState(value: "awaiting approval")
    let showRequest = TextState(value: "yes")
    let script = HeadlessScript()
        .key(KeyEvent(KeyCode.Enter))
        .render()

    let result = AppTestRunner.run(
        script,
        { frame =>
            let rows = Layout.vertical([Constraint.Min(8), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
            frame.renderWidget(TranscriptView(Transcript(items: [
                TranscriptItem("u1", title: "User", body: Document.plain("Run the release checks")),
                TranscriptItem("a1", title: "Assistant", body: Document.plain("I can run the gate."), status: TranscriptItemStatus.Done)
            ]), block: Block(title: "Transcript")), rows[0])
            if (showRequest.value == "yes") {
                frame.renderWidget(RequestDialog(title: "Approval", body: "Run release gate after rewrite?", detail: Document.plain("scripted smoke"), risk: "validation"), Rect(4, 3, 48, 7))
            }
            frame.renderWidget(StatusBar(left: "assistant_console", right: status.value), rows[1])
        },
        { event =>
            match (event) {
                case Event.KeyDown(key) =>
                    match (key.code) {
                        case KeyCode.Enter => status.value = "approval: accepted"; showRequest.value = "no"
                        case _ => ()
                    }
                case _ => ()
            }
            UpdateResult.next()
        },
        options: HeadlessRunOptions(area: Rect(0, 0, 68, 16))
    )
    assertScenario("assistant_console", result, ["Transcript", "Run the release checks", "approval: accepted"], failures)
}

main(): Int64 {
    let failures = ScenarioFailures()
    runTaskpadSmoke(failures)
    runDataBrowserSmoke(failures)
    runOpsDashboardSmoke(failures)
    runTerminalLabSmoke(failures)
    runMarkdownStudioSmoke(failures)
    runAssistantConsoleSmoke(failures)

    if (failures.any()) {
        failures.printAll()
        return 1
    }
    println("example smoke scenarios ok: 6")
    0
}
