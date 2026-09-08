package termcanvas_gif_ascii

import core.*
import media.*
import std.convert.*
import std.env.*

class MediaAsciiApp {
    let source: ?MediaSource
    var options: AsciiRenderOptions
    let decoder = FfmpegAsciiAnimationDecoder()
    var animation: ?AsciiAnimation = None
    var status: String = "ready"
    var elapsedMillis: Int64 = 0
    var speedPercent: Int64 = 100
    var zoom: Int64 = 1
    var paused: Bool = false
    var loaded: Bool = false
    private var loadTask: ?Future<?AsciiAnimation> = None
    private var loadRevision: Int64 = 0
    private var pendingRevision: Int64 = 0

    init(args: Array<String>) {
        let parsed = parseOptions(args)
        this.options = parsed.options
        this.source = parsed.source
        match (source) {
            case Some(src) => status = "loading " + src.uri
            case None => status = "usage: cjpm run --run-args=\"path/to/media-file [--width 80 --height 32 --fps 12 --mode ascii|half|braille --color --threshold 128]\""
        }
    }

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') =>
                    if (let Some(task) <- loadTask) { task.cancel() }
                    return UpdateResult.exit()
                case _ => ()
            }
            case _ => ()
        }
        finishLoad()
        if (!loaded && loadTask.isNone()) { load() }
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => UpdateResult.exit()
                case KeyCode.Char(r' ') =>
                    paused = !paused
                    UpdateResult.next()
                case KeyCode.Char(r'+') =>
                    zoom = min(4, zoom + 1)
                    UpdateResult.next()
                case KeyCode.Char(r'-') =>
                    zoom = max(1, zoom - 1)
                    UpdateResult.next()
                case KeyCode.Char(r']') =>
                    speedPercent = min(400, speedPercent + 25)
                    UpdateResult.next()
                case KeyCode.Char(r'[') =>
                    speedPercent = max(25, speedPercent - 25)
                    UpdateResult.next()
                case KeyCode.Char(r'.') =>
                    adjustThreshold(5)
                    UpdateResult.next()
                case KeyCode.Char(r',') =>
                    adjustThreshold(-5)
                    UpdateResult.next()
                case KeyCode.Char(r'>') =>
                    adjustThreshold(20)
                    UpdateResult.next()
                case KeyCode.Char(r'<') =>
                    adjustThreshold(-20)
                    UpdateResult.next()
                case _ => UpdateResult.next()
            }
            case Event.Tick(tick) =>
                if (!paused) {
                    elapsedMillis += tick.deltaMillis * speedPercent / 100
                }
                UpdateResult.next()
            case _ => UpdateResult.next()
        }
    }

    private func load(): Unit {
        match (source) {
            case Some(src) =>
                animation = None
                let requestedOptions = options
                pendingRevision = loadRevision
                loadTask = Some(spawn { decoder.decode(src, requestedOptions) })
            case None => loaded = true
        }
    }

    private func finishLoad(): Unit {
        if (let Some(task) <- loadTask) {
            if (let Some(result) <- task.tryGet()) {
                loadTask = None
                if (pendingRevision != loadRevision) { return }
                loaded = true
                match (result) {
                    case Some(value) =>
                        animation = Some(value)
                        status = "${value.frameCount()} frames  ${options.width}x${options.height} ${asciiModeName(options.mode)}  ${options.fps}fps  ${colorModeName(options.color)} threshold=${options.binaryThreshold}"
                    case None =>
                        status = "decode failed or exceeded limits: 10 s, 16 MiB, 256 frames"
                }
            }
        }
    }

    private func adjustThreshold(delta: Int64): Unit {
        let next = clampExample(options.binaryThreshold + delta, 0, 255)
        if (next == options.binaryThreshold) { return }
        options = asciiOptionsWithThreshold(options, next)
        loadRevision++
        if (let Some(task) <- loadTask) { task.cancel() }
        loaded = false
        elapsedMillis = 0
        status = "reloading threshold=${next}"
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Length(4), Constraint.Min(5), Constraint.Length(1)]).withGap(1).withMargin(Spacing.all(1)).split(frame.area)
        frame.renderWidget(Paragraph(headerText(), block: Block(title: "Media ASCII")), rows[0])
        match (animation) {
            case Some(value) =>
                frame.renderWidget(AsciiAnimationView(
                    value,
                    elapsedMillis: elapsedMillis,
                    zoom: zoom,
                    paused: paused,
                    block: Some(Block(title: "Frame")),
                    style: Style(fg: Color.Rgb(214, 225, 234), bg: Color.Black),
                    pausedStyle: Style(fg: Color.Yellow, bg: Color.Black)
                ), rows[1])
            case None =>
                frame.renderWidget(Paragraph(status, block: Block(title: "Status"), style: Style(fg: Color.Yellow)), rows[1])
        }
        frame.renderWidget(StatusBar(
            left: "media_ascii  space pause  +/- zoom  [] speed  ,./<> threshold  q quit",
            right: "zoom=${zoom} speed=${speedPercent}% threshold=${options.binaryThreshold}",
            style: Style(fg: Color.White, bg: Color.Black)
        ), rows[2])
    }

    private func headerText(): String {
        let play = if (paused) { "paused" } else { "playing" }
        match (source) {
            case Some(src) => "${src.uri}\n${status}\n${configText()}\n${play} elapsed=${elapsedMillis}ms"
            case None => "${status}\ninstall ffmpeg and pass an image, gif, or video path\nq quits"
        }
    }

    private func configText(): String {
        "config: ${options.width}x${options.height} ${asciiModeName(options.mode)} ${options.fps}fps ${colorModeName(options.color)} threshold=${options.binaryThreshold} zoom=${zoom} speed=${speedPercent}%"
    }
}

