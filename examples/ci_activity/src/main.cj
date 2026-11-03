package cjtui_ci_activity

import core.*

let MUTED = Color.Rgb(132, 139, 164)
let TEXT = Color.Rgb(197, 206, 230)
let GREEN = Color.Rgb(156, 229, 160)
let ORANGE = Color.Rgb(255, 169, 108)

class CiActivity {
    var elapsed: Int64 = 0
    var paused = false

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r' ') => paused = !paused; UpdateResult.next()
                case KeyCode.Char(r'r') => elapsed = 0; paused = false; UpdateResult.next()
                case _ => UpdateResult.next()
            }
            case Event.Tick(tick) =>
                if (!paused) { elapsed += tick.deltaMillis }
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    func render(frame: Frame): Unit {
        let canvas = frame.canvas()
        let area = frame.area
        let x = area.x + 1
        let y = area.y + 1
        let dim = Style(fg: MUTED)
        let normal = Style(fg: TEXT)
        let strong = Style(fg: TEXT, modifier: Modifier.strong())
        let finished = elapsed >= 30000
        let crossDone = elapsed >= 18000
        let seconds = elapsed / 1000
        let duration = "${seconds / 60}m${seconds % 60}s"

        canvas.drawText(x, y, "CI ACTIVITY  ·  SIMULATION", dim)
        canvas.drawText(x, y + 2, if (finished) { "All simulated checks finished" } else { "Waiting for active CI" }, strong)

        let width = max(0, area.width - 2)
        let theme = Theme(normal: strong, disabled: dim, accent: Style(fg: ORANGE), success: Style(fg: GREEN))
        let watched = TaskActivity("bg_202", status: TaskStatus.Done, duration: duration,
            detail: "gh run watch 123456 --repo example/project")
        let cross = TaskActivity("Cross-platform CI", id: "bg_201", prefix: "⟨bash⟩", duration: duration,
            status: if (crossDone) { TaskStatus.Done } else { TaskStatus.Running },
            progressLabel: "CI jobs", progress: Some(TaskProgress.Counts(if (crossDone) { 5 } else { 2 }, 5)),
            detail: if (crossDone) { "✓ All jobs completed" } else { "* Post Check out source" })
        let showcaseStatuses = if (finished) {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done]
        } else if (crossDone) {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done]
        } else {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Pending]
        }
        let showcase = TaskActivity("Showcase acceptance · CI jobs", id: "bg_203", prefix: "⟨bash⟩", duration: duration,
            status: if (finished) { TaskStatus.Done } else { TaskStatus.Running }, progressLabel: "Jobs",
            progress: Some(TaskProgress.Items(showcaseStatuses)),
            detail: if (finished) { "✓ All jobs completed" } else { "* Post Check out source" })
        frame.renderWidget(TaskActivityView(watched, layout: TaskActivityLayout.Compact, theme: theme), Rect(x, y + 4, width, 1))
        frame.renderWidget(TaskActivityView(cross, activityFrame: elapsed / 100, theme: theme), Rect(x, y + 5, width, 3))
        frame.renderWidget(TaskActivityView(showcase, activityFrame: elapsed / 100, theme: theme), Rect(x, y + 8, width, 3))
        canvas.drawText(x + 2, y + 11, if (finished) { "0 still running" } else if (crossDone) { "1 still running" } else { "2 still running" }, dim)

        canvas.drawText(x, y + 13, "demo  ·  ${duration} elapsed  ·  simulated CI data", dim)
        canvas.drawText(x, y + 15, if (paused) { "paused  ·  space resume  ·  r restart  ·  q quit" } else { "space pause  ·  r restart  ·  q quit" }, normal)
    }

}

main(): Int64 {
    let app = CiActivity()
    App(targetFps: 10).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
