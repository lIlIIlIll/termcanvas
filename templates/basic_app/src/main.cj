package cjtui_basic_app

import core.*
import cjtui_testing.*

class DemoApp {
    var count: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (key.code) {
                    case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                    case KeyCode.Char(r'+') => UpdateResult.withCommand(Command.Message("inc"))
                    case _ => UpdateResult.unchanged()
                }
            case Event.Resize(_) => UpdateResult.next()
            case Event.Message("inc") =>
                count++
                UpdateResult.next()
            case _ => UpdateResult.unchanged()
        }
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(
            Paragraph("count: ${count}\n+: increment\nq/Ctrl-C: quit", block: Block(title: "cjtui")),
            frame.area
        )
    }
}

main(args: Array<String>): Int64 {
    let app = DemoApp()
    if (args.size == 1 && args[0] == "--headless-smoke") {
        let report = TestScenario().key(KeyEvent(KeyCode.Char(r'+')))
            .key(KeyEvent(KeyCode.Char(r'q'))).run(
                { frame => app.render(frame) }, { event => app.update(event) }
            )
        if (report.passed && report.exited && app.count == 1) {
            println("downstream app smoke ok")
            return 0
        }
        return 1
    }
    App().runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
