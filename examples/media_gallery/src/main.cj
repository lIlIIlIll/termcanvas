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
        let cols = Layout.horizontal([Constraint.Percent(40), Constraint.Percent(30), Constraint.Min(20)]).withGap(1).split(rows[1])
        frame.addMedia(mediaPlacementWithAdapter("main", source, Rect(cols[0].x, cols[0].y, min(24, cols[0].width), min(8, cols[0].height)), caps, adapter: adapter))
        frame.renderWidget(DocumentView(Document([DocumentLine.image(source, alt: "document image", mediaHeight: 4)]), block: Block(title: "Document image")), cols[1])
        let node = ViewNode("thumb", tag: "img", inlineStyle: StyleDeclaration.parse("width: 18; height: 5; object-fit: contain")).setMedia(source)
        node.setArea(cols[2])
        node.render(frame, StyleSheet())
        frame.renderWidget(StatusBar(left: "media_gallery  q quit", right: mediaProtocolName(protocol), style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

main(): Int64 {
    let app = MediaGallery()
    App().runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
