package cjtui_form_studio

import core.*

class FormStudio {
    let focus = FocusManager()
    let interaction: ModalFocusState
    let saveDialog = Dialog(title: "Save profile", body: "Save the current profile? F1 opens help.", buttons: ["Cancel", "Save"])
    var regions = Array<Rect>(9, repeat: Rect(0, 0, 0, 0))
    var screen = Rect(0, 0, 80, 24)
    let name = Input(value: "Ada", cursor: 3, block: Block(title: "Name"))
    let notes = TextArea(value: "Ships weekly\nKeeps docs current", block: Block(title: "Notes"), lineNumbers: true)
    let enabled = Checkbox("Enable notifications", checked: true)
    let plan = RadioGroup(["Free", "Team", "Enterprise"], selected: 1, block: Some(Block(title: "Plan")))
    let role = Select(["Developer", "Reviewer", "Operator"], selected: 0, block: Block(title: "Role"))
    let region = Dropdown(["local", "staging", "production"], selected: 1, placeholder: "Region")
    let tags = MultiSelect(["docs", "runtime", "widgets", "release"], selected: [0, 2])
    let date = DatePicker(year: 2026, month: 6, day: 30)
    var status = "Tab changes focus. Enter/Space edits focused controls."

    init() {
        interaction = ModalFocusState(focus, keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.F(2))], "save")]))
        for (id in ["name", "notes", "enabled", "plan", "role", "region", "tags", "date", "submit"]) {
            focus.add(id)
        }
    }

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC => return ControlFlow.Exit
                    case _ => ()
                }
                if (interaction.handle(key)) { return ControlFlow.Continue }
                if (interaction.active().isSome()) { routeModalKey(key); return ControlFlow.Continue }
                if (interaction.actionFor(key) == Some("save")) { openSave(); return ControlFlow.Continue }
                routeKey(key)
            case Event.Paste(text) =>
                if (interaction.active().isNone()) { routePaste(text) }
            case Event.Mouse(mouse) => routeMouse(mouse)
            case _ => ()
        }
        ControlFlow.Continue
    }

    private func routePaste(text: String): Unit {
        match (focus.current()) {
            case Some("name") =>
                let inserted = text.trimAscii()
                let cursor = name.cursor
                name.setValue(
                    name.value[..cursor] + inserted + name.value[cursor..],
                    cursor: cursor + inserted.size
                )
                status = "pasted into name"
            case Some("notes") =>
                notes.paste(text)
                status = "pasted into notes"
            case _ => ()
        }
    }

    private func routeKey(key: KeyEvent): Unit {
        match (focus.current()) {
            case Some("name") => _ = name.handle(key)
            case Some("notes") => _ = notes.handle(key)
            case Some("enabled") => _ = enabled.handle(key)
            case Some("plan") => _ = plan.handle(key)
            case Some("role") =>
                match (role.handle(key)) {
                    case Some(value) => status = "role selected: " + value
                    case None => ()
                }
            case Some("region") =>
                match (region.handle(key)) {
                    case Some(value) => status = "region selected: " + value
                    case None => ()
                }
            case Some("tags") => _ = tags.handle(key)
            case Some("date") => _ = date.handle(key)
            case Some("submit") =>
                match (key.code) {
                    case KeyCode.Enter => openSave()
                    case _ => ()
                }
            case _ => ()
        }
    }

    func render(frame: Frame): Unit {
        screen = frame.area
        let root = Layout.vertical([
            Constraint.Length(1),
            Constraint.Min(14),
            Constraint.Length(1)
        ]).withMargin(Spacing.all(1)).split(frame.area)
        frame.renderWidget(MenuBar(["Profile", "Access", "Review"], selected: 1), root[0])

        let cols = Layout.horizontal([Constraint.Percent(42), Constraint.Percent(32), Constraint.Min(18)]).withGap(1).split(root[1])
        let left = Layout.vertical([Constraint.Length(3), Constraint.Min(6), Constraint.Length(2), Constraint.Length(2)]).withGap(1).split(cols[0])
        frame.renderWidget(name, left[0])
        frame.renderWidget(notes, left[1])
        frame.renderWidget(Checkbox("Enable notifications", checked: enabled.checked, focused: focus.isFocused("enabled")), left[2])
        frame.renderWidget(Button("Save profile", focused: focus.isFocused("submit")), left[3])

        let mid = Layout.vertical([Constraint.Length(5), Constraint.Length(4), Constraint.Min(4)]).withGap(1).split(cols[1])
        frame.renderWidget(plan, mid[0])
        frame.renderWidget(role, mid[1])
        frame.renderWidget(region, mid[2])

        let right = Layout.vertical([Constraint.Length(5), Constraint.Length(2), Constraint.Min(2)]).withGap(1).split(cols[2])
        frame.renderWidget(tags, right[0])
        frame.renderWidget(date, right[1])
        frame.renderWidget(Paragraph("focus: " + focusLabel() + "\nCtrl-C exits", block: Block(title: "State")), right[2])
        frame.renderWidget(StatusBar(left: status, right: date.value(), style: Style(fg: Color.White, bg: Color.Blue)), root[2])
        regions = [left[0], left[1], left[2], left[3], mid[0], mid[1], mid[2], right[0], right[1]]
        if (interaction.active().isSome()) {
            if (interaction.active() == Some("help")) {
                frame.renderWidget(Dialog(title: "Save help", body: "Save writes the current form. Esc returns to confirmation."), frame.area)
            } else {
                saveDialog.selected = if (interaction.focus().current() == Some("confirm")) { 1 } else { 0 }
                frame.renderWidget(saveDialog, frame.area)
            }
            return
        }
        match (focus.current()) {
            case Some("name") => frame.setCursor(name.cursorPosition(left[0]))
            case Some("notes") => frame.setCursor(notes.cursorPosition(left[1]))
            case _ => ()
        }
    }

    func openSave(): Unit {
        _ = interaction.open("save", ["cancel", "confirm"], keymap: KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.F(1))], "help")]))
    }

    private func finishSave(action: String): Unit {
        if (action == "Save") { status = "saved profile for " + name.value }
        _ = interaction.close()
    }

    private func routeModalKey(key: KeyEvent): Unit {
        if (interaction.active() == Some("help")) {
            match (key.code) { case KeyCode.Enter => _ = interaction.close(); case _ => () }
            return
        }
        if (interaction.actionFor(key) == Some("help")) { _ = interaction.open("help", ["close"]); return }
        saveDialog.selected = if (interaction.focus().current() == Some("confirm")) { 1 } else { 0 }
        match (saveDialog.handle(key)) {
            case Some(action) => finishSave(action)
            case None => _ = interaction.focus().focus(if (saveDialog.selected == 1) { "confirm" } else { "cancel" })
        }
    }

    private func routeMouse(mouse: MouseEvent): Unit {
        if (interaction.active().isSome()) {
            if (interaction.active() == Some("save")) {
                match (saveDialog.handleMouse(mouse, screen)) { case Some(action) => finishSave(action); case None => () }
            }
            return
        }
        var handled = false
        var id = ""
        if (widgetHitTest(mouse, regions[0])) { handled = name.handleMouse(mouse, regions[0]); id = "name" }
        else if (widgetHitTest(mouse, regions[1])) { handled = notes.handleMouse(mouse, regions[1]); id = "notes" }
        else if (widgetHitTest(mouse, regions[2])) { handled = enabled.handleMouse(mouse, regions[2]); id = "enabled" }
        else if (widgetHitTest(mouse, regions[3])) { handled = Button("Save").handleMouse(mouse, regions[3]); id = "submit"; if (handled) { openSave() } }
        else if (widgetHitTest(mouse, regions[4])) { handled = plan.handleMouse(mouse, regions[4]); id = "plan" }
        else if (widgetHitTest(mouse, regions[5])) { _ = role.handleMouse(mouse, regions[5]); handled = true; id = "role" }
        else if (widgetHitTest(mouse, regions[6])) { _ = region.handleMouse(mouse, regions[6]); handled = true; id = "region" }
        else if (widgetHitTest(mouse, regions[7])) { handled = tags.handleMouse(mouse, regions[7]); id = "tags" }
        if (handled) {
            match ((mouse.kind, mouse.button)) { case (MouseKind.Down, MouseButton.Left) => _ = focus.focus(id); case _ => () }
        }
    }

    private func focusLabel(): String {
        match (focus.current()) {
            case Some(id) => id
            case None => "none"
        }
    }
}

main(): Int64 {
    let app = FormStudio()
    App(mouse: true, bracketedPaste: true, hideCursor: false).run(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
