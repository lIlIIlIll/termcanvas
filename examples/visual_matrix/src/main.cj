package termcanvas_visual_matrix

import core.*
import diff.*
import game.*
import media.*
import terminal.*
import markdown_adapter.*
import std.convert.*
import std.env.*

class MatrixTranscriptSource <: VirtualTranscriptSource {
    public func size(): Int64 { 1 }
    public func itemId(_: Int64): String { "one" }
    public func itemTitle(_: Int64): String { "Activity" }
    public func revision(_: Int64): Int64 { 1 }
    public func document(_: Int64, _: Int64, _: String): Document { Document.plain("Hello 世界") }
}

class BufferPrimitive <: Widget {
    let subject: String
    let theme: Theme
    init(subject: String, theme: Theme) { this.subject = subject; this.theme = theme }
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        if (subject == "core.Buffer.setCell") { buffer.setCell(area.x, area.y, Cell("X", style: theme.accent)) }
        else if (subject == "core.Buffer.setString") { buffer.setString(area.x, area.y, if (area.width >= 5) { "Hello" } else { "H" }, style: theme.accent) }
        else if (subject == "core.Buffer.fill") { buffer.fill(area, style: theme.raisedSurface) }
        else if (subject == "core.Buffer.fillRect") { buffer.fillRect(area.x, area.y, area.width, area.height, style: theme.raisedSurface) }
        else if (subject == "core.Buffer.fillLine") { buffer.fillLine(area.y, area.x, area.width, style: theme.raisedSurface) }
        else if (subject == "core.Buffer.hline") { buffer.hline(area.x, area.y, area.width, "-", theme.accent) }
        else if (subject == "core.Buffer.vline") { buffer.vline(area.x, area.y, area.height, "|", theme.accent) }
        else if (subject == "core.Buffer.writeAsciiSpan") { _ = buffer.writeAsciiSpan(area.x, area.y, if (area.width >= 5) { "Hello" } else { "H" }, style: theme.accent) }
        else if (subject == "core.Buffer.blitFrom") {
            let source = Buffer(Rect(0, 0, area.width, area.height))
            source.setString(0, 0, "Hello", style: theme.accent)
            buffer.blitFrom(source, source.area, area.x, area.y)
        } else if (subject == "core.Buffer.addMedia") {
            let source = MediaSource("sample", "sample", alt: "Sample")
            buffer.addMedia(MediaPlacement("sample", source, area, frame: Some(MediaFrameData.text("Sample media"))))
        } else {
            throw IllegalArgumentException("unsupported buffer primitive")
        }
    }
}

// Exercise game drawing APIs against a real buffer; the camera offset is
// deliberately visible and the sprite's spaces leave existing cells intact.
class GamePrimitive <: Widget {
    let subject: String
    let state: String
    let theme: Theme
    init(subject: String, state: String, theme: Theme) {
        this.subject = subject
        this.state = state
        this.theme = theme
    }
    public func render(area: Rect, buffer: Buffer): Unit {
        let camera = Camera2D(origin: if (state == "offset") { Vec2(x: 1.0) } else { Vec2() }, viewport: area)
        if (subject == "game.TileMap.render") {
            TileMap(["########", "# A 界 #", "########"]).render(area, buffer, camera: camera)
        } else {
            let sprite = Sprite2D(["@ @", "###"], style: theme.accent)
            let transform = Transform2D(position: Vec2(x: 1.0, y: 1.0))
            let renderer = SpriteRenderer()
            if (subject == "game.SpriteRenderer.drawSprite") {
                renderer.drawSprite(Canvas(buffer, area), transform, sprite, camera)
            } else if (subject == "game.SpriteRenderer.render") {
                let entity = EntityWorld().create()
                let transforms = ComponentStore<Transform2D>()
                let sprites = ComponentStore<Sprite2D>()
                transforms.insert(entity, transform)
                sprites.insert(entity, sprite)
                renderer.render(area, buffer, transforms, sprites, camera: camera)
            } else {
                throw IllegalArgumentException("unsupported game primitive")
            }
        }
    }
}

