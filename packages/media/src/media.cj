package media

import core.*
import std.process.*
import std.collection.*
import std.time.*

public class MediaDecodeRequest {
    public let source: MediaSource
    public let area: Rect
    public let protocol: MediaProtocol
    public let frameIndex: Int64

    public init(source: MediaSource, area: Rect, protocol: MediaProtocol, frameIndex!: Int64 = 0) {
        this.source = source
        this.area = area
        this.protocol = protocol
        this.frameIndex = max(0, frameIndex)
    }
}

public interface MediaAdapter {
    func decode(request: MediaDecodeRequest): MediaFrameData
}

public class FallbackMediaAdapter <: MediaAdapter {
    public init() {}

    public func decode(request: MediaDecodeRequest): MediaFrameData {
        MediaFrameData.text(mediaFallbackText(request.source))
    }
}

public class ExternalMediaAdapter <: MediaAdapter {
    private let magick: String
    private let ffmpeg: String
    private let sixelEncoder: String

    public init(magick!: String = "magick", ffmpeg!: String = "ffmpeg", sixelEncoder!: String = "img2sixel") {
        this.magick = magick
        this.ffmpeg = ffmpeg
        this.sixelEncoder = sixelEncoder
    }

    public func decode(request: MediaDecodeRequest): MediaFrameData {
        match (request.protocol) {
            case MediaProtocol.Kitty => decodeKitty(request)
            case MediaProtocol.Sixel => decodeSixel(request)
            case MediaProtocol.Text => MediaFrameData.text(mediaFallbackText(request.source))
        }
    }

    private func decodeKitty(request: MediaDecodeRequest): MediaFrameData {
        let (width, height) = match (mediaDimensions(request.area)) {
            case Some(size) => size
            case None => return MediaFrameData.text(mediaFallbackText(request.source))
        }
        let result = match (request.source.kind) {
            case MediaKind.Video => runTool(ffmpeg, [
                "-v", "error",
                "-i", request.source.uri,
                "-frames:v", "1",
                "-vf", frameFilter(request.frameIndex, width, height),
                "-fps_mode", "passthrough",
                "-f", "rawvideo",
                "-pix_fmt", "rgba",
                "-"
            ])
            case MediaKind.Animation => runTool(ffmpeg, [
                "-v", "error",
                "-i", request.source.uri,
                "-frames:v", "1",
                "-vf", frameFilter(request.frameIndex, width, height),
                "-fps_mode", "passthrough",
                "-f", "rawvideo",
                "-pix_fmt", "rgba",
                "-"
            ])
            case _ => runTool(magick, [
                request.source.uri,
                "-resize", "${width}x${height}!",
                "-background", "none",
                "-alpha", "on",
                "rgba:-"
            ])
        }
        match (result) {
            case Some(bytes) =>
                if (bytes.size == width * height * 4) { MediaFrameData.kitty(bytes, widthPixels: width, heightPixels: height) }
                else { MediaFrameData.text(mediaFallbackText(request.source)) }
            case None => MediaFrameData.text(mediaFallbackText(request.source))
        }
    }

    private func decodeSixel(request: MediaDecodeRequest): MediaFrameData {
        // img2sixel has no frame-index contract: explicitly fall back for it.
        if (request.frameIndex != 0) { return MediaFrameData.text(mediaFallbackText(request.source)) }
        let (width, height) = match (mediaDimensions(request.area)) {
            case Some(size) => size
            case None => return MediaFrameData.text(mediaFallbackText(request.source))
        }
        match (runTool(sixelEncoder, ["-w", "${width}", "-h", "${height}", request.source.uri])) {
            case Some(out) =>
                let payload = unsafe { String.fromUtf8Unchecked(out) }
                MediaFrameData.sixel(stripSixelEnvelope(payload), widthPixels: width, heightPixels: height)
            case None => MediaFrameData.text(mediaFallbackText(request.source))
        }
    }

