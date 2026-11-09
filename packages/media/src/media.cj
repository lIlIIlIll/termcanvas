package media

import core.*
import std.process.*
import std.collection.*
import std.time.*

/** 媒体解码的来源、目标区域、协议和帧索引。 */
public class MediaDecodeRequest {
    /** 要解码的媒体来源。 */
    public let source: MediaSource
    /** 目标终端区域。 */
    public let area: Rect
    /** 请求的输出协议。 */
    public let protocol: MediaProtocol
    /** 请求帧索引，至少为零。 */
    public let frameIndex: Int64

    /** 创建解码请求。
     * @param source 媒体来源
     * @param area 目标区域
     * @param protocol 输出协议
     * @param frameIndex 帧索引，负值按零处理
     */
    public init(source: MediaSource, area: Rect, protocol: MediaProtocol, frameIndex!: Int64 = 0) {
        this.source = source
        this.area = area
        this.protocol = protocol
        this.frameIndex = max(0, frameIndex)
    }
}

/** 将媒体请求解码为可放置帧的接口。 */
public interface MediaAdapter {
    /** 解码媒体请求。
     * @param request 媒体解码请求
     * @return 解码后的帧
     */
    func decode(request: MediaDecodeRequest): MediaFrameData
}

/** 始终返回媒体文本回退帧。 */
public class FallbackMediaAdapter <: MediaAdapter {
    /** 创建文本回退适配器。 */
    public init() {}

    /** 将请求转换为文本回退帧。
     * @param request 媒体请求
     * @return 文本帧
     */
    public func decode(request: MediaDecodeRequest): MediaFrameData {
        MediaFrameData.text(mediaFallbackText(request.source))
    }
}

/** 使用外部工具解码 Kitty 或 Sixel 图像；失败时返回文本回退。 */
public class ExternalMediaAdapter <: MediaAdapter {
    private let magick: String
    private let ffmpeg: String
    private let sixelEncoder: String

    /** 创建外部媒体适配器。
     * @param magick 图片解码工具的可执行文件
     * @param ffmpeg 视频和动画解码工具的可执行文件
     * @param sixelEncoder Sixel 编码工具的可执行文件
     */
    public init(magick!: String = "magick", ffmpeg!: String = "ffmpeg", sixelEncoder!: String = "img2sixel") {
        this.magick = magick
        this.ffmpeg = ffmpeg
        this.sixelEncoder = sixelEncoder
    }

    /** 解码请求；文本协议或解码失败时返回文本回退。
     * @param request 媒体请求
     * @return 媒体帧
     */
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

    /** 生成供查看的外部工具命令文本；文本未经过 shell 转义。
     * @param request 媒体解码请求
     * @return 命令文本；无需工具或无法生成时为空字符串
     */
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

/** 将像素转换为终端字符的方式。 */
public enum AsciiRenderMode {
    /** 使用亮度字符梯度。 */
    | Ascii
    /** 用半块字符表示上下两个像素。 */
    | HalfBlock
    /** 用盲文点阵表示像素。 */
    | Braille
}

/** 控制字符帧尺寸、采样和颜色的配置。 */
public struct AsciiRenderOptions {
    /** 目标字符宽度，范围为 1 到 240。 */
    public let width: Int64
    /** 目标字符高度，范围为 1 到 120。 */
    public let height: Int64
    /** 目标帧率，范围为 1 到 30。 */
    public let fps: Int64
    /** ASCII 模式从暗到亮使用的字符梯度。 */
    public let ramp: String
    /** 是否反转亮度。 */
    public let invert: Bool
    /** 透明度阈值，范围为 0 到 255。 */
    public let alphaThreshold: Int64
    /** 字符采样模式。 */
    public let mode: AsciiRenderMode
    /** 是否保存每个字符的颜色。 */
    public let color: Bool
    /** 半块和盲文模式的亮度阈值，范围为 0 到 255。 */
    public let binaryThreshold: Int64

    /** 创建字符渲染配置；尺寸、帧率和阈值会限制在允许范围内。
     * @param width 目标字符宽度
     * @param height 目标字符高度
     * @param fps 目标帧率
     * @param ramp ASCII 亮度梯度；空字符串使用默认值
     * @param invert 是否反转亮度
     * @param alphaThreshold 透明度阈值
     * @param mode 字符采样模式
     * @param color 是否保留颜色
     * @param binaryThreshold 半块及盲文的亮度阈值
     */
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

    /** 获取帧持续时间。
     * @return 按帧率计算的毫秒数，至少为一
     */
    public func frameMillis(): Int64 {
        max(1, 1000 / fps)
    }

