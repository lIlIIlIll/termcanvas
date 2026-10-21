package cjtui_workbench

import core.*

main(args: Array<String>): Int64 {
    if (args.size > 1 || (args.size == 1 && args[0] != "--headless-smoke")) {
        println("usage: workbench [--headless-smoke]")
        return 2
    }

    if (args.size == 1) { return runWorkbenchHeadlessSmoke() }

    let app = WorkbenchApp()
    let metrics = AppMetrics()
    App(
        mouse: true,
        mouseMove: true,
        focusEvents: true,
        targetFps: 30,
        metrics: Some(metrics),
        hideCursor: false
    ).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
