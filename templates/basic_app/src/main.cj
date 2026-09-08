package termcanvas_basic_app

import core.*

class DemoApp {
    var count: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r'+') => UpdateResult.withCommand(Command.Message("inc"))
                case _ => UpdateResult.next()
            }
            case Event.Message("inc") =>
                count++
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(
            Paragraph("count: ${count}\n+: increment\nq/Ctrl-C: quit", block: Block(title: "termcanvas")),
            frame.area
        )
    }
}

main(): Int64 {
    let app = DemoApp()
    App(targetFps: 10).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