    /** 获取输入采样宽度。
     * @return 盲文模式为字符宽度的两倍，其他模式为字符宽度
     */
    public func sampleWidth(): Int64 {
        match (mode) {
            case AsciiRenderMode.Braille => width * 2
            case _ => width
        }
    }

    /** 获取输入采样高度。
     * @return 半块模式为字符高度的两倍，盲文模式为四倍，其他模式为字符高度
     */
    public func sampleHeight(): Int64 {
        match (mode) {
            case AsciiRenderMode.HalfBlock => height * 2
            case AsciiRenderMode.Braille => height * 4
            case _ => height
        }
    }
}

/** 包含文本行、可选颜色和帧持续时间。 */
public struct AsciiFrame {
    /** 字符帧的文本行。 */
    public let lines: Array<String>
    /** 各文本行对应的颜色数组；可为空。 */
    public let colors: Array<Array<Color>>
    /** 帧持续时间，至少为一毫秒。 */
    public let durationMillis: Int64

    /** 创建字符帧。
     * @param lines 文本行
     * @param durationMillis 帧持续毫秒数，至少为一
     * @param colors 可选的逐行颜色
     */
    public init(lines: Array<String>, durationMillis!: Int64 = 83, colors!: Array<Array<Color>> = []) {
        this.lines = lines
        this.colors = colors
        this.durationMillis = max(1, durationMillis)
    }

    /** 将文本行用换行符连接。
     * @return 字符帧文本
     */
    public func text(): String {
        joinLocal(lines, "\n")
    }

    /** 判断是否提供了颜色行。
     * @return 颜色数组非空时为 true
     */
    public func hasColors(): Bool {
        colors.size > 0
    }

    /** 获取一个字符位置的颜色。
     * @param row 颜色行索引
     * @param column 列索引
     * @return 对应颜色；超出范围时为 Color.Reset
     */
    public func colorAt(row: Int64, column: Int64): Color {
        if (row < 0 || column < 0 || row >= colors.size || column >= colors[row].size) {
            return Color.Reset
        }
        colors[row][column]
    }
}

/** 按顺序循环播放字符帧的动画。 */
public class AsciiAnimation {
    private let frames: Array<AsciiFrame>
    private let fallback: AsciiFrame

    /** 创建字符动画。
     * @param frames 顺序播放的帧
     */
    public init(frames: Array<AsciiFrame>) {
        this.frames = frames
        this.fallback = AsciiFrame([""], durationMillis: 1000)
    }

    /** 获取帧数。
     * @return 帧数
     */
    public func frameCount(): Int64 {
        frames.size
    }

    /** 判断动画是否没有帧。
     * @return 无帧时为 true
     */
    public func isEmpty(): Bool {
        frames.size == 0
    }

    /** 计算一轮动画的持续时间。
     * @return 帧时长之和；空动画返回一毫秒
     */
    public func totalDurationMillis(): Int64 {
        var total: Int64 = 0
        for (frame in frames) {
            total += frame.durationMillis
        }
        max(1, total)
    }

    /** 按索引循环选择帧；空动画返回默认空帧。
     * @param index 帧索引，可为负数
     * @return 选中的帧
     */
    public func frameAtIndex(index: Int64): AsciiFrame {
        if (frames.size == 0) { return fallback }
        frames[modPositive(index, frames.size)]
    }

    /** 根据经过的时间循环选择帧；空动画返回默认空帧。
     * @param elapsedMillis 经过的毫秒数，负值按零处理
     * @return 选中的帧
     */
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

/** 根据经过时间渲染字符动画的视图。 */
public class AsciiAnimationView <: Widget {
    private let animation: AsciiAnimation
    private let elapsedMillis: Int64
    private let zoom: Int64
    private let paused: Bool
    private let block: ?Block
    private let style: ?Style
    private let pausedStyle: ?Style

    /** 创建动画视图；经过时间下限为 0，缩放倍数限制在 1 到 4。未指定样式时使用应用主题的普通或警告角色，无主题时使用原有白色或黄色；显式样式和帧内颜色优先。
     * @param animation 要显示的字符动画
     * @param elapsedMillis 已经过的毫秒数
     * @param zoom 字符缩放倍数
     * @param paused 是否使用暂停样式
     * @param block 可选的边框
     * @param style 可选的播放样式
     * @param pausedStyle 可选的暂停样式
     */
    public init(
        animation: AsciiAnimation,
        elapsedMillis!: Int64 = 0,
        zoom!: Int64 = 1,
        paused!: Bool = false,
        block!: ?Block = None,
        style!: ?Style = None,
        pausedStyle!: ?Style = None
    ) {
        this.animation = animation
        this.elapsedMillis = max(0, elapsedMillis)
        this.zoom = clampLocal(zoom, 1, 4)
        this.paused = paused
        this.block = block
        this.style = style
        this.pausedStyle = pausedStyle
    }