    public func commandFor(request: MediaDecodeRequest): String {
        let (width, height) = match (mediaDimensions(request.area)) { case Some(size) => size; case None => return "" }
        match (request.protocol) {
            case MediaProtocol.Text => return ""
            case MediaProtocol.Sixel =>
                return if (request.frameIndex == 0) { "${sixelEncoder} -w ${width} -h ${height} ${request.source.uri}" } else { "" }
            case _ => ()
        }
        match (request.source.kind) {
            case MediaKind.Video =>
                "${ffmpeg} -v error -i ${request.source.uri} -frames:v 1 -vf ${frameFilter(request.frameIndex, width, height)} -fps_mode passthrough -f rawvideo -pix_fmt rgba -"
            case MediaKind.Animation =>
                "${ffmpeg} -v error -i ${request.source.uri} -frames:v 1 -vf ${frameFilter(request.frameIndex, width, height)} -fps_mode passthrough -f rawvideo -pix_fmt rgba -"
            case _ =>
                match (request.protocol) {
                    case MediaProtocol.Sixel => "${sixelEncoder} -w ${width} -h ${height} ${request.source.uri}"
                    case _ => "${magick} ${request.source.uri} -resize ${width}x${height}! -background none -alpha on rgba:-"
                }
        }
    }
}

public enum AsciiRenderMode {
    | Ascii
    | HalfBlock
    | Braille
}

public struct AsciiRenderOptions {
    public let width: Int64
    public let height: Int64
    public let fps: Int64
    public let ramp: String
    public let invert: Bool
    public let alphaThreshold: Int64
    public let mode: AsciiRenderMode
    public let color: Bool
    public let binaryThreshold: Int64

    public init(
        width!: Int64 = 80,
        height!: Int64 = 32,
        fps!: Int64 = 12,
        ramp!: String = " .:-=+*#%@",
        invert!: Bool = false,
        alphaThreshold!: Int64 = 16,
        mode!: AsciiRenderMode = AsciiRenderMode.Ascii,
        color!: Bool = false,
        binaryThreshold!: Int64 = 128
    ) {
        this.width = clampLocal(width, 1, 240)
        this.height = clampLocal(height, 1, 120)
        this.fps = clampLocal(fps, 1, 30)
        this.ramp = if (ramp.isEmpty()) { " .:-=+*#%@" } else { ramp }
        this.invert = invert
        this.alphaThreshold = clampLocal(alphaThreshold, 0, 255)
        this.mode = mode
        this.color = color
        this.binaryThreshold = clampLocal(binaryThreshold, 0, 255)
    }

    public func frameMillis(): Int64 {
        max(1, 1000 / fps)
    }

    public func sampleWidth(): Int64 {
        match (mode) {
            case AsciiRenderMode.Braille => width * 2
            case _ => width
        }
    }

    public func sampleHeight(): Int64 {
        match (mode) {
            case AsciiRenderMode.HalfBlock => height * 2
            case AsciiRenderMode.Braille => height * 4
            case _ => height
        }
    }
}

public struct AsciiFrame {
    public let lines: Array<String>
    public let colors: Array<Array<Color>>
    public let durationMillis: Int64

    public init(lines: Array<String>, durationMillis!: Int64 = 83, colors!: Array<Array<Color>> = []) {
        this.lines = lines
        this.colors = colors
        this.durationMillis = max(1, durationMillis)
    }

    public func text(): String {
        joinLocal(lines, "\n")
    }

    public func hasColors(): Bool {
        colors.size > 0
    }

    public func colorAt(row: Int64, column: Int64): Color {
        if (row < 0 || column < 0 || row >= colors.size || column >= colors[row].size) {
            return Color.Reset
        }
        colors[row][column]
    }
}

public class AsciiAnimation {
    private let frames: Array<AsciiFrame>
    private let fallback: AsciiFrame

