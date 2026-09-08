package cjtui_oh_my_pi_skin

import core.*
import std.collection.ArrayList

let BG = Color.Rgb(13, 13, 13)
let PANEL = Color.Rgb(22, 24, 30)
let PANEL_2 = Color.Rgb(30, 33, 41)
let STATUS_BG = Color.Rgb(18, 18, 18)
let ORANGE = Color.Rgb(249, 115, 22)
let ACCENT = Color.Rgb(254, 188, 56)
let BLUE = Color.Rgb(23, 143, 185)
let CYAN = Color.Rgb(0, 136, 250)
let GREEN = Color.Rgb(137, 210, 129)
let RED = Color.Rgb(252, 58, 75)
let MUTED = Color.Rgb(119, 125, 136)
let DIM = Color.Rgb(68, 72, 82)
let PINK = Color.Rgb(255, 92, 200)
let VIOLET = Color.Rgb(180, 110, 255)
let HERO_TIMER = "omp.hero"
let TODO_TIMER = "omp.todo"
let TRANSCRIPT_TIMER = "omp.transcript"
let STATUS_TIMER = "omp.status"

class TodoItem {
    let title: String
    var done: Bool

    init(title: String, done!: Bool = false) {
        this.title = title
        this.done = done
    }
}

class TodoSection {
    let title: String
    let items: Array<TodoItem>
    var expanded: Bool

    init(title: String, items: Array<TodoItem>, expanded!: Bool = false) {
        this.title = title
        this.items = items
        this.expanded = expanded
    }

    func doneCount(): Int64 {
        var count: Int64 = 0
        for (item in items) {
            if (item.done) { count++ }
        }
        count
    }
}

class TodoListState {
    let sections: Array<TodoSection>
    var selected: Int64 = 1
    var offset: Int64 = 0

    init() {
        sections = [
            TodoSection("I. Array", [
                TodoItem("Add @local!/@local? constructors to Array"),
                TodoItem("Add @local!/@local? get/first/last/[] to Array"),
                TodoItem("Add @local! set methods to Array"),
                TodoItem("Add @local? judge methods to Array"),
                TodoItem("Add @local! transform methods to Array"),
                TodoItem("Add Array adapter tests")
            ], expanded: true),
            TodoSection("II. String", [
                TodoItem("Add local String constructors"),
                TodoItem("Add local slicing helpers"),
                TodoItem("Add local mutation adapters"),
                TodoItem("Cover UTF-8 boundary behavior"),
                TodoItem("Add String adapter tests")
            ]),
            TodoSection("III. ArrayList", [
                TodoItem("Add local ArrayList constructors"),
                TodoItem("Add local indexed access"),
                TodoItem("Add local mutation methods"),
                TodoItem("Add collection judge methods"),
                TodoItem("Add transform methods"),
                TodoItem("Verify iterator ownership"),
                TodoItem("Add ArrayList adapter tests")
            ]),
            TodoSection("IV. Build", [
                TodoItem("Run adapter unit tests"),
                TodoItem("Run release build")
            ])
        ]
    }

    func visibleCount(): Int64 {
        var count: Int64 = 0
        for (section in sections) {
            count++
            if (section.expanded) { count += section.items.size }
        }
        count
    }

    func completedCount(): Int64 {
        var count: Int64 = 0
        for (section in sections) {
            count += section.doneCount()
        }
        count
    }

    func totalCount(): Int64 {
        var count: Int64 = 0
        for (section in sections) {
            count += section.items.size
        }
        count
    }

    func move(delta: Int64, viewportHeight: Int64): Unit {
        selected = min(max(0, visibleCount() - 1), max(0, selected + delta))
        ensureVisible(viewportHeight)
    }

    func home(viewportHeight: Int64): Unit {
        selected = 0
        ensureVisible(viewportHeight)
    }

    func end(viewportHeight: Int64): Unit {
        selected = max(0, visibleCount() - 1)
        ensureVisible(viewportHeight)
    }

    func activate(viewportHeight: Int64): Unit {
        var row: Int64 = 0
        for (section in sections) {
            if (row == selected) {
                section.expanded = !section.expanded
                selected = min(selected, max(0, visibleCount() - 1))
                ensureVisible(viewportHeight)
                return
            }
            row++
            if (section.expanded) {
                for (item in section.items) {
                    if (row == selected) {
                        item.done = !item.done
                        return
                    }
                    row++
                }
            }
        }
    }

    func setExpanded(expanded: Bool, viewportHeight: Int64): Unit {
        var row: Int64 = 0
        for (section in sections) {
            if (row == selected) {
                section.expanded = expanded
                selected = min(selected, max(0, visibleCount() - 1))
                ensureVisible(viewportHeight)
                return
            }
            row++
            if (section.expanded) { row += section.items.size }
        }
    }