// Cases share the same content so visual differences demonstrate override
// behavior instead of unrelated text or layout changes.
func styledMatrixWidget(state: String): Widget {
    var modifier = Modifier.strong()
    modifier.italic = true
    modifier.underline = true
    let base = Style(fg: Color.Green, bg: Color.Blue, modifier: modifier)
    if (state == "clear-background") {
        return StyledWidget(Paragraph("Styled 世界", style: base), override: StyleOverride(bg: Color.Reset))
    }
    if (state == "clear-modifiers") {
        return StyledWidget(Paragraph("Styled 世界", style: base),
            override: StyleOverride(bold: false, italic: false, underline: false))
    }
    if (state == "nested") {
        let inner = StyledWidget(Paragraph("inner", style: base), override: StyleOverride(fg: Color.Red, bold: true))
        return StyledWidget(HBox([Paragraph("outer", style: base), inner]),
            override: StyleOverride(bg: Color.Reset, bold: false, italic: false, underline: false))
    }
    StyledWidget(Paragraph("Styled 世界", style: base), override: StyleOverride(fg: Color.Yellow, bold: true))
}

func markdownMatrixWidget(state: String, themeName!: String = "indigo"): Widget {
    if (state == "explicit-theme") {
        let custom = DocumentTheme(link: Style(fg: Color.Magenta, bg: Color.Blue))
        return ThemedMarkdownView("[link](https://example.test)", theme: Some(custom))
    }
    if (state == "syntax-off" || state == "syntax-on") {
        let syntax: ?SyntaxHighlightConfig = if (state == "syntax-on") {
            // Syntax colors are application-supplied; choose a darker token
            // explicitly on the light canvas, without changing adapter policy.
            let keywordColor = if (themeName == "light") { "#006D81" } else { "cyan" }
            Some(parseSyntaxHighlightConfig("syntax 1\nlanguage workflow\nkeywords task\nstyle keyword ${keywordColor} bold\nend"))
        } else { None }
        return ThemedMarkdownView("```workflow\ntask item\n```", syntax: syntax)
    }
    if (state == "scroll-start" || state == "scroll-next") {
        return ThemedMarkdownView("First line\n\nSecond line\n\nThird line", scroll: if (state == "scroll-next") { 2 } else { 0 })
    }
    ThemedMarkdownView("# Heading\nHello **world**")
}

func tabsMatrixWidget(state: String, theme: Theme): Tabs {
    let tabs = Tabs(["Alpha", "Beta"], selected: 1)
    tabs.setTheme(Some(theme))
    tabs.setFocused(state == "focused")
    tabs
}

// These are fixed render inputs, not a clock or an animation scheduler.
func matrixFrameIndex(state: String): Int64 {
    if (state == "frame-1") { 1 }
    else if (state == "frame-2") { 2 }
    else if (state == "frame-3") { 3 }
    else { 0 }
}

func animationMatrixWidget(state: String): AsciiAnimationView {
    let animation = AsciiAnimation([AsciiFrame(["[frame 1]"]), AsciiFrame(["[frame 2]"])])
    let second = state == "frame-1" || state == "paused-frame-1"
    let paused = state == "paused-frame-0" || state == "paused-frame-1"
    AsciiAnimationView(animation, elapsedMillis: if (second) { 83 } else { 0 }, paused: paused)
}

func progressMatrixWidget(state: String, theme: Theme): ProgressBar {
    let tiny = state == "tiny" || state.startsWith("tiny+width-")
    let mode = if (state.contains("percent") || tiny) { ProgressBarLabelMode.Percent } else if (state == "ratio") { ProgressBarLabelMode.Ratio }
        else if (state == "value") { ProgressBarLabelMode.Value } else if (state == "text") { ProgressBarLabelMode.Text("Building") }
        else { ProgressBarLabelMode.Hidden }
    let value = if (state == "empty") { 0 } else if (state == "full") { 100 } else if (tiny) { 1 } else { 37 }
    let direction = if (state.contains("vertical")) { ProgressBarDirection.Vertical } else { ProgressBarDirection.Horizontal }
    ProgressBar(value, total: if (tiny) { 10000 } else { 100 }, theme: Some(theme), labelMode: mode, direction: direction,
        indeterminate: state.startsWith("indeterminate-"), phase: if (state == "indeterminate-mid") { 20 } else { 1 })
}