    public init(frames: Array<AsciiFrame>) {
        this.frames = frames
        this.fallback = AsciiFrame([""], durationMillis: 1000)
    }

    public func frameCount(): Int64 {
        frames.size
    }

    public func isEmpty(): Bool {
        frames.size == 0
    }

    public func totalDurationMillis(): Int64 {
        var total: Int64 = 0
        for (frame in frames) {
            total += frame.durationMillis
        }
        max(1, total)
    }

    public func frameAtIndex(index: Int64): AsciiFrame {
        if (frames.size == 0) { return fallback }
        frames[modPositive(index, frames.size)]
    }

    public func frameAtElapsed(elapsedMillis: Int64): AsciiFrame {
        if (frames.size == 0) { return fallback }
        var remaining = modPositive(max(0, elapsedMillis), totalDurationMillis())
        for (frame in frames) {
            if (remaining < frame.durationMillis) { return frame }
            remaining -= frame.durationMillis
        }
        frames[frames.size - 1]
    }
}

public interface AsciiAnimationDecoder {
    func decode(source: MediaSource, options: AsciiRenderOptions): ?AsciiAnimation
}

public class FfmpegAsciiAnimationDecoder <: AsciiAnimationDecoder {
    private let ffmpeg: String

    public init(ffmpeg!: String = "ffmpeg") {
        this.ffmpeg = ffmpeg
    }

    // Synchronous, cancellable through the calling Future. Returns None on a
    // 10-second tool deadline, more than 16 MiB of output, incomplete RGBA, or
    // more than 256 frames. No truncated animation is reported as complete.
    public func decode(source: MediaSource, options: AsciiRenderOptions): ?AsciiAnimation {
        match (runTool(ffmpeg, ffmpegAsciiArgs(source, options))) {
            case Some(bytes) => asciiAnimationFromRgba(bytes, options)
            case None => None
        }
    }

    public func commandFor(source: MediaSource, options: AsciiRenderOptions): String {
        ffmpeg + " " + joinLocal(ffmpegAsciiArgs(source, options), " ")
    }
}

public class AsciiAnimationView <: Widget {
    private let animation: AsciiAnimation
    private let elapsedMillis: Int64
    private let zoom: Int64
    private let paused: Bool
    private let block: ?Block
    private let style: Style
    private let pausedStyle: Style

    public init(
        animation: AsciiAnimation,
        elapsedMillis!: Int64 = 0,
        zoom!: Int64 = 1,
        paused!: Bool = false,
        block!: ?Block = None,
        style!: Style = Style(fg: Color.White),
        pausedStyle!: Style = Style(fg: Color.Yellow)
    ) {
        this.animation = animation
        this.elapsedMillis = max(0, elapsedMillis)
        this.zoom = clampLocal(zoom, 1, 4)
        this.paused = paused
        this.block = block
        this.style = style
        this.pausedStyle = pausedStyle
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let frame = animation.frameAtElapsed(elapsedMillis)
        let rowStyle = if (paused) { pausedStyle } else { style }
        var outY: Int64 = 0
        for (sourceY in 0..frame.lines.size) {
            if (outY >= target.height) { break }
            let line = frame.lines[sourceY]
            for (_ in 0..zoom) {
                if (outY >= target.height) { break }
                if (frame.hasColors()) {
                    renderColoredAsciiLine(buffer, target.x, target.y + outY, line, frame, sourceY, zoom, target.width, rowStyle)
                } else {
                    let rendered = zoomAsciiLine(line, zoom, target.width)
                    buffer.setString(target.x, target.y + outY, rendered, style: rowStyle)
                }
                outY++
            }
        }
    }
}