    func ensureVisible(viewportHeight: Int64): Unit {
        let height = max(1, viewportHeight)
        if (selected < offset) {
            offset = selected
        } else if (selected >= offset + height) {
            offset = selected - height + 1
        }
        offset = min(offset, max(0, visibleCount() - height))
    }
}

class OhMyPiSkin {
    var caps = TerminalCapabilities()
    var heroMillis: Int64 = 0
    var todoMillis: Int64 = 0
    var transcriptMillis: Int64 = 0
    var statusMillis: Int64 = 0
    var paletteOpen = false
    var showBusy = true
    var mode = "agent"
    var todoFocused = true
    var todoViewportHeight: Int64 = 8
    var screenArea = Rect(0, 0, 0, 0)
    var heroArea = Rect(0, 0, 0, 0)
    var todoArea = Rect(0, 0, 0, 0)
    var transcriptArea = Rect(0, 0, 0, 0)
    var composerArea = Rect(0, 0, 0, 0)
    var statusArea = Rect(0, 0, 0, 0)
    var paletteArea = Rect(0, 0, 0, 0)
    var snowPile = ArrayList<Int64>()
    var snowPileWidth: Int64 = 0
    let todos = TodoListState()
    let composer = Composer(
        value: "/review runtime#1441 --multi-round",
        slashHints: ["/review", "/model", "/theme", "/resume", "/clear"]
    )
    let palette = CommandPalette([
        MenuItem("Switch model", action: "model"),
        MenuItem("Toggle busy state", action: "busy"),
        MenuItem("Open recent session", action: "session"),
        MenuItem("Run review command", action: "review"),
        MenuItem("Quit", action: "quit")
    ])

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.Capabilities(c) =>
                caps = c
                UpdateResult.withCommand(Command.Batch([
                    Command.StartTimer(TimerSpec(HERO_TIMER, Duration.millisecond * 33)),
                    Command.StartTimer(TimerSpec(TODO_TIMER, Duration.millisecond * 83)),
                    Command.StartTimer(TimerSpec(TRANSCRIPT_TIMER, Duration.millisecond * 83)),
                    Command.StartTimer(TimerSpec(STATUS_TIMER, Duration.millisecond * 83))
                ]))
            case Event.Timer(timer) =>
                if (timer.id == HERO_TIMER) {
                    advanceHeroSnow(timer.elapsedMillis)
                    heroMillis = timer.elapsedMillis
                    dirtyResult([heroArea])
                } else if (timer.id == TODO_TIMER) {
                    todoMillis = timer.elapsedMillis
                    dirtyResult([selectedTodoRow()])
                } else if (timer.id == TRANSCRIPT_TIMER) {
                    transcriptMillis = timer.elapsedMillis
                    dirtyResult([transcriptTypingArea()])
                } else if (timer.id == STATUS_TIMER) {
                    statusMillis = timer.elapsedMillis
                    dirtyResult([statusArea])
                } else {
                    dirtyResult([statusArea])
                }
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC => UpdateResult.exit()
                    case _ =>
                        if (paletteOpen) {
                            handlePaletteKey(key)
                        } else {
                            handlePrimaryKey(key)
                        }
                }
            case Event.Paste(text) =>
                if (!paletteOpen && !todoFocused) {
                    _ = composer.paste(text)
                    dirtyResult([composerArea])
                } else {
                    UpdateResult.next()
                }
            case _ => dirtyResult([statusArea])
        }
    }

    private func handlePrimaryKey(key: KeyEvent): UpdateResult {
        match (key.code) {
            case KeyCode.Char(r'q') => UpdateResult.exit()
            case KeyCode.Tab =>
                todoFocused = !todoFocused
                dirtyResult([todoArea, composerArea])
            case KeyCode.Char(r'/') =>
                palette.query = ""
                palette.selected = 0
                paletteOpen = true
                dirtyResult([paletteArea])
            case KeyCode.Char(r'b') =>
                showBusy = !showBusy
                dirtyResult([heroArea])
            case KeyCode.Char(r't') =>
                mode = if (mode == "agent") { "theme" } else { "agent" }
                dirtyResult([statusArea])
            case KeyCode.Up =>
                handleNavigation(key, -1)
            case KeyCode.Down =>
                handleNavigation(key, 1)
            case KeyCode.Home =>
                handleTodoAction(key, { => todos.home(todoViewportHeight) })
            case KeyCode.End =>
                handleTodoAction(key, { => todos.end(todoViewportHeight) })
            case KeyCode.Left =>
                handleTodoAction(key, { => todos.setExpanded(false, todoViewportHeight) }, structural: true)
            case KeyCode.Right =>
                handleTodoAction(key, { => todos.setExpanded(true, todoViewportHeight) }, structural: true)
            case KeyCode.Enter | KeyCode.Char(r' ') =>
                handleTodoAction(key, { => todos.activate(todoViewportHeight) }, structural: true)
            case _ =>
                _ = composer.handle(key)
                dirtyResult([composerArea])
        }
    }

    private func handlePaletteKey(key: KeyEvent): UpdateResult {
        match (key.code) {
            case KeyCode.Esc =>
                paletteOpen = false
                dirtyResult([paletteArea])
            case _ =>
                match (palette.handle(key)) {
                    case Some(action) => applyPaletteAction(action)
                    case None => dirtyResult([paletteArea])
                }
        }
    }

    private func applyPaletteAction(action: String): UpdateResult {
        paletteOpen = false
        match (action) {
            case "model" =>
                mode = if (mode == "agent") { "model" } else { "agent" }
                dirtyResult([paletteArea, statusArea])
            case "busy" =>
                showBusy = !showBusy
                dirtyResult([paletteArea, heroArea])
            case "session" =>
                composer.restoreDraft("/resume recent")
                todoFocused = false
                dirtyResult([paletteArea, todoArea, composerArea])
            case "review" =>
                composer.restoreDraft("/review runtime#1441 --multi-round")
                todoFocused = false
                dirtyResult([paletteArea, todoArea, composerArea])
            case "quit" => UpdateResult.exit()
            case _ => dirtyResult([paletteArea])
        }
    }

    private func handleNavigation(key: KeyEvent, delta: Int64): UpdateResult {
        if (!todoFocused) {
            _ = composer.handle(key)
            return dirtyResult([composerArea])
        }
        let oldOffset = todos.offset
        let oldRow = selectedTodoRow()
        todos.move(delta, todoViewportHeight)
        if (oldOffset != todos.offset) {
            dirtyResult([todoArea])
        } else {
            dirtyResult([oldRow, selectedTodoRow()])
        }
    }

    private func handleTodoAction(key: KeyEvent, action: () -> Unit, structural!: Bool = false): UpdateResult {
        if (!todoFocused) {
            _ = composer.handle(key)
            return dirtyResult([composerArea])
        }
        let oldOffset = todos.offset
        let oldRow = selectedTodoRow()
        action()
        if (structural || oldOffset != todos.offset) {
            dirtyResult([todoArea])
        } else {
            dirtyResult([oldRow, selectedTodoRow()])
        }
    }

    private func dirtyResult(areas: Array<Rect>): UpdateResult {
        let dirty = DirtyRects()
        for (area in areas) {
            if (area.width > 0 && area.height > 0) { dirty.add(area) }
        }
        if (dirty.isEmpty()) {
            return UpdateResult.next()
        }
        UpdateResult(dirtyRects: Some(dirty))
    }

    private func selectedTodoRow(): Rect {
        if (todoArea.width <= 4 || todoArea.height <= 2) { return Rect(0, 0, 0, 0) }
        let viewRow = todos.selected - todos.offset
        if (viewRow < 0 || viewRow >= todoViewportHeight) { return Rect(0, 0, 0, 0) }
        Rect(todoArea.x + 2, todoArea.y + 1 + viewRow, max(1, todoArea.width - 4), 1)
    }

    private func transcriptTypingArea(): Rect {
        if (transcriptArea.width <= 4 || transcriptArea.height <= 2) { return Rect(0, 0, 0, 0) }
        Rect(transcriptArea.x + 2, transcriptArea.bottom - 2, max(1, transcriptArea.width - 4), 1)
    }

    private func popupRect(area: Rect): Rect {
        let width = min(42, max(24, area.width - 8))
        let height = min(10, max(6, area.height - 6))
        Rect(area.x + (area.width - width) / 2, area.y + 3, width, height)
    }

    func render(frame: Frame): Unit {
        let canvas = frame.canvas()
        screenArea = frame.area
        canvas.fillRect(frame.area, Style(bg: BG))
        drawBackground(canvas, frame.area)

        if (frame.area.width < 76 || frame.area.height < 21) {
            if (frame.isDirty(frame.area)) { drawCompact(canvas, frame.area) }
            return
        }

        let rows = Layout.vertical([
            Constraint.Length(8),
            Constraint.Min(9),
            Constraint.Length(4),
            Constraint.Length(1)
        ]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)

        heroArea = rows[0]
        let cols = Layout.horizontal([Constraint.Percent(46), Constraint.Min(40)]).withGap(1).split(rows[1])
        todoArea = cols[0]
        transcriptArea = cols[1]
        composerArea = rows[2]
        statusArea = rows[3]
        paletteArea = popupRect(frame.area)

        if (frame.isDirty(heroArea)) { drawHero(canvas, heroArea, heroMillis) }
        if (frame.isDirty(todoArea)) { drawTodos(canvas, todoArea, todoMillis) }
        drawTranscript(frame, canvas, transcriptArea, transcriptMillis)
        frame.renderWidget(composer, rows[2])
        if (frame.isDirty(statusArea)) { drawStatus(canvas, statusArea) }

        if (paletteOpen) {
            canvas.fillRect(paletteArea, Style(bg: Color.Rgb(19, 22, 28)))
            frame.renderWidget(palette, paletteArea)
        }

        if (!todoFocused) {
            frame.setCursor(composer.area.cursorPosition(rows[2]))
        }
    }

    private func drawBackground(canvas: Canvas, area: Rect): Unit {
        let gridStyle = Style(fg: Color.Rgb(28, 32, 38), bg: BG)
        var x = area.x
        while (x < area.right) {
            var y = area.y
            while (y < area.bottom) {
                canvas.drawText(x, y, ".", gridStyle)
                y += 4
            }
            x += 8
        }
        let glowStyle = Style(fg: ORANGE, bg: BG)
        canvas.drawLine(area.x + 2, area.y + 2, area.x + 10, area.y + 6, "*", glowStyle)
        canvas.drawLine(area.right - 12, area.y + 2, area.right - 4, area.y + 6, "*", glowStyle)
        canvas.drawLine(area.x + 2, area.bottom - 4, area.x + 14, area.bottom - 2, ".", Style(fg: Color.Rgb(80, 45, 24), bg: BG))
        canvas.drawLine(area.right - 15, area.bottom - 2, area.right - 3, area.bottom - 4, ".", Style(fg: Color.Rgb(80, 45, 24), bg: BG))
    }

    private func drawHero(canvas: Canvas, area: Rect, millis: Int64): Unit {
        canvas.fillRect(area, Style(bg: Color.Rgb(10, 12, 16)))
        drawCornerMarks(canvas, area)
        drawHeroSnow(canvas, area, millis, Color.Rgb(10, 12, 16))
        let center = Rect(area.x + area.width / 2 - 28, area.y + 1, 56, max(1, area.height - 2))
        drawPiLogo(canvas, Rect(center.x, center.y, 14, 5), millis)
        canvas.drawText(center.x + 17, center.y + 1, "oh my PI", Style(fg: Color.White, bg: Color.Rgb(10, 12, 16), modifier: Modifier.strong()))
        canvas.drawText(center.x + 17, center.y + 3, "[ ai coding agent ]", Style(fg: MUTED, bg: Color.Rgb(10, 12, 16)))
        let dot = if (showBusy) { if ((millis / 500) % 2 == 0) { "*" } else { "o" } } else { "o" }
        canvas.drawText(center.x + 17, center.y + 5, dot + " MCP  LSP  Subagents  Web Search", Style(fg: if (showBusy) { GREEN } else { MUTED }, bg: Color.Rgb(10, 12, 16)))
        drawLightSweep(canvas, area, millis, Color.Rgb(10, 12, 16))
        drawMarquee(canvas, Rect(area.x + 2, area.bottom - 2, max(1, area.width - 4), 1), " waiting on 3 jobs  ArrayAdapter  StringAdapter  ArrayListAdapter  ", millis, Style(fg: Color.Rgb(170, 180, 190), bg: Color.Rgb(10, 12, 16)))
        drawHeroSnowPile(canvas, area, millis, Color.Rgb(10, 12, 16))
    }

    private func drawTodos(canvas: Canvas, area: Rect, millis: Int64): Unit {
        let focusMark = if (todoFocused) { " *" } else { "" }
        let title = " Todos · ${todos.completedCount()}/${todos.totalCount()}${focusMark} "
        drawPanel(canvas, area, title)
        let inner = Rect(area.x + 2, area.y + 1, max(1, area.width - 4), max(1, area.height - 2))
        todoViewportHeight = inner.height
        todos.ensureVisible(todoViewportHeight)

        var logicalRow: Int64 = 0
        var visibleRow: Int64 = 0
        for (section in todos.sections) {
            if (logicalRow >= todos.offset && visibleRow < inner.height) {
                drawTodoSection(canvas, inner, visibleRow, logicalRow, section, millis)
                visibleRow++
            }
            logicalRow++
            if (section.expanded) {
                for (i in 0..section.items.size) {
                    if (logicalRow >= todos.offset && visibleRow < inner.height) {
                        drawTodoItem(canvas, inner, visibleRow, logicalRow, section.items[i], i == section.items.size - 1, millis)
                        visibleRow++
                    }
                    logicalRow++
                }
            }
        }

        if (todos.offset + inner.height < todos.visibleCount() && inner.height > 0) {
            let remaining = todos.visibleCount() - todos.offset - inner.height
            let marker = if (caps.unicode) { "└─ … ${remaining} more todo" } else { "`- ... ${remaining} more todo" }
            canvas.drawText(inner.x, inner.bottom - 1, truncateText(marker, inner.width), Style(fg: MUTED, bg: PANEL))
        }
    }

    private func drawTodoSection(canvas: Canvas, area: Rect, viewRow: Int64, logicalRow: Int64, section: TodoSection, millis: Int64): Unit {
        let selected = todoFocused && logicalRow == todos.selected
        let bg = if (selected) { PANEL_2 } else { PANEL }
        canvas.fillRect(Rect(area.x, area.y + viewRow, area.width, 1), Style(bg: bg))
        let fold = if (section.expanded) {
            if (caps.unicode) { "▾ " } else { "v " }
        } else {
            if (caps.unicode) { "▸ " } else { "> " }
        }
        let text = fold + section.title + " · ${section.doneCount()}/${section.items.size}"
        canvas.drawText(area.x, area.y + viewRow, truncateText(text, area.width), Style(fg: if (selected) { ACCENT } else { Color.White }, bg: bg, modifier: Modifier.strong()))
        if (selected) {
            drawTodoLight(canvas, area, viewRow, section.title + "  ${section.doneCount()}/${section.items.size}", 2, millis, bg)
        }
    }

    private func drawTodoItem(canvas: Canvas, area: Rect, viewRow: Int64, logicalRow: Int64, item: TodoItem, last: Bool, millis: Int64): Unit {
        let selected = todoFocused && logicalRow == todos.selected
        let bg = if (selected) { Color.Rgb(38, 42, 52) } else { PANEL }
        canvas.fillRect(Rect(area.x, area.y + viewRow, area.width, 1), Style(bg: bg))
        let branch = if (caps.unicode) {
            if (last) { "  └─ " } else { "  ├─ " }
        } else {
            if (last) { "  `- " } else { "  |- " }
        }
        let box = if (caps.unicode) {
            if (item.done) { "☑ " } else { "☐ " }
        } else {
            if (item.done) { "[x] " } else { "[ ] " }
        }
        let text = branch + box + item.title
        let fg = if (item.done) { DIM } else if (selected) { Color.White } else { MUTED }
        canvas.drawText(area.x, area.y + viewRow, truncateText(text, area.width), Style(fg: fg, bg: bg))
        if (selected) {
            let prefixWidth: Int64 = if (caps.unicode) { 7 } else { 9 }
            drawTodoLight(canvas, area, viewRow, item.title, prefixWidth, millis, bg)
        }
    }

    private func drawTodoLight(canvas: Canvas, area: Rect, viewRow: Int64, text: String, start: Int64, millis: Int64, bg: Color): Unit {
        let width = min(max(0, area.width - start), text.size)
        if (width <= 0) { return }
        let position = positiveMod(millis / 83, width)
        canvas.drawText(area.x + start + position, area.y + viewRow, text[position..position + 1], Style(fg: Color.Rgb(255, 238, 170), bg: bg, modifier: Modifier.strong()))
    }

    private func drawTranscript(frame: Frame, canvas: Canvas, area: Rect, millis: Int64): Unit {
        let staticArea = Rect(area.x, area.y, area.width, max(0, area.height - 2))
        if (frame.isDirty(staticArea)) { drawTranscriptStatic(canvas, area) }
        let typingArea = transcriptTypingArea()
        if (frame.isDirty(typingArea)) {
            canvas.fillRect(typingArea, Style(bg: PANEL))
            drawTypingLight(canvas, typingArea, millis)
        }
    }

    private func drawTranscriptStatic(canvas: Canvas, area: Rect): Unit {
        drawPanel(canvas, area, " Transcript ")
        var y = area.y + 1
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 3), "User", "写一个外观复刻版 oh-my-pi", Color.Rgb(34, 29, 26))
        y += 4
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 4), "Assistant", "I will build a terminal-native skin with welcome card, transcript, composer, and status segments.", Color.Rgb(42, 37, 48))
        y += 5
        drawMessage(canvas, Rect(area.x + 2, y, area.width - 4, 4), "Tool", "cjtui: Canvas + Style + Composer + CommandPalette + Tick animation", Color.Rgb(22, 26, 32))
        canvas.drawText(area.x + 4, min(area.bottom - 2, y + 3), "approval gate: ready", Style(fg: RED, bg: Color.Rgb(22, 26, 32)))
    }

    private func drawMessage(canvas: Canvas, area: Rect, title: String, body: String, bg: Color): Unit {
        canvas.fillRect(area, Style(bg: bg))
        drawBox(canvas, area, Style(fg: DIM, bg: bg))
        canvas.drawText(area.x + 2, area.y, " " + title + " ", Style(fg: Color.Rgb(178, 129, 214), bg: bg, modifier: Modifier.strong()))
        canvas.drawText(area.x + 2, area.y + 1, truncateText(body, max(1, area.width - 4)), Style(fg: Color.White, bg: bg))
        if (area.height > 3) {
            canvas.drawText(area.x + 2, area.y + 2, truncateText("status: rendered  public API only", max(1, area.width - 4)), Style(fg: MUTED, bg: bg))
        }
    }

    private func drawStatus(canvas: Canvas, area: Rect): Unit {
        canvas.fillRect(area, Style(bg: STATUS_BG))
        var x = area.x
        x = segment(canvas, x, area.y, " PI ", ORANGE, Color.Black)
        x = segment(canvas, x, area.y, " " + mode + " ", Color.Rgb(215, 135, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " examples/oh_my_pi_skin ", Color.Rgb(0, 175, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " git dirty ", Color.Rgb(215, 175, 95), STATUS_BG)
        x = segment(canvas, x, area.y, " ctx 38% ", Color.Rgb(135, 135, 175), STATUS_BG)
        x = segment(canvas, x, area.y, " subagents 3 ", ACCENT, STATUS_BG)
        x = segment(canvas, x, area.y, spinnerText(statusMillis), GREEN, STATUS_BG)
        if (x < area.right) {
            canvas.drawText(x, area.y, spaces(area.right - x), Style(bg: STATUS_BG))
        }
    }

    private func segment(canvas: Canvas, x: Int64, y: Int64, text: String, fg: Color, bg: Color): Int64 {
        canvas.drawText(x, y, text, Style(fg: fg, bg: bg, modifier: Modifier.strong()))
        x + text.size
    }

    private func drawPanel(canvas: Canvas, area: Rect, title: String): Unit {
        canvas.fillRect(area, Style(bg: PANEL))
        drawBox(canvas, area, Style(fg: BLUE, bg: PANEL))
        canvas.drawText(area.x + 3, area.y, title, Style(fg: MUTED, bg: PANEL, modifier: Modifier.strong()))
    }

    private func drawPiLogo(canvas: Canvas, area: Rect, millis: Int64): Unit {
        let logo = ["▀██████████▀", " ╘██    ██  ", "  ██    ██  ", "  ██    ██  ", " ▄██▄  ▄██▄ "]
        for (i in 0..logo.size) {
            let color = gradientColor(i + millis / 160)
            canvas.drawText(area.x, area.y + i, logo[i], Style(fg: color, bg: PANEL_2, modifier: Modifier.strong()))
        }
        canvas.drawText(area.x + 8, area.y + 3, "[]", Style(fg: ORANGE, bg: PANEL_2, modifier: Modifier.strong()))
    }

    private func gradientColor(i: Int64): Color {
        match (i % 5) {
            case 0 => PINK
            case 1 => VIOLET
            case 2 => CYAN
            case 3 => Color.Rgb(120, 255, 220)
            case _ => ORANGE
        }
    }

    private func drawLightSweep(canvas: Canvas, area: Rect, millis: Int64, bg: Color): Unit {
        if (area.width <= 8 || area.height <= 2) { return }
        let span = max(1, area.width - 4)
        let head = area.x + 2 + positiveMod(millis / 42, span)
        let y = area.y + 1 + positiveMod(millis / 250, max(1, area.height - 2))
        for (i in 0..5) {
            let x = head - i
            if (x >= area.x + 2 && x < area.right - 2) {
                let color = match (i) {
                    case 0 => Color.Rgb(255, 230, 150)
                    case 1 => ACCENT
                    case 2 => ORANGE
                    case _ => Color.Rgb(90, 60, 36)
                }
                canvas.drawText(x, y, "=", Style(fg: color, bg: bg, modifier: Modifier.strong()))
            }
        }
    }

    private func drawHeroSnow(canvas: Canvas, area: Rect, millis: Int64, bg: Color): Unit {
        if (area.width < 8 || area.height < 5) { return }
        let innerWidth = area.width - 6
        let fallHeight = area.height - 3
        let step = millis / 66
        for (i in 0..48) {
            let speed = 2 + i % 4
            let fall = step / speed + i * 5
            let y = positiveMod(fall, fallHeight)
            let cycle = fall / fallHeight
            let drift = positiveMod(step / (3 + i % 3) + i * 7, 9) - 4
            let x = positiveMod(i * 17 + cycle * 13 + drift, innerWidth)
            let color = match (i % 3) {
                case 0 => Color.Rgb(235, 248, 255)
                case 1 => Color.Rgb(150, 205, 235)
                case _ => Color.Rgb(92, 125, 150)
            }
            let symbol = if (caps.unicode) {
                match (i % 3) {
                    case 0 => "❄"
                    case 1 => "·"
                    case _ => "•"
                }
            } else {
                match (i % 3) {
                    case 0 => "*"
                    case 1 => "."
                    case _ => "+"
                }
            }
            canvas.drawText(area.x + 3 + x, area.y + 1 + y, symbol, Style(fg: color, bg: bg))
        }
    }

    private func drawHeroSnowPile(canvas: Canvas, area: Rect, millis: Int64, bg: Color): Unit {
        if (area.width < 8 || area.height < 5) { return }
        let innerWidth = area.width - 6
        let border = if (caps.unicode) { "─" } else { "-" }
        canvas.drawLine(
            area.x + 3,
            area.bottom - 1,
            area.right - 4,
            area.bottom - 1,
            border,
            Style(fg: Color.Rgb(48, 62, 72), bg: bg)
        )

        let melting = positiveMod(millis, 12000) >= 8000
        if (snowPileWidth == innerWidth) {
            for (column in 0..innerWidth) {
                let depth = snowPile[column]
                if (depth <= 0) { continue }
                let pileColor = if (melting) {
                    Color.Rgb(120, 165, 188)
                } else {
                    Color.Rgb(225, 242, 250)
                }
                let pile = if (caps.unicode) {
                    if (melting && column % 7 == 0) {
                        "·"
                    } else {
                        match (depth) {
                            case 1 => "▂"
                            case 2 => "▄"
                            case 3 => "▆"
                            case _ => "█"
                        }
                    }
                } else {
                    if (melting && column % 7 == 0) { "." } else { "#" }
                }
                canvas.drawText(area.x + 3 + column, area.bottom - 1, pile, Style(fg: pileColor, bg: bg))
            }
        }
    }

    private func advanceHeroSnow(nextMillis: Int64): Unit {
        let innerWidth = heroArea.width - 6
        let fallHeight = heroArea.height - 3
        if (innerWidth <= 0 || fallHeight <= 0) { return }
        ensureSnowPile(innerWidth)

        let oldPhase = positiveMod(heroMillis, 12000)
        let nextPhase = positiveMod(nextMillis, 12000)
        if (nextMillis < heroMillis || nextPhase < oldPhase) {
            resetSnowPile(innerWidth)
        }

        if (nextPhase < 8000) {
            let oldStep = heroMillis / 66
            let nextStep = nextMillis / 66
            for (i in 0..48) {
                if (i % 3 != 0) { continue }
                let speed = 2 + i % 4
                let oldFall = oldStep / speed + i * 5
                let nextFall = nextStep / speed + i * 5
                let oldCycle = oldFall / fallHeight
                let nextCycle = nextFall / fallHeight
                if (nextCycle > oldCycle) {
                    let drift = positiveMod(nextStep / (3 + i % 3) + i * 7, 9) - 4
                    let column = positiveMod(i * 17 + nextCycle * 13 + drift, innerWidth)
                    depositSnow(column)
                }
            }
        } else {
            let oldMeltStep = heroMillis / 80
            let nextMeltStep = nextMillis / 80
            var meltStep = oldMeltStep + 1
            while (meltStep <= nextMeltStep) {
                for (i in 0..4) {
                    let column = positiveMod(meltStep * 11 + i * 19, innerWidth)
                    if (snowPile[column] > 0) {
                        snowPile[column] = snowPile[column] - 1
                    }
                }
                meltStep++
            }
        }
    }

    private func ensureSnowPile(width: Int64): Unit {
        if (snowPileWidth != width) { resetSnowPile(width) }
    }

    private func resetSnowPile(width: Int64): Unit {
        snowPile = ArrayList<Int64>()
        snowPileWidth = width
        for (_ in 0..width) { snowPile.add(0) }
    }

    private func depositSnow(column: Int64): Unit {
        var target = column
        if (column > 0 && snowPile[column - 1] < snowPile[target]) {
            target = column - 1
        }
        if (column + 1 < snowPileWidth && snowPile[column + 1] < snowPile[target]) {
            target = column + 1
        }
        if (snowPile[target] < 4) {
            snowPile[target] = snowPile[target] + 1
        }
    }

    private func drawMarquee(canvas: Canvas, area: Rect, text: String, millis: Int64, style: Style): Unit {
        if (area.width <= 0) { return }
        let padded = text + "   " + text
        let start = positiveMod(millis / 160, max(1, text.size))
        let view = sliceWrapAscii(padded, start, area.width)
        canvas.drawText(area.x, area.y, view, style)
    }

    private func drawTypingLight(canvas: Canvas, area: Rect, millis: Int64): Unit {
        if (area.width <= 0) { return }
        let prefix = "assistant is thinking"
        canvas.drawText(area.x, area.y, truncateText(prefix, area.width), Style(fg: MUTED, bg: PANEL))
        let dots = positiveMod(millis / 250, 4)
        for (i in 0..dots) {
            let x = area.x + min(area.width - 1, prefix.size + i)
            canvas.drawText(x, area.y, ".", Style(fg: ACCENT, bg: PANEL, modifier: Modifier.strong()))
        }
        let lightX = area.x + positiveMod(millis / 83, max(1, area.width))
        canvas.drawText(lightX, area.y, if (caps.unicode) { "·" } else { "." }, Style(fg: Color.Rgb(255, 230, 140), bg: PANEL, modifier: Modifier.strong()))
    }

    private func spinnerText(millis: Int64): String {
        match ((millis / 83) % 4) {
            case 0 => " / active "
            case 1 => " - active "
            case 2 => " \\ active "
            case _ => " | active "
        }
    }

    private func positiveMod(value: Int64, modulus: Int64): Int64 {
        if (modulus <= 0) { return 0 }
        let raw = value % modulus
        if (raw < 0) { raw + modulus } else { raw }
    }

    private func sliceWrapAscii(text: String, start: Int64, width: Int64): String {
        if (width <= 0 || text.size == 0) { return "" }
        var out = ""
        var i: Int64 = 0
        while (i < width) {
            let index = positiveMod(start + i, text.size)
            out += text[index..index + 1]
            i += 1
        }
        out
    }

    private func drawCornerMarks(canvas: Canvas, area: Rect): Unit {
        let style = Style(fg: Color.Rgb(80, 80, 86), bg: Color.Rgb(10, 12, 16))
        drawOpenCorner(canvas, area.x + 1, area.y + 1, "tl", style)
        drawOpenCorner(canvas, area.right - 4, area.y + 1, "tr", style)
        drawOpenCorner(canvas, area.x + 1, area.bottom - 3, "bl", style)
        drawOpenCorner(canvas, area.right - 4, area.bottom - 3, "br", style)
    }

    private func drawCompact(canvas: Canvas, area: Rect): Unit {
        let fit = SizeGuard(76, 21).fit(area)
        let box = fit.content
        canvas.fillRect(box, Style(bg: PANEL))
        drawBox(canvas, box, Style(fg: ORANGE, bg: PANEL))
        canvas.drawText(box.x + 2, box.y + 1, "oh my PI", Style(fg: ORANGE, bg: PANEL, modifier: Modifier.strong()))
        canvas.drawText(box.x + 2, box.y + 3, "terminal too small for full skin", Style(fg: Color.White, bg: PANEL))
        canvas.drawText(box.x + 2, box.y + 4, "need at least 76x21 cells", Style(fg: MUTED, bg: PANEL))
    }

    private func truncateText(text: String, width: Int64): String {
        if (width <= 0) { return "" }
        if (text.size <= width) { return text }
        if (width <= 3) { return text[0..width] }
        text[0..max(0, width - 3)] + "..."
    }

    private func drawBox(canvas: Canvas, area: Rect, style: Style): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        let h = if (caps.unicode) { "─" } else { "-" }
        let v = if (caps.unicode) { "│" } else { "|" }
        let tl = if (caps.unicode) { "╭" } else { "+" }
        let tr = if (caps.unicode) { "╮" } else { "+" }
        let bl = if (caps.unicode) { "╰" } else { "+" }
        let br = if (caps.unicode) { "╯" } else { "+" }

        if (area.width == 1) {
            for (y in area.y..area.bottom) {
                canvas.drawText(area.x, y, v, style)
            }
            return
        }
        if (area.height == 1) {
            canvas.drawText(area.x, area.y, tl + repeatGlyph(h, area.width - 2) + tr, style)
            return
        }

        canvas.drawText(area.x, area.y, tl + repeatGlyph(h, area.width - 2) + tr, style)
        for (y in area.y + 1..area.bottom - 1) {
            canvas.drawText(area.x, y, v, style)
            canvas.drawText(area.right - 1, y, v, style)
        }
        canvas.drawText(area.x, area.bottom - 1, bl + repeatGlyph(h, area.width - 2) + br, style)
    }

    private func drawOpenCorner(canvas: Canvas, x: Int64, y: Int64, kind: String, style: Style): Unit {
        let h = if (caps.unicode) { "─" } else { "-" }
        let v = if (caps.unicode) { "│" } else { "|" }
        let tl = if (caps.unicode) { "╭" } else { "+" }
        let tr = if (caps.unicode) { "╮" } else { "+" }
        let bl = if (caps.unicode) { "╰" } else { "+" }
        let br = if (caps.unicode) { "╯" } else { "+" }
        match (kind) {
            case "tl" =>
                canvas.drawText(x, y, tl + h + h, style)
                canvas.drawText(x, y + 1, v, style)
            case "tr" =>
                canvas.drawText(x, y, h + h + tr, style)
                canvas.drawText(x + 2, y + 1, v, style)
            case "bl" =>
                canvas.drawText(x, y, v, style)
                canvas.drawText(x, y + 1, bl + h + h, style)
            case _ =>
                canvas.drawText(x + 2, y, v, style)
                canvas.drawText(x, y + 1, h + h + br, style)
        }
    }

    private func repeatGlyph(glyph: String, count: Int64): String {
        var out = ""
        for (_ in 0..max(0, count)) {
            out += glyph
        }
        out
    }

    private func spaces(width: Int64): String {
        var out = ""
        for (_ in 0..max(0, width)) {
            out += " "
        }
        out
    }
}

main(): Int64 {
    let app = OhMyPiSkin()
    App(bracketedPaste: true, hideCursor: false).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
