package cjtui_api_example

import core.*
import media.*

main(): Int64 {
    let source = MediaSource("clip", "clip.mp4", kind: MediaKind.Video)
    let options = AsciiRenderOptions(width: 20, height: 10, fps: 12)
    let decoder = FfmpegAsciiAnimationDecoder()
    let command = decoder.commandFor(source, options)
    if (!command.contains("clip.mp4") || !command.contains("fps=12")) {
        throw IllegalStateException("decoder configuration failed")
    }
    // 未安装或不能启动 ffmpeg 时，应用可使用 None 选择回退界面。
    let missing: AsciiAnimationDecoder = FfmpegAsciiAnimationDecoder(ffmpeg: "")
    if (missing.decode(source, options).isSome()) { throw IllegalStateException("decoder fallback failed") }
    return 0
}