public func rgbaToAsciiFrame(bytes: Array<Byte>, width: Int64, height: Int64, options: AsciiRenderOptions): AsciiFrame {
    let targetWidth = max(0, width)
    let targetHeight = max(0, height)
    let frameSize = targetWidth * targetHeight * 4
    if (targetWidth <= 0 || targetHeight <= 0 || bytes.size < frameSize) {
        return AsciiFrame([], durationMillis: options.frameMillis())
    }
    match (options.mode) {
        case AsciiRenderMode.HalfBlock => return rgbaToHalfBlockFrame(bytes, targetWidth, targetHeight, options)
        case AsciiRenderMode.Braille => return rgbaToBrailleFrame(bytes, targetWidth, targetHeight, options)
        case AsciiRenderMode.Ascii => ()
    }
    let lines = ArrayList<String>()
    let colorRows = ArrayList<Array<Color>>()
    for (y in 0..targetHeight) {
        let builder = StringBuilder()
        let rowColors = ArrayList<Color>()
        for (x in 0..targetWidth) {
            let offset = (y * targetWidth + x) * 4
            let r = Int64(bytes[offset])
            let g = Int64(bytes[offset + 1])
            let b = Int64(bytes[offset + 2])
            let a = Int64(bytes[offset + 3])
            builder.append(asciiRampChar(r, g, b, a, options))
            if (options.color) {
                rowColors.add(pixelColor(r, g, b, a, options))
            }
        }
        lines.add(builder.toString())
        if (options.color) {
            colorRows.add(rowColors.toArray())
        }
    }
    AsciiFrame(lines.toArray(), durationMillis: options.frameMillis(), colors: colorRows.toArray())
}

let MEDIA_ESC = "\u{1B}"
const MEDIA_MAX_OUTPUT_BYTES: Int64 = 16 * 1024 * 1024
const MEDIA_MAX_FRAMES: Int64 = 256

func mediaDimensions(area: Rect): ?(Int64, Int64) {
    if (area.width < 0 || area.height < 0 || area.width > 4096 || area.height > 4096) { return None }
    let width = max(1, area.width * 8)
    let height = max(1, area.height * 16)
    if (width > MEDIA_MAX_OUTPUT_BYTES / 4 / height) { return None }
    Some((width, height))
}

func frameFilter(index: Int64, width: Int64, height: Int64): String {
    "select=eq(n\\,${index}),scale=${width}:${height}"
}

func runTool(command: String, args: Array<String>): ?Array<Byte> {
    try {
        let process = launch(command, args, stdIn: ProcessRedirect.Discard, stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Discard)
        let reader: Future<?Array<Byte>> = spawn {
            let out = ArrayList<Byte>()
            let chunk = Array<Byte>(8192, repeat: 0)
            try {
                while (true) {
                    let count = process.stdOutPipe.read(chunk)
                    if (count == 0) { break }
                    if (count < 0) { return None }
                    if (out.size > MEDIA_MAX_OUTPUT_BYTES - count) {
                        process.terminate(force: true)
                        return None
                    }
                    for (i in 0..count) { out.add(chunk[i]) }
                }
                if (out.size > 0) { Some(out.toArray()) } else { None }
            } catch (_) { None }
        }
        var reaped = false
        try {
            let deadline = MonoTime.now() + 10 * Duration.second
            while (MonoTime.now() < deadline && !Thread.currentThread.hasPendingCancellation) {
                try {
                    // wait closes process streams, so finish reading before reaping.
                    let output = reader.get(100 * Duration.millisecond)
                    let code = process.wait(timeout: 100 * Duration.millisecond)
                    reaped = true
                    return if (code == 0) { output } else { None }
                } catch (_: TimeoutException) { () }
            }
            None
        } finally {
            if (!reaped) {
                try { process.terminate(force: true) } catch (_) { () }
                try { _ = process.wait(timeout: Duration.second) } catch (_) { () }
            }
            try { _ = reader.get(Duration.second) } catch (_) { () }
        }
    } catch (_) {
        None
    }
}