// Width-specific cases remain constrained by the outer matrix allocation.
func matrixTargetWidth(subject: String, state: String): Int64 {
    if (subject == "core.ProgressBar") {
        if (state == "tiny+width-3") { return 3 }
        if (state == "tiny+width-4") { return 4 }
        if (state == "tiny+width-8") { return 8 }
    } else if (subject == "core.Tree") {
        if (state == "long-name+expanded+width-39") { return 39 }
        if (state == "long-name+expanded+width-40") { return 40 }
        if (state == "long-name+expanded+width-41") { return 41 }
        if (state == "long-name+expanded+width-42") { return 42 }
    } else if (subject == "core.VirtualTable") {
        if (state == "sort-asc+width-1" || state == "sort-desc+width-1") { return 1 }
        if (state == "sort-asc+width-2" || state == "sort-desc+width-2") { return 2 }
    }
    0
}

func matrixWidgetArea(subject: String, state: String, area: Rect): Rect {
    let target = matrixTargetWidth(subject, state)
    let height = if (subject == "core.Input") { min(Int64(1), area.height) } else { area.height }
    Rect(area.x, area.y, if (target > 0) { min(target, area.width) } else { area.width }, height)
}

func matrixWidthCaption(target: Int64, actual: Int64): String {
    "Width: target ${target}, actual ${actual}"
}

// This is the area passed to the draw API, not an independent terminal measurement.
func matrixDrawReport(area: Rect, targetWidth: Int64): String {
    "{\"effective_rect\":[${area.x},${area.y},${area.width},${area.height}],\"target_width\":${targetWidth}}"
}

func inputMatrixWidget(state: String, theme: Theme): Input {
    let empty = state.contains("empty")
    let input = Input(value: if (empty) { "" } else { "Hello 世界" }, cursor: if (empty) { 0 } else { 5 },
        placeholder: "Task name")
    input.setVisualState(focused: state.contains("focused"), disabled: state.contains("disabled"),
        error: state.contains("error"), theme: Some(theme))
    input
}

func tableMatrixWidget(state: String, theme: Theme): Table {
    let scrolled = state.contains("scrolled")
    let rows = if (scrolled) {
        [["job-1", "Done"], ["job-2", "Done"], ["job-3", "Done"], ["job-4", "Running"],
            ["job-5", "Queued"], ["job-6", "Queued"]]
    } else { [["Alpha", "Ready"], ["Beta", "Done"]] }
    let selected: ?Int64 = if (state == "no-selection") { None } else if (scrolled) { Some(3) } else { Some(0) }
    Table(["Name", "State"], rows, state: Some(TableState(selectedRow: selected, offset: if (scrolled) { 3 } else { 0 })),
        focused: state.contains("focused"), theme: theme)
}

func virtualTableMatrixWidget(state: String): VirtualTable {
    let width = if (state.contains("width-1")) { Int64(1) } else if (state.contains("width-2")) { Int64(2) } else { Int64(10) }
    if (state == "paged+custom-surface") {
        let model = PagedTableModel(pageSize: 1)
        let first = model.requestViewport(0, 1)[0]
        if (!model.accept(first, TablePage([TableDataRow("alpha", ["Alpha"])], 3))) {
            throw IllegalArgumentException("visual fixture could not load its first page")
        }
        let failed = model.requestViewport(1, 1)[0]
        if (!model.fail(failed, "Page failed")) {
            throw IllegalArgumentException("visual fixture could not record its failed page")
        }
        return VirtualTable([TableColumn("Name", width: width)], model)
    }
    let table = VirtualTable([TableColumn("Name", width: width)], 2, { i => if (i == 0) { ["Alpha"] } else { ["Beta"] } })
    if (state.startsWith("sort-")) { table.sortBy(0, descending: state.contains("sort-desc")) }
    if (state == "empty" || state == "empty+custom-surface") { table.setStatus(TableStatus.Empty) }
    else if (state == "loading" || state == "loading+custom-surface") { table.setStatus(TableStatus.Loading) }
    else if (state == "error" || state == "error+custom-surface") { table.setStatus(TableStatus.Error("Unable to load")) }
    table
}

