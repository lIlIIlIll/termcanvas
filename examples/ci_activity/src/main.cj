package cjtui_ci_activity

import core.*

let MUTED = Color.Rgb(132, 139, 164)
let TEXT = Color.Rgb(197, 206, 230)
let GREEN = Color.Rgb(156, 229, 160)
let ORANGE = Color.Rgb(255, 169, 108)

class CiActivity {
    var elapsed: Int64 = 0
    var paused = false
    var offset: Int64 = 0
    var iconSet = IconSet.Unicode
    var unicodeSupported = true

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r' ') => paused = !paused; UpdateResult.next()
                case KeyCode.Char(r'r') => elapsed = 0; paused = false; offset = 0; UpdateResult.next()
                case KeyCode.Char(r'n') =>
                    iconSet = match (iconSet) {
                        case IconSet.Unicode => IconSet.NerdFont
                        case IconSet.NerdFont => IconSet.Ascii
                        case IconSet.Ascii => IconSet.Unicode
                    }
                    UpdateResult.next()
                case KeyCode.Up => offset = max(0, offset - 1); UpdateResult.next()
                case KeyCode.Down => offset = min(2, offset + 1); UpdateResult.next()
                case _ => UpdateResult.next()
            }
            case Event.Capabilities(value) =>
                unicodeSupported = value.unicode
                UpdateResult.next()
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

        let useUnicode = unicodeSupported && match (iconSet) {
            case IconSet.Ascii => false
            case _ => true
        }
        let separator = if (useUnicode) { "  ·  " } else { "  |  " }
        let prefix = if (useUnicode) { "⟨bash⟩" } else { "[bash]" }
        let completedDetail = if (useUnicode) { "✓ All jobs completed" } else { "+ All jobs completed" }
        canvas.drawText(x, y, "CI ACTIVITY" + separator + "SIMULATION", dim)
        canvas.drawText(x, y + 2, if (finished) { "All simulated checks finished" } else { "Waiting for active CI" }, strong)

        let width = max(0, area.width - 2)
        let theme = Theme(normal: strong, disabled: dim, accent: Style(fg: ORANGE), success: Style(fg: GREEN),
            iconSet: iconSet)
        let watched = TaskActivity("bg_202", status: TaskStatus.Done, duration: duration,
            detail: "gh run watch 123456 --repo example/project")
        let cross = TaskActivity("Cross-platform CI", id: "bg_201", prefix: prefix, duration: duration,
            status: if (crossDone) { TaskStatus.Done } else { TaskStatus.Running },
            progressLabel: "CI jobs", progress: Some(TaskProgress.Counts(if (crossDone) { 5 } else { 2 }, 5)),
            detail: if (crossDone) { completedDetail } else { "* Post Check out source" })
        let showcaseStatuses = if (finished) {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done]
        } else if (crossDone) {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done, TaskStatus.Done]
        } else {
            [TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Done, TaskStatus.Pending, TaskStatus.Done, TaskStatus.Pending]
        }
        let showcase = TaskActivity(if (useUnicode) { "Showcase acceptance · CI jobs" } else { "Showcase acceptance - CI jobs" }, id: "bg_203", prefix: prefix, duration: duration,
            status: if (finished) { TaskStatus.Done } else { TaskStatus.Running }, progressLabel: "Jobs",
            progress: Some(TaskProgress.Items(showcaseStatuses)),
            detail: if (finished) { completedDetail } else { "* Post Check out source" })
        let entries = [TaskActivityListEntry(watched, layout: TaskActivityLayout.Compact),
            TaskActivityListEntry(cross), TaskActivityListEntry(showcase)]
        let listHeight = max(0, min(7, area.height - 9))
        let unicodeOverride: ?Bool = if (unicodeSupported) { None } else { Some(false) }
        frame.renderWidget(TaskActivityList(entries, offset: offset, activityFrame: elapsed / 100, theme: theme,
            unicode: unicodeOverride),
            Rect(x, y + 4, width, listHeight))
        let summaryY = y + 4 + listHeight
        canvas.drawText(x + 2, summaryY,
            if (finished) { "0 still running" } else if (crossDone) { "1 still running" } else { "2 still running" }, dim)
        let legendY = if (summaryY + 4 < area.bottom) { summaryY + 2 } else { summaryY + 1 }
        canvas.drawText(x, legendY, if (useUnicode) { "●" } else { "+" }, theme.success)
        canvas.drawText(x + 1, legendY, " done  ", dim)
        canvas.drawText(x + 8, legendY, if (useUnicode) { "◌" } else { "o" }, theme.normal)
        canvas.drawText(x + 9, legendY, " waiting", dim)
        let iconName = match (iconSet) {
            case IconSet.Unicode => "Unicode"
            case IconSet.NerdFont => "Nerd Font"
            case IconSet.Ascii => "ASCII"
        }
        canvas.drawText(x, legendY + 1, "demo" + separator + "${duration} elapsed" + separator + "icons: ${iconName}", dim)
        let pauseHint = if (paused) { "paused" + separator + "space resume" } else { "space pause" }
        canvas.drawText(x, legendY + 2, "n icons" + separator + pauseHint + separator + "arrows scroll" +
            separator + "r restart" + separator + "q quit", normal)
    }

}

main(): Int64 {
    let app = CiActivity()
    App(targetFps: 10, hideCursor: true).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
