package termcanvas_ops_dashboard

import core.*

class OpsDashboard {
    var frame: Int64 = 0
    var build: Int64 = 42
    var queue: Int64 = 6
    let metrics = AppMetrics()
    let logs = ["deploy accepted", "workers healthy", "cache warmed", "alerts quiet"]

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r'r') => build = 0; queue = 8; UpdateResult.next()
                case _ => UpdateResult.next()
            }
            case Event.Tick(tick) =>
                frame = tick.frameIndex
                build = min(100, build + 3)
                queue = max(0, (queue + 5) % 13)
                UpdateResult.next()
            case Event.Timer(timer) =>
                queue = (queue + timer.firedCount) % 10
                UpdateResult.next()
            case Event.Capabilities(_) =>
                UpdateResult.withCommand(Command.StartTimer(TimerSpec("queue", Duration.second)))
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([
            Constraint.Length(1),
            Constraint.Length(7),
            Constraint.Min(8),
            Constraint.Length(1)
        ]).withMargin(Spacing.all(1)).withGap(1).split(frame.area)
        frame.renderWidget(MenuBar(["Ops", "Deploy", "Metrics", "Alerts"], selected: 2), rows[0])
        let top = Layout.horizontal([Constraint.Percent(34), Constraint.Percent(33), Constraint.Min(20)]).withGap(1).split(rows[1])
        frame.renderWidget(Gauge(build, total: 100, label: "deploy"), top[0])
        let latencyBlock = Block(title: "Latency")
        frame.renderWidget(latencyBlock, top[1])
        frame.renderWidget(Sparkline([10, 14, 13, 18, 17, 22, 19, 24, 21, 26], maxValue: 30), latencyBlock.inner(top[1]))
        frame.renderWidget(Chart([queue, queue + 3, queue + 1, queue + 5], block: Block(title: "Queue")), top[2])

        let body = Layout.horizontal([Constraint.Percent(52), Constraint.Min(20)]).withGap(1).split(rows[2])
        let progressBlock = Block(title: "Release progress")
        frame.renderWidget(progressBlock, body[0])
        frame.renderWidget(ProgressBar(build, total: 100, label: phase(), segments: [
            ProgressBarSegment(min(build, 25), style: Style(fg: Color.Cyan), symbol: "="),
            ProgressBarSegment(max(0, min(build, 70) - 25), style: Style(fg: Color.Yellow), symbol: "="),
            ProgressBarSegment(max(0, build - 70), style: Style(fg: Color.Green), symbol: "=")
        ]), progressBlock.inner(body[0]))
        frame.renderWidget(LogView(logs, block: Block(title: "Event log")), body[1])
        frame.renderWidget(StatusBar(
            left: "ops_dashboard  r reset  q quit",
            right: "frame ${this.frame}",
            style: Style(fg: Color.White, bg: Color.Black),
            progress: Some(StatusBarProgress(build, width: 18, label: "ship"))
        ), rows[3])
    }

    private func phase(): String {
        if (build >= 100) { "complete" } else if (build >= 70) { "verify" } else if (build >= 25) { "build" } else { "prepare" }
    }
}

main(): Int64 {
    let app = OpsDashboard()
    App(targetFps: 12, metrics: Some(app.metrics)).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