func stripSixelEnvelope(text: String): String {
    var out = text
    if (out.startsWith("${MEDIA_ESC}Pq")) {
        out = out[3..]
    } else if (out.startsWith("${MEDIA_ESC}P0;0;0q")) {
        out = out[8..]
    } else if (out.startsWith("${MEDIA_ESC}P")) {
        let q = indexOfAscii(out, b'q')
        if (q >= 0 && q + 1 < out.size) {
            out = out[q + 1..]
        }
    }
    if (out.endsWith("${MEDIA_ESC}\\")) {
        out = out[..out.size - 2]
    }
    out
}

func indexOfAscii(text: String, target: Byte): Int64 {
    let bytes = unsafe { text.rawData() }
    for (i in 0..bytes.size) {
        if (bytes[i] == target) { return i }
    }
    -1
}

public func preferredMediaProtocol(caps: TerminalCapabilities): MediaProtocol {
    if (caps.kittyGraphics) { MediaProtocol.Kitty }
    else if (caps.sixel) { MediaProtocol.Sixel }
    else { MediaProtocol.Text }
}

public func mediaPlacementWithAdapter(
    id: String,
    source: MediaSource,
    area: Rect,
    caps: TerminalCapabilities,
    adapter!: MediaAdapter = FallbackMediaAdapter(),
    fit!: MediaFit = MediaFit.Contain,
    frameIndex!: Int64 = 0
): MediaPlacement {
    let protocol = preferredMediaProtocol(caps)
    let frame = adapter.decode(MediaDecodeRequest(source, area, protocol, frameIndex: frameIndex))
    MediaPlacement(id, source, area, fit: fit, frameIndex: frameIndex, frame: Some(frame))
}

func ffmpegAsciiArgs(source: MediaSource, options: AsciiRenderOptions): Array<String> {
    [
        "-v", "error",
        "-i", source.uri,
        "-vf", "fps=${options.fps},scale=${options.sampleWidth()}:${options.sampleHeight()}:flags=lanczos",
        // Read one extra frame to detect the limit; never label a prefix complete.
        "-frames:v", "${MEDIA_MAX_FRAMES + 1}",
        "-f", "rawvideo",
        "-pix_fmt", "rgba",
        "-"
    ]
}

func asciiAnimationFromRgba(bytes: Array<Byte>, options: AsciiRenderOptions): ?AsciiAnimation {
    let sampleWidth = options.sampleWidth()
    let sampleHeight = options.sampleHeight()
    let frameSize = sampleWidth * sampleHeight * 4
    if (frameSize <= 0 || bytes.size < frameSize || bytes.size % frameSize != 0 || bytes.size / frameSize > MEDIA_MAX_FRAMES) { return None }
    let frames = ArrayList<AsciiFrame>()
    var offset: Int64 = 0
    while (offset + frameSize <= bytes.size) {
        frames.add(rgbaToAsciiFrame(bytes[offset..offset + frameSize], sampleWidth, sampleHeight, options))
        offset += frameSize
    }
    if (frames.size == 0) { None } else { Some(AsciiAnimation(frames.toArray())) }
}

func rgbaToHalfBlockFrame(bytes: Array<Byte>, width: Int64, height: Int64, options: AsciiRenderOptions): AsciiFrame {
    let lines = ArrayList<String>()
    let colorRows = ArrayList<Array<Color>>()
    var y: Int64 = 0
    while (y < height) {
        let builder = StringBuilder()
        let rowColors = ArrayList<Color>()
        for (x in 0..width) {
            let upper = visiblePixel(bytes, width, height, x, y, options)
            let lower = visiblePixel(bytes, width, height, x, y + 1, options)
            builder.append(halfBlockRune(upper, lower))
            if (options.color) {
                rowColors.add(averagePixelColor(bytes, width, height, x, y, 1, 2, options))
            }
        }
        lines.add(builder.toString())
        if (options.color) {
            colorRows.add(rowColors.toArray())
        }
        y += 2
    }
    AsciiFrame(lines.toArray(), durationMillis: options.frameMillis(), colors: colorRows.toArray())
}