    /** 将当前动画帧绘制到目标区域。
     * @param area 绘制区域
     * @param buffer 目标缓冲区
     */
    public func render(area: Rect, buffer: Buffer): Unit {
        var target = area
        if (let Some(b) <- block) {
            b.render(area, buffer)
            target = b.inner(area)
        }
        if (target.width <= 0 || target.height <= 0) { return }
        let canvas = Canvas(buffer, target)
        let frame = animation.frameAtElapsed(elapsedMillis)
        let explicit = if (paused) { pausedStyle } else { style }
        let rowStyle = match (explicit) {
            case Some(value) => value
            case None => match (buffer.resolveTheme(Option<Theme>.None)) {
                case Some(theme) => if (paused) { theme.warning } else { theme.normal }
                case None => if (paused) { Style(fg: Color.Yellow) } else { Style(fg: Color.White) }
            }
        }
        var outY: Int64 = 0
        for (sourceY in 0..frame.lines.size) {
            if (outY >= target.height) { break }
            let line = frame.lines[sourceY]
            for (_ in 0..zoom) {
                if (outY >= target.height) { break }
                if (frame.hasColors()) {
                    renderColoredAsciiLine(canvas, target.x, target.y + outY, line, frame, sourceY, zoom, target.width, rowStyle)
                } else {
                    let rendered = zoomAsciiLine(line, zoom, target.width, options: canvas.textWidthOptions())
                    canvas.drawText(target.x, target.y + outY, rendered, rowStyle)
                }
                outY++
            }
        }
    }
}

/** 将行优先的 RGBA 字节转换为字符帧；尺寸无效或数据不足时返回空帧。
 * @param bytes 每像素四字节的 RGBA 数据
 * @param width 输入像素宽度
 * @param height 输入像素高度
 * @param options 渲染配置
 * @return 转换后的字符帧
 */
public func rgbaToAsciiFrame(bytes: Array<Byte>, width: Int64, height: Int64, options: AsciiRenderOptions): AsciiFrame {
    let targetWidth = max(0, width)
    let targetHeight = max(0, height)
    // Divide before multiplying so untrusted dimensions cannot overflow.
    if (targetWidth <= 0 || targetHeight <= 0 || targetHeight > bytes.size / 4 / targetWidth) {
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

/** 根据终端能力选择媒体协议，优先 Kitty，其次 Sixel，最后文本。
 * @param caps 终端能力
 * @return 首选媒体协议
 */
public func preferredMediaProtocol(caps: TerminalCapabilities): MediaProtocol {
    if (caps.kittyGraphics) { MediaProtocol.Kitty }
    else if (caps.sixel) { MediaProtocol.Sixel }
    else { MediaProtocol.Text }
}

/** 根据终端能力解码并创建媒体放置项。
 * @param id 放置项标识
 * @param source 媒体来源
 * @param area 目标区域
 * @param caps 终端能力
 * @param adapter 媒体解码适配器
 * @param fit 适配方式
 * @param frameIndex 请求的帧索引
 * @return 包含解码帧的媒体放置项
 */
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

func zoomAsciiLine(line: String, zoom: Int64, maxWidth: Int64, options!: TextWidthOptions = TextWidthOptions()): String {
    if (maxWidth <= 0) { return "" }
    if (zoom <= 1) { return truncateAscii(line, maxWidth, options: options) }
    let builder = StringBuilder()
    var cells: Int64 = 0
    for (cluster in graphemeClusters(line, options: options)) {
        if (cluster.width <= 0) { continue }
        for (_ in 0..zoom) {
            if (cluster.width > maxWidth - cells) { return builder.toString() }
            builder.append(cluster.text)
            cells += cluster.width
        }
    }
    builder.toString()
}

func renderColoredAsciiLine(canvas: Canvas, x: Int64, y: Int64, line: String, frame: AsciiFrame, sourceY: Int64, zoom: Int64, maxWidth: Int64, baseStyle: Style): Unit {
    var outX: Int64 = 0
    var sourceX: Int64 = 0
    for (cluster in graphemeClusters(line, options: canvas.textWidthOptions())) {
        if (cluster.width <= 0) { continue }
        for (_ in 0..zoom) {
            if (cluster.width > maxWidth - outX) { return }
            let color = frame.colorAt(sourceY, sourceX)
            let cellStyle = if (colorEqualsLocal(color, Color.Reset)) { baseStyle } else { baseStyle.withFg(color) }
            canvas.drawText(x + outX, y, cluster.text, cellStyle)
            outX += cluster.width
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

func truncateAscii(text: String, maxWidth: Int64, options!: TextWidthOptions = TextWidthOptions()): String {
    graphemePrefix(text, max(0, maxWidth), options: options)
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
