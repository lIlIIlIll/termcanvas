package cjtui_form_studio

import core.*

class FormStudio {
    let focus = FocusManager()
    let name = Input(value: "Ada", cursor: 3, block: Block(title: "Name"))
    let notes = TextArea(value: "Ships weekly\nKeeps docs current", block: Block(title: "Notes"), lineNumbers: true)
    let enabled = Checkbox("Enable notifications", checked: true)
    let plan = RadioGroup(["Free", "Team", "Enterprise"], selected: 1)
    let role = Select(["Developer", "Reviewer", "Operator"], selected: 0, block: Block(title: "Role"))
    let region = Dropdown(["local", "staging", "production"], selected: 1, placeholder: "Region")
    let tags = MultiSelect(["docs", "runtime", "widgets", "release"], selected: [0, 2])
    let date = DatePicker(year: 2026, month: 6, day: 30)
    var status = "Tab changes focus. Enter/Space edits focused controls."

    init() {
        for (id in ["name", "notes", "enabled", "plan", "role", "region", "tags", "date", "submit"]) {
            focus.add(id)
        }
    }

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => return ControlFlow.Exit
                    case _ => ()
                }
                if (focus.handle(key)) { return ControlFlow.Continue }
                routeKey(key)
            case Event.Paste(text) =>
                routePaste(text)
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
                    case KeyCode.Enter => status = "saved profile for " + name.value
                    case _ => ()
                }
            case _ => ()
        }
    }

    func render(frame: Frame): Unit {
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
        frame.renderWidget(RadioGroup(["Free", "Team", "Enterprise"], selected: plan.selected, focused: focus.isFocused("plan"), block: Block(title: "Plan")), mid[0])
        frame.renderWidget(role, mid[1])
        frame.renderWidget(region, mid[2])

        let right = Layout.vertical([Constraint.Length(5), Constraint.Length(2), Constraint.Min(2)]).withGap(1).split(cols[2])
        frame.renderWidget(tags, right[0])
        frame.renderWidget(date, right[1])
        frame.renderWidget(Paragraph("focus: " + focusLabel() + "\nq/Ctrl-C exits", block: Block(title: "State")), right[2])
        frame.renderWidget(StatusBar(left: status, right: date.value(), style: Style(fg: Color.White, bg: Color.Blue)), root[2])
        match (focus.current()) {
            case Some("name") => frame.setCursor(name.cursorPosition(left[0]))
            case Some("notes") => frame.setCursor(notes.cursorPosition(left[1]))
            case _ => ()
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