func matrixTableSurface(frame: Frame, area: Rect, state: String, theme: Theme): Unit {
    if (state == "custom-surface" || state.contains("+custom-surface")) { frame.fill(area, theme.raisedSurface) }
}

func treeMatrixWidget(state: String, theme: Theme): Tree {
    let longName = state.contains("long-name")
    let root = TreeNode("root", if (longName) { "Workspace with a long project name 世界 and additional content" } else { "Workspace" },
        expanded: !state.contains("collapsed"), children: [TreeNode("file", "sample.cj")])
    Tree([root], selected: if (longName) { 0 } else { 1 }, focused: state.contains("focused"), theme: Some(theme))
}

func activityMatrixWidget(state: String, theme: Theme): TaskActivityView {
    let status = if (state.contains("pending")) { TaskStatus.Pending } else if (state.contains("queued")) { TaskStatus.Queued }
        else if (state.contains("paused")) { TaskStatus.Paused } else if (state.contains("done")) { TaskStatus.Done }
        else if (state.contains("failed")) { TaskStatus.Failed } else if (state.contains("cancelled")) { TaskStatus.Cancelled }
        else { TaskStatus.Running }
    let layout = if (state.contains("compact")) { TaskActivityLayout.Compact } else { TaskActivityLayout.Expanded }
    let mixed = state.contains("mixed-stages")
    let longTitle = state.contains("long-title")
    let progress = if (mixed) { TaskProgress.Items([TaskStatus.Done, TaskStatus.Running, TaskStatus.Failed,
        TaskStatus.Paused, TaskStatus.Queued, TaskStatus.Cancelled]) } else { TaskProgress.Counts(2, 5) }
    let activity = TaskActivity(if (longTitle) { "Cross-platform test suite" } else { "Build" }, status: status,
        prefix: if (longTitle) { "CI" } else { "" }, duration: if (longTitle) { "16m7s" } else { "" },
        detail: "Compiling", progressLabel: "Jobs", progress: Some(progress))
    TaskActivityView(activity, layout: layout, theme: theme)
}

func matrixCapabilities(size: Rect, glyph: String, color: String): TerminalCapabilities {
    let level: Int64 = match (color) {
        case "truecolor" => 24
        case "256" => 256
        case "16" => 16
        case "monochrome" => 1
        case _ => throw IllegalArgumentException("unknown matrix color mode")
    }
    TerminalCapabilities(size: size, unicode: glyph != "ascii", trueColor: color == "truecolor", colorLevel: level)
}

