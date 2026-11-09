package cjtui_api_example

import core.*
import media.*

main(): Int64 {
    let options = AsciiRenderOptions(width: 2, height: 1, fps: 10, ramp: " .@", color: true)
    let pixels: Array<Byte> = [0, 0, 0, 255, 255, 255, 255, 255]
    let frame = rgbaToAsciiFrame(pixels, 2, 1, options)
    if (frame.lines.size != 1 || frame.text() != " @" || !frame.hasColors() ||
        frame.durationMillis != 100) {
        throw IllegalStateException("pixel conversion failed")
    }
    match (frame.colorAt(1, 0)) {
        case Color.Reset => ()
        case _ => throw IllegalStateException("out-of-range color failed")
    }
    let second = AsciiFrame(["done"], durationMillis: 50)
    let animation = AsciiAnimation([frame, second])
    if (animation.isEmpty() || animation.frameCount() != 2 || animation.totalDurationMillis() != 150 ||
        animation.frameAtIndex(-1).text() != "done" || animation.frameAtElapsed(100).text() != "done") {
        throw IllegalStateException("animation timing failed")
    }
    let half = AsciiRenderOptions(width: 2, height: 3, mode: AsciiRenderMode.HalfBlock)
    let dots = AsciiRenderOptions(width: 2, height: 3, mode: AsciiRenderMode.Braille)
    if (half.sampleWidth() != 2 || half.sampleHeight() != 6 || dots.sampleWidth() != 4 || dots.sampleHeight() != 12) {
        throw IllegalStateException("sampling dimensions failed")
    }
    return 0
}
