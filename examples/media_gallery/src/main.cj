package media_gallery

import core.*
import media.*

class MediaGallery {
    var caps = TerminalCapabilities()
    let source = MediaSource("demo", "demo.png", alt: "demo image")
    let adapter = FallbackMediaAdapter()

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.Capabilities(caps) =>
                this.caps = caps
                UpdateResult.next()
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case _ => UpdateResult.next()
            }
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(3), Constraint.Min(10), Constraint.Length(1)]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        let protocol = preferredMediaProtocol(caps)
        frame.renderWidget(Paragraph("protocol: " + mediaProtocolName(protocol) + "\nkitty=${caps.kittyGraphics} sixel=${caps.sixel}", block: Block(title: "Media capabilities")), rows[0])
        let cols = Layout.horizontal([Constraint.Percent(50), Constraint.Percent(50)]).withGap(1).split(rows[1])
        frame.addMedia(mediaPlacementWithAdapter("main", source, Rect(cols[0].x, cols[0].y, min(24, cols[0].width), min(8, cols[0].height)), caps, adapter: adapter))
        frame.renderWidget(DocumentView(Document([DocumentLine.image(source, alt: "document image", mediaHeight: 4)]), block: Block(title: "Document image")), cols[1])
        frame.renderWidget(StatusBar(left: "media_gallery  q quit", right: mediaProtocolName(protocol), style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

func runHeadlessSmoke(): Int64 {
    let app = MediaGallery()
    let result = AppTestRunner.run(
        HeadlessScript().event(Event.Capabilities(TerminalCapabilities(kittyGraphics: true))).render(),
        { frame => app.render(frame) },
        { event => app.update(event) },
        options: HeadlessRunOptions(area: Rect(0, 0, 80, 24))
    )
    if (!result.passed() || result.frames.size == 0) {
        println("media_gallery headless smoke failed: runner")
        return 1
    }
    let frame = result.frames[result.frames.size - 1]
    let placements = frame.mediaPlacements()
    if (placements.size != 2) {
        println("media_gallery headless smoke failed: placements=${placements.size}")
        return 1
    }
    var direct = false
    var document = false
    for (placement in placements) {
        if (placement.id == "main" && placement.area.width > 0 && placement.area.height > 0) { direct = true }
        if (placement.id.startsWith("document:") && placement.area.width > 0 && placement.area.height > 0) { document = true }
    }
    let snapshot = result.snapshots[result.snapshots.size - 1]
    if (!direct || !document || !snapshot.contains("Media capabilities") || !snapshot.contains("Document image")) {
        println("media_gallery headless smoke failed: rendered paths")
        return 1
    }
    println("media_gallery headless smoke ok")
    0
}

main(args: Array<String>): Int64 {
    if (args.size > 0 && args[0] == "--headless-smoke") { return runHeadlessSmoke() }
    let app = MediaGallery()
    App().runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