// The launcher validates every argument against the declared inventory before
// starting this process. This process reports readiness only after draw/flush.
main(args: Array<String>): Int64 {
    if (args.size != 8) { return 2 }
    let subject = args[0]
    let state = args[1]
    let themeName = args[2]
    let glyph = args[3]
    let color = args[4]
    let width = Int64.parse(args[5])
    let height = Int64.parse(args[6])
    let backend = AnsiBackend()
    let size = match (TerminalMode.size()) { case Some(value) => value; case None => return 2 }
    if ("${size.width}x${size.height}" != args[7]) { return 2 }
    let caps = matrixCapabilities(size, glyph, color)
    let icons = if (glyph == "nerd-font") { IconSet.NerdFont } else if (glyph == "ascii") { IconSet.Ascii } else { IconSet.Unicode }
    let theme = (if (themeName == "default") { Theme.default() } else if (themeName == "indigo") { Theme.indigo() }
        else if (themeName == "graphite") { Theme.graphite() } else { Theme.light() }).withIconSet(icons).adapted(caps)
    let terminal = Terminal(backend, renderMode: RenderMode.Full)
    terminal.setCapabilities(caps)
    terminal.setTheme(Some(theme))
    backend.hideCursor()
    let allocatedArea = Rect(2, 4, width, height)
    let targetWidth = matrixTargetWidth(subject, state)
    let area = matrixWidgetArea(subject, state, allocatedArea)
    _ = terminal.draw({ frame =>
        frame.fill(frame.area, theme.canvas)
        frame.canvas().drawText(1, 1, "VISUAL MATRIX / ${subject} / ${state}", theme.heading)
        if (targetWidth > 0) {
            frame.canvas().drawText(1, 2, matrixWidthCaption(targetWidth, area.width), theme.secondary)
        }
        if (subject == "core.Button") {
            frame.renderWidget(Button("Confirm", focused: state.contains("focused"), disabled: state.contains("disabled"), theme: Some(theme)), area)
        } else if (subject == "core.Checkbox") {
            frame.renderWidget(Checkbox("Enable", checked: state.contains("checked"), focused: state.contains("focused"),
                disabled: state.contains("disabled"), theme: Some(theme)), area)
        } else if (subject == "core.Block") {
            let boxState = if (state == "focused") { BoxState.Focused } else if (state == "active") { BoxState.Active }
                else if (state == "error") { BoxState.Error } else if (state == "disabled") { BoxState.Disabled } else { BoxState.Normal }
            frame.renderWidget(Block(BlockOptions(title: "Panel", state: boxState, theme: Some(theme))), area)
        } else if (subject == "core.ProgressBar") {
            frame.renderWidget(progressMatrixWidget(state, theme), area)
        } else if (subject == "core.Switch") {
            frame.renderWidget(Switch("Enable", checked: state.contains("checked"), focused: state.contains("focused"),
                disabled: state.contains("disabled"), theme: Some(theme)), area)
        } else if (subject == "core.RadioGroup") {
            frame.renderWidget(RadioGroup(["Alpha", "Beta"], selected: 1, focused: state.contains("focused"),
                disabled: state.contains("disabled"), theme: Some(theme)), area)
        } else if (subject == "core.SegmentedControl") {
            frame.renderWidget(SegmentedControl(["Alpha", "Beta"], selected: 1, focused: state.contains("focused"),
                disabled: state.contains("disabled"), theme: Some(theme)), area)
        } else if (subject == "core.Input") {
            frame.renderWidget(inputMatrixWidget(state, theme), area)
        } else if (subject == "core.ColorPicker") {
            let picker = ColorPicker()
            picker.setVisualState(focused: state.contains("focused"), disabled: state.contains("disabled"), theme: Some(theme))
            frame.renderWidget(picker, area)
        } else if (subject == "core.DatePicker") {
            let picker = DatePicker(theme: Some(theme))
            picker.setVisualState(focused: state.contains("focused"), disabled: state.contains("disabled"), theme: Some(theme))
            frame.renderWidget(picker, area)
        } else if (subject == "core.Dropdown") {
            let dropdown = Dropdown(["Alpha", "Beta"], selected: 1, open: state.contains("open"))
            dropdown.setVisualState(focused: state.contains("focused"), disabled: state.contains("disabled"), theme: Some(theme))
            frame.renderWidget(dropdown, area)
        } else if (subject == "core.Select") {
            frame.renderWidget(Select(["Alpha", "Beta"], selected: 1), area)
        } else if (subject == "core.MultiSelect") {
            frame.renderWidget(MultiSelect(["Alpha", "Beta"], cursor: 1, selected: [0]), area)
        } else if (subject == "core.Tabs") {
            frame.renderWidget(tabsMatrixWidget(state, theme), area)
        } else if (subject == "core.List") {
            frame.renderWidget(List(["Alpha", "Beta"], selected: Some(1), focused: state == "focused", theme: theme), area)
        } else if (subject == "core.Table") {
            matrixTableSurface(frame, area, state, theme)
            frame.renderWidget(tableMatrixWidget(state, theme), area)
        } else if (subject == "core.Tree") {
            frame.renderWidget(treeMatrixWidget(state, theme), area)
        } else if (subject == "core.Scrollbar") {
            frame.renderWidget(Scrollbar(20, offset: 4, viewport: 4, style: theme.secondary, thumbStyle: theme.accent), area)
        } else if (subject == "core.Paragraph") {
            frame.renderWidget(Paragraph("Hello 世界\nSecond line", style: theme.normal), area)
        } else if (subject == "core.StyledWidget") {
            frame.renderWidget(styledMatrixWidget(state), area)
        } else if (subject == "core.TextArea") {
            frame.renderWidget(TextArea(value: "Hello 世界\nSecond line", style: theme.normal), area)
        } else if (subject == "core.MarkdownTextEditor") {
            frame.renderWidget(MarkdownTextEditor(value: "# Heading\nHello"), area)
        } else if (subject == "core.MarkdownView") {
            frame.renderWidget(MarkdownView("# Heading\nHello", style: theme.normal), area)
        } else if (subject == "markdown_adapter.ThemedMarkdownView") {
            frame.renderWidget(markdownMatrixWidget(state, themeName: themeName), area)
        } else if (subject == "core.Composer") {
            frame.renderWidget(Composer(value: "Hello 世界"), area)
        } else if (subject == "core.ActivityTimeline") {
            frame.renderWidget(ActivityTimeline([ActivityStep("Build"), ActivityStep("Test")]), area)
        } else if (subject == "core.RequestDialog") {
            frame.renderWidget(RequestDialog(title: "Confirm", body: "Proceed?", theme: Some(theme)), area)
        } else if (subject == "core.Dialog") {
            frame.renderWidget(Dialog(title: "Confirm", body: "Proceed?", theme: Some(theme)), area)
        } else if (subject == "core.ConfirmDialog") {
            frame.renderWidget(ConfirmDialog("Proceed?", theme: Some(theme)), area)
        } else if (subject == "core.Menu") {
            frame.renderWidget(Menu("Actions", [MenuItem("Open"), MenuItem("Delete", enabled: false)]), area)
        } else if (subject == "core.MenuBar") {
            frame.renderWidget(MenuBar(["File", "Edit"], selected: 1), area)
        } else if (subject == "core.CommandPalette") {
            frame.renderWidget(CommandPalette([MenuItem("Open"), MenuItem("Close")], theme: Some(theme)), area)
        } else if (subject == "core.ToastManager") {
            frame.renderWidget(ToastManager(toasts: [Toast("Saved")], theme: Some(theme)), area)
        } else if (subject == "core.Spinner") {
            frame.renderWidget(Spinner(label: "Working", frame: matrixFrameIndex(state), style: theme.accent), area)
        } else if (subject == "core.MetricCard") {
            frame.renderWidget(MetricCard("RUNNING", "1 / 4", detail: "Active slots", style: theme.secondary, valueStyle: theme.accent), area)
        } else if (subject == "core.Meter") {
            frame.renderWidget(Meter("Progress", 37, style: theme.secondary, fillStyle: theme.accent), area)
        } else if (subject == "core.TimeSeriesChart") {
            frame.renderWidget(TimeSeriesChart([1, 3, 2, 5], style: theme.accent), area)
        } else if (subject == "core.HeaderBar") {
            frame.renderWidget(HeaderBar("Title", right: "Ready", style: theme.heading), area)
        } else if (subject == "core.FooterBar") {
            frame.renderWidget(FooterBar(left: "Help", right: "Quit", style: theme.secondary), area)
        } else if (subject == "core.EmptyState") {
            frame.renderWidget(EmptyState(title: "No items", detail: "Add one", style: theme.secondary), area)
        } else if (subject == "core.ErrorBox") {
            frame.renderWidget(ErrorBox("Failed", detail: "Retry"), area)
        } else if (subject == "core.LoadingOverlay") {
            frame.renderWidget(LoadingOverlay(label: "Loading", frame: matrixFrameIndex(state)), area)
        } else if (subject == "core.Skeleton") {
            frame.renderWidget(Skeleton(rows: 3, style: theme.secondary), area)
        } else if (subject == "core.InlineAlert") {
            frame.renderWidget(InlineAlert("Check input", state: StyleState.Error), area)
        } else if (subject == "core.Badge") {
            frame.renderWidget(Badge("READY", theme: Some(theme)), area)
        } else if (subject == "core.Sparkline") {
            frame.renderWidget(Sparkline([1, 3, 2, 5], style: theme.accent), area)
        } else if (subject == "core.Gauge") {
            frame.renderWidget(Gauge(37, style: theme.secondary, fillStyle: theme.accent), area)
        } else if (subject == "core.Chart") {
            frame.renderWidget(Chart([1, 3, 2, 5], style: theme.accent), area)
        } else if (subject == "core.LogView") {
            frame.renderWidget(LogView(["Build started", "Tests passed"], style: theme.normal), area)
        } else if (subject == "core.StatusBar") {
            frame.renderWidget(StatusBar(left: "Ready", right: "Quit", style: theme.surface), area)
        } else if (subject == "core.Viewport") {
            frame.renderWidget(Viewport(["First", "Second"], style: theme.normal), area)
        } else if (subject == "core.Scrollable") {
            frame.renderWidget(Scrollable(["First", "Second"], style: theme.normal), area)
        } else if (subject == "core.Panel") {
            frame.renderWidget(Panel(block: Block(BlockOptions(title: "Panel", theme: Some(theme))),
                child: Some(Paragraph("Content", style: theme.normal))), area)
        } else if (subject == "core.TaskActivityView") {
            frame.renderWidget(activityMatrixWidget(state, theme), area)
        } else if (subject == "core.TaskActivityList") {
            frame.renderWidget(TaskActivityList([TaskActivityListEntry(TaskActivity("Build", status: TaskStatus.Running))], theme: theme), area)
        } else if (subject == "core.Legend") {
            frame.renderWidget(Legend([LegendItem("Active", style: theme.accent)]), area)
        } else if (subject == "core.DocumentView") {
            frame.renderWidget(DocumentView(Document.plain("Hello 世界", style: theme.normal)), area)
        } else if (subject == "core.TranscriptView") {
            frame.renderWidget(TranscriptView(Transcript(items: [TranscriptItem("one", title: "Activity",
                body: Document.plain("Hello"))])), area)
        } else if (subject == "core.VirtualTranscriptView") {
            frame.renderWidget(VirtualTranscriptView(MatrixTranscriptSource()), area)
        } else if (subject == "core.HelpView") {
            frame.renderWidget(HelpView(KeyMap(bindings: [KeyBinding([KeyEvent(KeyCode.Char(r'q'))], "quit", description: "Quit")]), style: theme.normal), area)
        } else if (subject == "core.DebugOverlay") {
            frame.renderWidget(DebugOverlay(AppMetrics(), style: theme.accent), area)
        } else if (subject == "core.VirtualTable") {
            matrixTableSurface(frame, area, state, theme)
            frame.renderWidget(virtualTableMatrixWidget(state), area)
        } else if (subject == "core.VBox") {
            frame.renderWidget(VBox([Paragraph("First"), Paragraph("Second")]), area)
        } else if (subject == "core.HBox") {
            frame.renderWidget(HBox([Paragraph("First"), Paragraph("Second")]), area)
        } else if (subject == "core.Stack") {
            frame.renderWidget(Stack([Paragraph("First"), Paragraph("Second")]), area)
        } else if (subject == "core.Overlay") {
            frame.renderWidget(Overlay(Paragraph("First"), overlays: [Paragraph("Second")]), area)
        } else if (subject == "core.Padding") {
            frame.renderWidget(Padding(Paragraph("Content"), Spacing.all(1)), area)
        } else if (subject == "core.Margin") {
            frame.renderWidget(Margin(Paragraph("Content"), Spacing.all(1)), area)
        } else if (subject == "core.Centered") {
            frame.renderWidget(Centered(Paragraph("Content"), 10, 1), area)
        } else if (subject == "core.Dock") {
            frame.renderWidget(Dock(top: Some(Paragraph("Top")), center: Some(Paragraph("Content"))), area)
        } else if (subject == "diff.DiffView") {
            let hunk = DiffHunk("@@", lines: [DiffLine(DiffLineKind.Delete, "old"), DiffLine(DiffLineKind.Add, "new")])
            let document = DiffDocument([DiffFile("sample.cj", "sample.cj", hunks: [hunk])])
            frame.renderWidget(DiffView(document, sideBySide: state == "side-by-side", theme: Some(theme)), area)
        } else if (subject == "game.SpriteRenderer.render") {
            frame.renderWidget(GamePrimitive(subject, state, theme), area)
        } else if (subject == "game.SpriteRenderer.drawSprite") {
            frame.renderWidget(GamePrimitive(subject, state, theme), area)
        } else if (subject == "game.TileMap.render") {
            frame.renderWidget(GamePrimitive(subject, state, theme), area)
        } else if (subject == "media.AsciiAnimationView") {
            frame.renderWidget(animationMatrixWidget(state), area)
        } else if (subject == "terminal.TerminalView") {
            let transcript = TerminalTranscript(cols: 16, rows: 3)
            transcript.append("Hello world")
            frame.renderWidget(TerminalView(transcript, search: "world"), area)
        } else if (subject == "core.FilePicker") {
            let samplePath = match (getVariable("TERMCANVAS_MATRIX_SAMPLE_DIR")) { case Some(value) => value; case None => "" }
            frame.renderWidget(FilePicker(path: samplePath), area)
        } else if (subject == "core.FileDialog") {
            let samplePath = match (getVariable("TERMCANVAS_MATRIX_SAMPLE_DIR")) { case Some(value) => value; case None => "" }
            frame.renderWidget(FileDialog(path: samplePath), area)
        } else if (subject.startsWith("core.Buffer.")) {
            frame.renderWidget(BufferPrimitive(subject, theme), area)
        } else if (subject == "core.Canvas.fillRect") {
            frame.canvas(area: area).fillRect(area, theme.raisedSurface)
        } else if (subject == "core.Canvas.hline") {
            frame.canvas(area: area).hline(area.x, area.y, area.width, "-", theme.accent)
        } else if (subject == "core.Canvas.vline") {
            frame.canvas(area: area).vline(area.x, area.y, area.height, "|", theme.accent)
        } else if (subject == "core.Canvas.strokeRect") {
            frame.canvas(area: area).strokeRect(area, theme.accent)
        } else if (subject == "core.Canvas.drawLine") {
            if (area.width > 0 && area.height > 0) { frame.canvas(area: area).drawLine(area.x, area.y, area.right - 1, area.bottom - 1, "*", theme.accent) }
        } else if (subject == "core.Canvas.drawText") {
            frame.canvas(area: area).drawText(area.x, area.y, "Hello 世界", theme.accent)
        } else if (subject == "core.Canvas.drawSprite") {
            frame.canvas(area: area).drawSprite(area.x, area.y, ["First", "Second"], theme.accent)
        } else if (subject == "core.Canvas.render") {
            frame.canvas(area: area).render(Paragraph("Hello", style: theme.normal), area)
        } else if (subject == "core.Canvas.composite") {
            let surface = Surface(area)
            surface.canvas().drawText(area.x, area.y, "Hello", theme.accent)
            frame.canvas(area: area).composite(surface)
        } else if (subject == "core.Canvas.withClip") {
            frame.canvas().withClip(area).drawText(area.x, area.y, "Hello", theme.accent)
        } else if (subject == "core.Canvas.translated") {
            frame.canvas(area: area).translated(area.x, area.y).drawText(0, 0, "Hello", theme.accent)
        } else if (subject == "core.Canvas.viewport") {
            frame.canvas(area: area).viewport(Position(-area.x, -area.y)).drawText(0, 0, "Hello", theme.accent)
        } else if (subject == "core.Frame.fill") {
            frame.fill(area, theme.raisedSurface)
        } else if (subject == "core.Frame.fillRect") {
            frame.fillRect(area.x, area.y, area.width, area.height, theme.raisedSurface)
        } else if (subject == "core.Frame.renderWidget") {
            frame.renderWidget(Paragraph("Hello", style: theme.normal), area)
        } else if (subject == "core.Frame.addMedia") {
            let source = MediaSource("sample", "sample", alt: "Sample")
            frame.addMedia(MediaPlacement("sample", source, area, frame: Some(MediaFrameData.text("Sample media"))))
        } else if (subject == "core.Canvas.strokeBorder") {
            frame.canvas().strokeBorder(area, theme.border)
        } else {
            throw IllegalArgumentException("unsupported matrix subject")
        }
    })
    backend.flush()
    let stderr = getStdErr()
    stderr.write("TERMCANVAS_MATRIX_DRAWN\n${matrixDrawReport(area, targetWidth)}\n".toArray())
    stderr.flush()
    // The capture process terminates this fixture after the screenshot.
    while (true) { sleep(Duration.second) }
    0
}
