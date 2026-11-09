package cjtui_workbench

import core.*

main(args: Array<String>): Int64 {
    if (args.size > 1 || (args.size == 1 && args[0] != "--headless-smoke" && args[0] != "--ci")) {
        println("usage: workbench [--ci|--headless-smoke]")
        return 2
    }

    if (args.size == 1 && args[0] == "--headless-smoke") { return runWorkbenchHeadlessSmoke() }

    let app = WorkbenchApp()
    if (args.size == 1 && args[0] == "--ci") { app.enterCiShowcase() }
    let metrics = AppMetrics()
    App(
        mouse: true,
        mouseMove: true,
        focusEvents: true,
        targetFps: 30,
        metrics: Some(metrics),
        hideCursor: true
    ).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
