package cjtui_taskpad

import core.*
import std.collection.ArrayList

class Task {
    var title: String
    var done: Bool

    init(title: String, done!: Bool = false) {
        this.title = title
        this.done = done
    }

    func label(): String {
        if (done) { "[x] " + title } else { "[ ] " + title }
    }
}

class TaskPad {
    let tasks = ArrayList<Task>()
    let input = Input(block: Block(title: "New task"))
    let listState = ListState(selected: Some(0))
    let toasts = ToastManager()
    let keymap = KeyMap(bindings: [
        KeyBinding([KeyEvent(KeyCode.Enter)], "add", description: "Add task"),
        KeyBinding([KeyEvent(KeyCode.Char(r't'), modifiers: KeyModifier(ctrl: true))], "toggle", description: "Toggle task"),
        KeyBinding([KeyEvent(KeyCode.Char(r'd'), modifiers: KeyModifier(ctrl: true))], "delete", description: "Delete task"),
        KeyBinding([KeyEvent(KeyCode.Char(r'p'), modifiers: KeyModifier(ctrl: true))], "commands", description: "Open commands"),
        KeyBinding([KeyEvent(KeyCode.Char(r'q'), modifiers: KeyModifier(ctrl: true)), KeyEvent(KeyCode.CtrlC)], "quit", description: "Quit")
    ])
    let palette = CommandPalette([
        MenuItem("Add task", action: "add"),
        MenuItem("Toggle task", action: "toggle"),
        MenuItem("Delete task", action: "delete"),
        MenuItem("Clear done", action: "clear_done"),
        MenuItem("Quit", action: "quit")
    ])
    var commandMode = false
    var status = "Enter adds, Ctrl+T toggles, Ctrl+P opens commands, Ctrl+Q quits."

    init() {
        tasks.add(Task("Review rewritten examples"))
        tasks.add(Task("Run release gate"))
        tasks.add(Task("Update docs", done: true))
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                if (commandMode) {
                    match (key.code) {
                        case KeyCode.Esc => commandMode = false; return UpdateResult.next()
                        case KeyCode.CtrlC => return UpdateResult.exit()
                        case _ => ()
                    }
                    match (palette.handle(key)) {
                        case Some(action) =>
                            commandMode = false
                            return apply(action)
                        case None => return UpdateResult.next()
                    }
                }
                match (keymap.actionFor(key)) {
                    case Some(action) => return apply(action)
                    case None =>
                        match (key.code) {
                            case KeyCode.Up => move(-1); return UpdateResult.next()
                            case KeyCode.Down => move(1); return UpdateResult.next()
                            case _ => _ = input.handle(key); return UpdateResult.next()
                        }
                }
            case Event.Paste(text) =>
                let pasted = singleLinePaste(text)
                if (commandMode) {
                    palette.query += pasted
                    palette.selected = 0
                } else {
                    let cursor = clampToRuneBoundary(input.value, input.cursor)
                    input.setValue(input.value[..cursor] + pasted + input.value[cursor..], cursor: cursor + pasted.size)
                }
                return UpdateResult.next()
            case Event.Tick(_) =>
                toasts.tick()
                return UpdateResult.next()
            case _ => return UpdateResult.next()
        }
    }

    private func singleLinePaste(text: String): String {
        var result = ""
        for (rune in text.runes()) {
            let code = UInt32(rune)
            if (rune == r'\n' || rune == r'\r' || rune == r'\t') {
                result += " "
            } else if (code >= 32 && (code < 127 || code >= 160)) {
                result += rune.toString()
            }
        }
        result
    }

    private func apply(action: String): UpdateResult {
        match (action) {
            case "add" => addTask(); UpdateResult.next()
            case "toggle" => toggleSelected(); UpdateResult.next()
            case "delete" => removeSelected(); UpdateResult.next()
            case "clear_done" => clearDone(); UpdateResult.next()
            case "commands" => commandMode = true; UpdateResult.next()
            case "quit" => UpdateResult.exit()
            case _ => UpdateResult.next()
        }
    }

    private func addTask(): Unit {
        let title = input.value.trimAscii()
        if (title.isEmpty()) {
            status = "Type a task before adding."
            toasts.push(Toast(status, ttl: 3))
            return
        }
        tasks.add(Task(title))
        listState.select(Some(tasks.size - 1))
        input.clear()
        status = "added: " + title
        toasts.push(Toast(status, ttl: 3, style: Style(fg: Color.Black, bg: Color.Green)))
    }

    private func toggleSelected(): Unit {
        let index = selectedIndex()
        if (tasks.size == 0 || index < 0 || index >= tasks.size) { return }
        tasks[index].done = !tasks[index].done
        status = "toggled: " + tasks[index].title
    }

    private func removeSelected(): Unit {
        let index = selectedIndex()
        if (tasks.size == 0 || index < 0 || index >= tasks.size) { return }
        let title = tasks[index].title
        tasks.remove(at: index)
        listState.select(if (tasks.size == 0) { None } else { Some(min(index, tasks.size - 1)) })
        status = "deleted: " + title
        toasts.push(Toast(status, ttl: 3))
    }

    private func clearDone(): Unit {
        var i: Int64 = 0
        while (i < tasks.size) {
            if (tasks[i].done) { tasks.remove(at: i) } else { i++ }
        }
        listState.select(if (tasks.size == 0) { None } else { Some(0) })
        status = "cleared done tasks"
    }

    private func move(delta: Int64): Unit {
        if (tasks.size == 0) { return }
        listState.select(Some(clampInt(selectedIndex() + delta, 0, tasks.size - 1)))
        listState.scrollToVisible(tasks.size, 8)
    }

    private func selectedIndex(): Int64 {
        match (listState.selected) {
            case Some(i) => i
            case None => 0
        }
    }

    private func labels(): Array<String> {
        let out = ArrayList<String>()
        for (task in tasks) { out.add(task.label()) }
        out.toArray()
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(3), Constraint.Min(8), Constraint.Length(4), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        frame.renderWidget(input, rows[0])
        frame.renderWidget(List(labels(), state: Some(listState), block: Block(title: "Tasks")), rows[1])
        let bottom = Layout.horizontal([Constraint.Percent(55), Constraint.Min(20)]).withGap(1).split(rows[2])
        let helpBlock = Block(title: "Keys")
        frame.renderWidget(helpBlock, bottom[0])
        frame.renderWidget(HelpView(keymap), helpBlock.inner(bottom[0]))
        frame.renderWidget(toasts, bottom[1])
        frame.renderWidget(StatusBar(left: status, right: "${tasks.size} tasks", style: Style(fg: Color.White, bg: Color.Black)), rows[3])
        if (commandMode) {
            frame.renderWidget(palette, Rect(frame.area.x + 4, frame.area.y + 3, max(30, frame.area.width - 8), min(10, frame.area.height - 6)))
        } else {
            frame.setCursor(input.cursorPosition(rows[0]))
        }
    }
}

func clampInt(value: Int64, low: Int64, high: Int64): Int64 {
    min(max(value, low), high)
}

main(): Int64 {
    let app = TaskPad()
    App(bracketedPaste: true, hideCursor: false, targetFps: 8).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