struct ParsedOptions {
    let source: ?MediaSource
    let options: AsciiRenderOptions

    init(source: ?MediaSource, options: AsciiRenderOptions) {
        this.source = source
        this.options = options
    }
}

func parseOptions(args: Array<String>): ParsedOptions {
    var width: Int64 = 80
    var height: Int64 = 32
    var fps: Int64 = 12
    var mode = AsciiRenderMode.Ascii
    var color = false
    var threshold: Int64 = 128
    var path = ""
    var i: Int64 = 0
    while (i < args.size) {
        match (args[i]) {
            case "--width" =>
                if (i + 1 < args.size) {
                    width = parsePositive(args[i + 1], width)
                    i += 2
                } else { i++ }
            case "--height" =>
                if (i + 1 < args.size) {
                    height = parsePositive(args[i + 1], height)
                    i += 2
                } else { i++ }
            case "--fps" =>
                if (i + 1 < args.size) {
                    fps = parsePositive(args[i + 1], fps)
                    i += 2
                } else { i++ }
            case "--mode" =>
                if (i + 1 < args.size) {
                    mode = parseMode(args[i + 1], mode)
                    i += 2
                } else { i++ }
            case "--color" =>
                color = true
                i++
            case "--no-color" =>
                color = false
                i++
            case "--threshold" =>
                if (i + 1 < args.size) {
                    threshold = parseByte(args[i + 1], threshold)
                    i += 2
                } else { i++ }
            case value =>
                if (path.isEmpty() && !value.startsWith("--")) { path = value }
                i++
        }
    }
    let sourcePath = expandUserPath(path)
    let source: ?MediaSource = if (sourcePath.isEmpty()) { None } else { Some(MediaSource("media", sourcePath, kind: MediaKind.Animation, alt: sourcePath)) }
    ParsedOptions(source, AsciiRenderOptions(width: width, height: height, fps: fps, mode: mode, color: color, binaryThreshold: threshold))
}

func expandUserPath(path: String): String {
    if (path == "~") { return getHomeDirectory().toString() }
    if (path.startsWith("~/")) { return getHomeDirectory().toString() + path[1..] }
    path
}

func parsePositive(text: String, fallback: Int64): Int64 {
    try {
        let value = Int64.parse(text)
        if (value > 0) { value } else { fallback }
    } catch (_) {
        fallback
    }
}

func parseByte(text: String, fallback: Int64): Int64 {
    try {
        clampExample(Int64.parse(text), 0, 255)
    } catch (_) {
        fallback
    }
}

func parseMode(text: String, fallback: AsciiRenderMode): AsciiRenderMode {
    match (text) {
        case "ascii" => AsciiRenderMode.Ascii
        case "half" => AsciiRenderMode.HalfBlock
        case "half-block" => AsciiRenderMode.HalfBlock
        case "braille" => AsciiRenderMode.Braille
        case _ => fallback
    }
}

func asciiModeName(mode: AsciiRenderMode): String {
    match (mode) {
        case AsciiRenderMode.Ascii => "ascii"
        case AsciiRenderMode.HalfBlock => "half"
        case AsciiRenderMode.Braille => "braille"
    }
}

func colorModeName(color: Bool): String {
    if (color) { "color" } else { "mono" }
}

func asciiOptionsWithThreshold(options: AsciiRenderOptions, threshold: Int64): AsciiRenderOptions {
    AsciiRenderOptions(
        width: options.width,
        height: options.height,
        fps: options.fps,
        ramp: options.ramp,
        invert: options.invert,
        alphaThreshold: options.alphaThreshold,
        mode: options.mode,
        color: options.color,
        binaryThreshold: threshold
    )
}

func clampExample(value: Int64, low: Int64, high: Int64): Int64 {
    min(max(value, low), high)
}

main(args: Array<String>): Int64 {
    let app = MediaAsciiApp(args)
    App(targetFps: 24).runWithCommands(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