func rgbaToBrailleFrame(bytes: Array<Byte>, width: Int64, height: Int64, options: AsciiRenderOptions): AsciiFrame {
    let lines = ArrayList<String>()
    let colorRows = ArrayList<Array<Color>>()
    var y: Int64 = 0
    while (y < height) {
        let builder = StringBuilder()
        let rowColors = ArrayList<Color>()
        var x: Int64 = 0
        while (x < width) {
            var mask: UInt32 = 0
            for (dy in 0..4) {
                for (dx in 0..2) {
                    if (visiblePixel(bytes, width, height, x + dx, y + dy, options)) {
                        mask |= brailleMask(dx, dy)
                    }
                }
            }
            builder.append(Rune(UInt32(0x2800) + mask))
            if (options.color) {
                rowColors.add(averagePixelColor(bytes, width, height, x, y, 2, 4, options))
            }
            x += 2
        }
        lines.add(builder.toString())
        if (options.color) {
            colorRows.add(rowColors.toArray())
        }
        y += 4
    }
    AsciiFrame(lines.toArray(), durationMillis: options.frameMillis(), colors: colorRows.toArray())
}

func asciiRampChar(r: Int64, g: Int64, b: Int64, a: Int64, options: AsciiRenderOptions): Rune {
    if (a < options.alphaThreshold) { return r' ' }
    let brightness = clampLocal((r * 299 + g * 587 + b * 114) / 1000, 0, 255)
    let ramp = options.ramp
    let count = max(1, runeCount(ramp))
    var index = brightness * (count - 1) / 255
    if (options.invert) { index = (count - 1) - index }
    runeAt(ramp, index)
}

func visiblePixel(bytes: Array<Byte>, width: Int64, height: Int64, x: Int64, y: Int64, options: AsciiRenderOptions): Bool {
    if (x < 0 || y < 0 || x >= width || y >= height) { return false }
    let offset = (y * width + x) * 4
    let a = Int64(bytes[offset + 3])
    if (a < options.alphaThreshold) { return false }
    let r = Int64(bytes[offset])
    let g = Int64(bytes[offset + 1])
    let b = Int64(bytes[offset + 2])
    var brightness = clampLocal((r * 299 + g * 587 + b * 114) / 1000, 0, 255)
    if (options.invert) { brightness = 255 - brightness }
    brightness >= options.binaryThreshold
}

func pixelColor(r: Int64, g: Int64, b: Int64, a: Int64, options: AsciiRenderOptions): Color {
    if (a < options.alphaThreshold) { return Color.Reset }
    Color.Rgb(UInt8(clampLocal(r, 0, 255)), UInt8(clampLocal(g, 0, 255)), UInt8(clampLocal(b, 0, 255)))
}

func averagePixelColor(bytes: Array<Byte>, width: Int64, height: Int64, x: Int64, y: Int64, cellWidth: Int64, cellHeight: Int64, options: AsciiRenderOptions): Color {
    var rSum: Int64 = 0
    var gSum: Int64 = 0
    var bSum: Int64 = 0
    var count: Int64 = 0
    for (dy in 0..cellHeight) {
        for (dx in 0..cellWidth) {
            let px = x + dx
            let py = y + dy
            if (px >= 0 && py >= 0 && px < width && py < height) {
                let offset = (py * width + px) * 4
                let a = Int64(bytes[offset + 3])
                if (a >= options.alphaThreshold && visiblePixel(bytes, width, height, px, py, options)) {
                    rSum += Int64(bytes[offset])
                    gSum += Int64(bytes[offset + 1])
                    bSum += Int64(bytes[offset + 2])
                    count++
                }
            }
        }
    }
    if (count <= 0) { return Color.Reset }
    Color.Rgb(UInt8(rSum / count), UInt8(gSum / count), UInt8(bSum / count))
}

