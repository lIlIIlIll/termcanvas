package cjtui_debug_lab

import core.*

class DebugLab {
    let metrics = AppMetrics()
    var caps = TerminalCapabilities()
    var focus = "unknown"
    var mouse = "none"
    var tick: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.Capabilities(c) =>
                caps = c
                UpdateResult.next()
            case Event.FocusIn =>
                focus = "in"
                UpdateResult.next()
            case Event.FocusOut =>
                focus = "out"
                UpdateResult.next()
            case Event.Mouse(m) =>
                mouse = "${m.x},${m.y}"
                UpdateResult.next()
            case Event.Tick(t) =>
                tick = t.frameIndex
                UpdateResult.next()
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case _ => UpdateResult.next()
            }
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Min(8), Constraint.Length(1)]).withMargin(Spacing.all(1)).split(frame.area)
        let body = "driver: ${caps.driverName}\nsize: ${caps.size.width}x${caps.size.height}\ncolor: ${caps.colorLevel}\nkeyboard: ${protocolName(caps.keyboardProtocol)} keyUp=${caps.keyUp} repeat=${caps.keyRepeat}\nmouseMove=${caps.mouseMove} focus=${focus} mouse=${mouse}\nrecommendedFps=${caps.recommendedFps} tick=${tick}"
        frame.renderWidget(Paragraph(body, block: Block(title: "Terminal capabilities"), wrap: WrapMode.Word), rows[0])
        frame.renderWidget(DebugOverlay(metrics), rows[1])
    }
}

func protocolName(protocol: KeyProtocol): String {
    match (protocol) {
        case KeyProtocol.Basic => "basic"
        case KeyProtocol.ModifyOtherKeys => "modifyOtherKeys"
        case KeyProtocol.Kitty => "kitty"
    }
}

main(): Int64 {
    let app = DebugLab()
    App(
        mouse: true,
        mouseMove: true,
        focusEvents: true,
        keyboard: KeyboardOptions(mode: KeyboardProtocolMode.Auto),
        targetFps: 10,
        metrics: Some(app.metrics)
    ).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
