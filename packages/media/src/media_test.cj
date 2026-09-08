package media

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class MediaExtensionTest {
    @TestCase
    func preferredProtocolUsesKittyBeforeSixelAndFallsBackToText(): Unit {
        @Expect(isKitty(preferredMediaProtocol(TerminalCapabilities(kittyGraphics: true, sixel: true))))
        @Expect(isSixel(preferredMediaProtocol(TerminalCapabilities(kittyGraphics: false, sixel: true))))
        @Expect(isText(preferredMediaProtocol(TerminalCapabilities(kittyGraphics: false, sixel: false))))
    }

    @TestCase
    func externalAdapterBuildsCommandsAndFrames(): Unit {
        var pixels = ""
        for (_ in 0..128) { pixels += "\\377\\000\\000\\377" }
        let source = MediaSource("img", pixels, alt: "demo")
        let request = MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Kitty)
        let adapter = ExternalMediaAdapter(magick: "/usr/bin/printf")
        @Expect(adapter.commandFor(request).contains("-resize 8x16!"))
        let frame = adapter.decode(request)
        @Expect(isKitty(frame.protocol))
        @Expect(frame.widthPixels, 8)
        @Expect(frame.heightPixels, 16)
        @Expect(frame.payload.size, 684)
        let short = adapter.decode(MediaDecodeRequest(MediaSource("short", "x"), Rect(0, 0, 1, 1), MediaProtocol.Kitty))
        @Expect(isText(short.protocol))
        let large = adapter.decode(MediaDecodeRequest(source, Rect(0, 0, 9223372036854775807, 1), MediaProtocol.Kitty))
        @Expect(isText(large.protocol))
    }

    @TestCase
    func requestedFrameIndexControlsSelectionAndUnsupportedSixelFallsBack(): Unit {
        let source = MediaSource("gif", "demo.gif", kind: MediaKind.Animation)
        let adapter = ExternalMediaAdapter()
        let first = MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Kitty)
        let later = MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Kitty, frameIndex: 7)
        @Expect(adapter.commandFor(first).contains("select=eq(n\\,0)"))
        @Expect(adapter.commandFor(later).contains("select=eq(n\\,7)"))
        @Expect(isText(adapter.decode(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Sixel, frameIndex: 7)).protocol))
        let fixture = ExternalMediaAdapter(ffmpeg: "./testdata/fake_ffmpeg.sh")
        let selected = MediaSource("frames", "selected-frame", kind: MediaKind.Animation)
        let red = fixture.decode(MediaDecodeRequest(selected, Rect(0, 0, 1, 1), MediaProtocol.Kitty))
        let blue = fixture.decode(MediaDecodeRequest(selected, Rect(0, 0, 1, 1), MediaProtocol.Kitty, frameIndex: 7))
        @Expect(isKitty(red.protocol))
        @Expect(isKitty(blue.protocol))
        @Expect(red.payload != blue.payload)
    }

    @TestCase
    func animationBudgetsRejectExtraAndPartialFrames(): Unit {
        let decoder = FfmpegAsciiAnimationDecoder(ffmpeg: "./testdata/fake_ffmpeg.sh")
        let options = AsciiRenderOptions(width: 1, height: 1)
        match (decoder.decode(MediaSource("one", "one-frame"), options)) {
            case Some(animation) => @Expect(animation.frameCount(), 1)
            case None => @Expect(false)
        }
        @Expect(decoder.decode(MediaSource("many", "many-frames"), options).isNone())
        @Expect(decoder.decode(MediaSource("partial", "partial-frame"), options).isNone())
    }

    @TestCase
    func rgbaToAsciiFrameMapsBrightnessAlphaAndInvert(): Unit {
        let options = AsciiRenderOptions(width: 3, height: 1, ramp: " .@", alphaThreshold: 10)
        let bytes: Array<Byte> = [
            0, 0, 0, 255,
            255, 255, 255, 255,
            200, 200, 200, 0
        ]
        let frame = rgbaToAsciiFrame(bytes, 3, 1, options)
        @Expect(frame.lines.size, 1)
        @Expect(frame.lines[0], " @ ")

        let inverted = rgbaToAsciiFrame(bytes, 3, 1, AsciiRenderOptions(width: 3, height: 1, ramp: " .@", invert: true, alphaThreshold: 10))
        @Expect(inverted.lines[0], "@  ")
    }

    @TestCase
    func highResolutionAsciiModesPackMultiplePixelsPerCell(): Unit {
        let halfBytes: Array<Byte> = [
            255, 255, 255, 255,
            0, 0, 0, 255,
            0, 0, 0, 255,
            255, 255, 255, 255
        ]
        let half = rgbaToAsciiFrame(halfBytes, 2, 2, AsciiRenderOptions(width: 2, height: 1, mode: AsciiRenderMode.HalfBlock))
        @Expect(half.lines.size, 1)
        @Expect(half.lines[0], "▀▄")

        let brailleBytes = Array<Byte>(2 * 4 * 4, repeat: 0)
        setPixel(brailleBytes, 2, 0, 0)
        setPixel(brailleBytes, 2, 1, 3)
        let braille = rgbaToAsciiFrame(brailleBytes, 2, 4, AsciiRenderOptions(width: 1, height: 1, mode: AsciiRenderMode.Braille))
        @Expect(braille.lines.size, 1)
        @Expect(braille.lines[0], "⢁")

        let dimBytes: Array<Byte> = [
            100, 100, 100, 255,
            0, 0, 0, 255
        ]
        let visibleAtLowThreshold = rgbaToAsciiFrame(dimBytes, 1, 2, AsciiRenderOptions(width: 1, height: 1, mode: AsciiRenderMode.HalfBlock, binaryThreshold: 80))
        let hiddenAtDefaultThreshold = rgbaToAsciiFrame(dimBytes, 1, 2, AsciiRenderOptions(width: 1, height: 1, mode: AsciiRenderMode.HalfBlock))
        @Expect(visibleAtLowThreshold.lines[0], "▀")
        @Expect(hiddenAtDefaultThreshold.lines[0], " ")
    }

    @TestCase
    func coloredAsciiFramesCarryPerCellRgbStyles(): Unit {
        let bytes: Array<Byte> = [
            255, 0, 0, 255,
            0, 64, 255, 255
        ]
        let frame = rgbaToAsciiFrame(bytes, 2, 1, AsciiRenderOptions(width: 2, height: 1, ramp: "#", color: true))
        @Expect(frame.lines[0], "##")
        @Expect(frame.hasColors())
        @Expect(isRgb(frame.colorAt(0, 0), 255, 0, 0))
        @Expect(isRgb(frame.colorAt(0, 1), 0, 64, 255))

        let animation = AsciiAnimation([frame])
        let buffer = Buffer(Rect(0, 0, 2, 1))
        AsciiAnimationView(animation, style: Style(fg: Color.White, bg: Color.Black)).render(Rect(0, 0, 2, 1), buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Rgb(255, 0, 0), bg: Color.Black))
        @Expect(buffer.getCell(1, 0).style, Style(fg: Color.Rgb(0, 64, 255), bg: Color.Black))
    }

    @TestCase
    func highResolutionColorUsesOnlyVisiblePixels(): Unit {
        let bytes = Array<Byte>(2 * 4 * 4, repeat: 0)
        setPixelColor(bytes, 2, 0, 0, 255, 0, 0)
        setPixelColor(bytes, 2, 1, 0, 0, 0, 80)
        setPixelColor(bytes, 2, 0, 1, 0, 0, 80)
        setPixelColor(bytes, 2, 1, 1, 0, 0, 80)

        let frame = rgbaToAsciiFrame(bytes, 2, 4, AsciiRenderOptions(width: 1, height: 1, mode: AsciiRenderMode.Braille, color: true, binaryThreshold: 70))
        @Expect(frame.lines[0], "⠁")
        @Expect(isRgb(frame.colorAt(0, 0), 255, 0, 0))
    }

    @TestCase
    func asciiAnimationSelectsFramesByIndexAndElapsedTime(): Unit {
        let animation = AsciiAnimation([
            AsciiFrame(["one"], durationMillis: 10),
            AsciiFrame(["two"], durationMillis: 20)
        ])
        @Expect(animation.frameCount(), 2)
        @Expect(animation.totalDurationMillis(), 30)
        @Expect(animation.frameAtIndex(2).lines[0], "one")
        @Expect(animation.frameAtElapsed(0).lines[0], "one")
        @Expect(animation.frameAtElapsed(10).lines[0], "two")
        @Expect(animation.frameAtElapsed(31).lines[0], "one")
    }

    @TestCase
    func ffmpegAsciiDecoderBuildsCommandAndFailsGracefully(): Unit {
        let source = MediaSource("gif", "demo.gif", kind: MediaKind.Animation)
        let options = AsciiRenderOptions(width: 12, height: 5, fps: 7, mode: AsciiRenderMode.Braille)
        let decoder = FfmpegAsciiAnimationDecoder(ffmpeg: "/bin/false")
        let command = decoder.commandFor(source, options)
        @Expect(command.contains("-vf fps=7,scale=24:20:flags=lanczos"))
        @Expect(command.contains("-pix_fmt rgba"))
        @Expect(command.contains("demo.gif"))
        match (decoder.decode(source, options)) {
            case Some(_) => @Expect(false)
            case None => @Expect(true)
        }
    }

    @TestCase
    func asciiAnimationViewRendersCurrentFrame(): Unit {
        let animation = AsciiAnimation([
            AsciiFrame(["ab"], durationMillis: 10),
            AsciiFrame(["cd"], durationMillis: 10)
        ])
        let buffer = Buffer(Rect(0, 0, 6, 3))
        AsciiAnimationView(animation, elapsedMillis: 10, zoom: 2, paused: true, block: Some(Block(title: "GIF"))).render(Rect(0, 0, 6, 3), buffer)
        @Expect(buffer.getCell(1, 1).symbol, "c")
        @Expect(buffer.getCell(2, 1).symbol, "c")
        @Expect(buffer.getCell(3, 1).symbol, "d")
        @Expect(buffer.getCell(4, 1).symbol, "d")
    }
    @TestCase
    func fallbackCommandsAndAsciiBoundaryContractsStayCovered(): Unit {
        let source = MediaSource("still", "image.png")
        let request = MediaDecodeRequest(source, Rect(0, 0, 2, 3), MediaProtocol.Kitty, frameIndex: -4)
        @Expect(request.frameIndex, 0)
        @Expect(isText(FallbackMediaAdapter().decode(request).protocol))
        let adapter = ExternalMediaAdapter(magick: "/bin/false", ffmpeg: "/bin/false", sixelEncoder: "/bin/false")
        @Expect(adapter.commandFor(MediaDecodeRequest(source, Rect(0, 0, 5000, 1), MediaProtocol.Kitty)), "")
        @Expect(adapter.commandFor(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Text)), "")
        @Expect(adapter.commandFor(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Sixel)), "/bin/false -w 8 -h 16 image.png")
        @Expect(adapter.commandFor(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Sixel, frameIndex: 1)), "")
        let video = MediaSource("video", "movie.mp4", kind: MediaKind.Video)
        let animation = MediaSource("animation", "movie.gif", kind: MediaKind.Animation)
        @Assert(adapter.commandFor(MediaDecodeRequest(video, Rect(0, 0, 1, 1), MediaProtocol.Kitty)).contains("movie.mp4"))
        @Assert(adapter.commandFor(MediaDecodeRequest(animation, Rect(0, 0, 1, 1), MediaProtocol.Kitty)).contains("movie.gif"))
        let options = AsciiRenderOptions(width: 0, height: 0, fps: 0, ramp: "", alphaThreshold: 999, binaryThreshold: -1)
        @Expect(options.width, 1)
        @Expect(options.height, 1)
        @Expect(options.fps, 1)
        @Expect(options.frameMillis(), 1000)
        @Expect(options.sampleWidth(), 1)
        @Expect(options.sampleHeight(), 1)
        let brailleOptions = AsciiRenderOptions(width: 2, height: 3, mode: AsciiRenderMode.Braille)
        @Expect(brailleOptions.sampleWidth(), 4)
        @Expect(brailleOptions.sampleHeight(), 12)
        let empty = AsciiAnimation([])
        @Expect(empty.isEmpty())
        @Expect(empty.frameAtIndex(-1).lines[0], "")
        @Expect(empty.frameAtElapsed(-1).lines[0], "")
        @Expect(empty.totalDurationMillis(), 1)
        let frame = AsciiFrame(["x"])
        @Expect(isReset(frame.colorAt(-1, 0)))
        @Expect(isReset(frame.colorAt(0, 0)))
        @Expect(rgbaToAsciiFrame([], 0, 0, options).lines.size, 0)
        @Expect(stripSixelEnvelope("\u{1B}PqABC\u{1B}\\"), "ABC")
        @Expect(stripSixelEnvelope("\u{1B}P0;0;0qABC\u{1B}\\"), "ABC")
        @Expect(stripSixelEnvelope("\u{1B}P1;2qABC"), "ABC")
        let buffer = Buffer(Rect(0, 0, 4, 2))
        AsciiAnimationView(empty, paused: false).render(buffer.area, buffer)
        AsciiAnimationView(AsciiAnimation([AsciiFrame(["abc"])]), block: Some(Block(title: "X"))).render(buffer.area, buffer)
        let placement = mediaPlacementWithAdapter("id", source, Rect(0, 0, 1, 1), TerminalCapabilities(), adapter: FallbackMediaAdapter())
        @Expect(placement.id, "id")
        @Expect(isText(placement.frame.protocol))
    }
    @TestCase
    func asciiConversionHelpersCoverAllPackingAndColorBoundaries(): Unit {
        @Expect(halfBlockRune(false, false), r' ')
        @Expect(halfBlockRune(true, false), r'▀')
        @Expect(halfBlockRune(false, true), r'▄')
        @Expect(halfBlockRune(true, true), r'█')
        for ((x, y) in [(0, 0), (0, 1), (0, 2), (0, 3), (1, 0), (1, 1), (1, 2), (1, 3)]) {
            @Expect(brailleMask(x, y) > 0)
        }
        @Expect(brailleMask(2, 4), 0)

        @Expect(colorEqualsLocal(Color.Reset, Color.Reset))
        @Expect(colorEqualsLocal(Color.Black, Color.Black))
        @Expect(colorEqualsLocal(Color.Red, Color.Red))
        @Expect(colorEqualsLocal(Color.Green, Color.Green))
        @Expect(colorEqualsLocal(Color.Yellow, Color.Yellow))
        @Expect(colorEqualsLocal(Color.Blue, Color.Blue))
        @Expect(colorEqualsLocal(Color.Magenta, Color.Magenta))
        @Expect(colorEqualsLocal(Color.Cyan, Color.Cyan))
        @Expect(colorEqualsLocal(Color.White, Color.White))
        @Expect(colorEqualsLocal(Color.Indexed(3), Color.Indexed(3)))
        @Expect(colorEqualsLocal(Color.Rgb(1, 2, 3), Color.Rgb(1, 2, 3)))
        @Expect(!colorEqualsLocal(Color.Red, Color.Blue))
        @Expect(!colorEqualsLocal(Color.Indexed(3), Color.Indexed(4)))
        @Expect(!colorEqualsLocal(Color.Rgb(1, 2, 3), Color.Rgb(1, 2, 4)))

        let options = AsciiRenderOptions(
            width: 1,
            height: 1,
            ramp: "@.",
            color: true,
            alphaThreshold: 10,
            binaryThreshold: 50
        )
        let bytes: Array<Byte> = [255, 0, 0, 255]
        @Expect(visiblePixel(bytes, 1, 1, 0, 0, options))
        @Expect(!visiblePixel(bytes, 1, 1, -1, 0, options))
        @Expect(!visiblePixel([255, 0, 0, 1], 1, 1, 0, 0, options))
        @Expect(isRgb(pixelColor(255, 0, 0, 255, options), 255, 0, 0))
        @Expect(isReset(pixelColor(255, 0, 0, 0, options)))
        @Expect(isReset(averagePixelColor([0, 0, 0, 0], 1, 1, 0, 0, 1, 2, options)))

        @Expect(zoomAsciiLine("abc", 1, 2), "ab")
        @Expect(zoomAsciiLine("ab", 2, 3), "aab")
        @Expect(zoomAsciiLine("abc", 2, 0), "")
        @Expect(truncateAscii("abc", 0), "")
        @Expect(truncateAscii("abc", 2), "ab")
        @Expect(modPositive(-1, 3), 2)
        @Expect(modPositive(4, 3), 1)
        @Expect(modPositive(4, 0), 0)
        @Expect(runeCount("é🙂"), 2)
        @Expect(runeAt("ab", 9).toString(), " ")
        @Expect(joinLocal([], ","), "")
        @Expect(joinLocal(["a", "b"], ","), "a,b")
        @Expect(frameFilter(2, 8, 16), "select=eq(n\\,2),scale=8:16")

        let twoFrames: Array<Byte> = [255, 0, 0, 255, 255, 0, 0, 255]
        match (asciiAnimationFromRgba(twoFrames, options)) {
            case Some(animation) => @Expect(animation.frameCount(), 2)
            case None => @Expect(false)
        }
        @Expect(asciiAnimationFromRgba([1, 2, 3], options).isNone())
        match (mediaDimensions(Rect(0, 0, 0, 0))) {
            case Some((width, height)) =>
                @Expect(width, 1)
                @Expect(height, 1)
            case None => @Expect(false)
        }
        @Expect(mediaDimensions(Rect(0, 0, 5000, 1)).isNone())

        let colored = AsciiAnimation([AsciiFrame(["a"], colors: [[Color.Reset]])])
        let buffer = Buffer(Rect(0, 0, 1, 1))
        AsciiAnimationView(colored, style: Style(fg: Color.Red)).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
    }

}
func setPixel(bytes: Array<Byte>, width: Int64, x: Int64, y: Int64): Unit {
    setPixelColor(bytes, width, x, y, 255, 255, 255)
}

func setPixelColor(bytes: Array<Byte>, width: Int64, x: Int64, y: Int64, r: Byte, g: Byte, b: Byte): Unit {
    let offset = (y * width + x) * 4
    bytes[offset] = r
    bytes[offset + 1] = g
    bytes[offset + 2] = b
    bytes[offset + 3] = 255
}

func isKitty(protocol: MediaProtocol): Bool {
    match (protocol) {
        case MediaProtocol.Kitty => true
        case _ => false
    }
}

func isSixel(protocol: MediaProtocol): Bool {
    match (protocol) {
        case MediaProtocol.Sixel => true
        case _ => false
    }
}

func isText(protocol: MediaProtocol): Bool {
    match (protocol) {
        case MediaProtocol.Text => true
        case _ => false
    }
}

func isRgb(color: Color, r: UInt8, g: UInt8, b: UInt8): Bool {
    match (color) {
        case Color.Rgb(cr, cg, cb) => cr == r && cg == g && cb == b
        case _ => false
    }
}
func isReset(color: Color): Bool {
    match (color) {
        case Color.Reset => true
        case _ => false
    }
}