func halfBlockRune(upper: Bool, lower: Bool): Rune {
    if (upper && lower) { r'█' }
    else if (upper) { r'▀' }
    else if (lower) { r'▄' }
    else { r' ' }
}

func brailleMask(x: Int64, y: Int64): UInt32 {
    match ((x, y)) {
        case (0, 0) => 0x01
        case (0, 1) => 0x02
        case (0, 2) => 0x04
        case (0, 3) => 0x40
        case (1, 0) => 0x08
        case (1, 1) => 0x10
        case (1, 2) => 0x20
        case (1, 3) => 0x80
        case _ => 0
    }
}

func runeAt(text: String, index: Int64): Rune {
    var current: Int64 = 0
    for (r in text.runes()) {
        if (current == index) { return r }
        current++
    }
    r' '
}

func runeCount(text: String): Int64 {
    var count: Int64 = 0
    for (_ in text.runes()) {
        count++
    }
    count
}

func zoomAsciiLine(line: String, zoom: Int64, maxWidth: Int64): String {
    if (maxWidth <= 0) { return "" }
    if (zoom <= 1) { return truncateAscii(line, maxWidth) }
    let builder = StringBuilder()
    var cells: Int64 = 0
    for (r in line.runes()) {
        for (_ in 0..zoom) {
            if (cells >= maxWidth) { return builder.toString() }
            builder.append(r)
            cells++
        }
    }
    truncateAscii(builder.toString(), maxWidth)
}

func renderColoredAsciiLine(buffer: Buffer, x: Int64, y: Int64, line: String, frame: AsciiFrame, sourceY: Int64, zoom: Int64, maxWidth: Int64, baseStyle: Style): Unit {
    var outX: Int64 = 0
    var sourceX: Int64 = 0
    for (r in line.runes()) {
        for (_ in 0..zoom) {
            if (outX >= maxWidth) { return }
            let color = frame.colorAt(sourceY, sourceX)
            let cellStyle = if (colorEqualsLocal(color, Color.Reset)) { baseStyle } else { baseStyle.withFg(color) }
            buffer.setString(x + outX, y, runeToStringLocal(r), style: cellStyle)
            outX++
        }
        sourceX++
    }
}

func modPositive(value: Int64, modulus: Int64): Int64 {
    if (modulus <= 0) { return 0 }
    let result = value % modulus
    if (result < 0) { result + modulus } else { result }
}

func clampLocal(value: Int64, low: Int64, high: Int64): Int64 {
    min(max(value, low), high)
}

func joinLocal(parts: Array<String>, sep: String): String {
    let builder = StringBuilder()
    for (i in 0..parts.size) {
        if (i > 0) { builder.append(sep) }
        builder.append(parts[i])
    }
    builder.toString()
}

func truncateAscii(text: String, maxWidth: Int64): String {
    if (maxWidth <= 0) { return "" }
    let builder = StringBuilder()
    var width: Int64 = 0
    for (r in text.runes()) {
        if (width >= maxWidth) { break }
        builder.append(r)
        width++
    }
    builder.toString()
}

func runeToStringLocal(r: Rune): String {
    let builder = StringBuilder()
    builder.append(r)
    builder.toString()
}

func colorEqualsLocal(a: Color, b: Color): Bool {
    match ((a, b)) {
        case (Color.Reset, Color.Reset) => true
        case (Color.Black, Color.Black) => true
        case (Color.Red, Color.Red) => true
        case (Color.Green, Color.Green) => true
        case (Color.Yellow, Color.Yellow) => true
        case (Color.Blue, Color.Blue) => true
        case (Color.Magenta, Color.Magenta) => true
        case (Color.Cyan, Color.Cyan) => true
        case (Color.White, Color.White) => true
        case (Color.Indexed(x), Color.Indexed(y)) => x == y
        case (Color.Rgb(ar, ag, ab), Color.Rgb(br, bg, bb)) => ar == br && ag == bg && ab == bb
        case _ => false
    }
}
