package media

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class MediaBoundaryTest {
    @TestCase
    func decodingRejectsInvalidDimensionsBeforeLaunchingTools(): Unit {
        var negativeWidth = Rect(0, 0, 1, 1)
        negativeWidth.width = -1
        var negativeHeight = Rect(0, 0, 1, 1)
        negativeHeight.height = -1
        let adapter = ExternalMediaAdapter(magick: "./testdata/absent-media-boundary-tool",
            ffmpeg: "./testdata/absent-media-boundary-tool", sixelEncoder: "./testdata/absent-media-boundary-tool")
        let source = MediaSource("missing", "missing", alt: "fallback")
        for (area in [negativeWidth, negativeHeight, Rect(0, 0, 1, 4097), Rect(0, 0, 129, 256)]) {
            @Expect(mediaDimensions(area).isNone())
            @Expect(adapter.commandFor(MediaDecodeRequest(source, area, MediaProtocol.Sixel)), "")
            @Expect(isText(adapter.decode(MediaDecodeRequest(source, area, MediaProtocol.Sixel)).protocol))
        }
        match (mediaDimensions(Rect(0, 0, 128, 256))) {
            case Some((width, height)) =>
                @Expect(width, 1024)
                @Expect(height, 4096)
            case None => @Expect(false)
        }
        @Expect(mediaDimensions(Rect(0, 0, 0, 4096)).isSome())
        @Expect(isText(adapter.decode(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Text)).protocol))
        @Expect(isText(adapter.decode(MediaDecodeRequest(source, Rect(0, 0, 1, 1), MediaProtocol.Sixel)).protocol))
        let video = MediaSource("video", "missing", kind: MediaKind.Video)
        @Expect(isText(adapter.decode(MediaDecodeRequest(video, Rect(0, 0, 1, 1), MediaProtocol.Kitty)).protocol))
    }

    @TestCase
    func sixelEnvelopesPreserveIncompleteHeadersAndUnwrappedPayloads(): Unit {
        let cases: Array<(String, String)> = [
            ("", ""), ("payload", "payload"), ("\u{1B}P", "\u{1B}P"),
            ("\u{1B}P1;2", "\u{1B}P1;2"), ("\u{1B}P1;2q", "\u{1B}P1;2q"),
            ("\u{1B}P1;2qdata\u{1B}\\", "data"), ("\u{1B}Pq", ""),
            ("\u{1B}P0;0;0q", ""), ("payload\u{1B}\\", "payload"),
            ("\u{1B}P1;2\u{1B}\\", "\u{1B}P1;2")
        ]
        for ((source, expected) in cases) { @Expect(stripSixelEnvelope(source), expected) }
        @Expect(indexOfAscii("", b'q'), -1)
        @Expect(indexOfAscii("abc", b'q'), -1)
        @Expect(indexOfAscii("éq", b'q'), 2)
    }

    @TestCase
    func samplingDimensionsAndFrameBudgetsMatchEachRenderMode(): Unit {
        let half = AsciiRenderOptions(width: 3, height: 2, fps: 30, mode: AsciiRenderMode.HalfBlock)
        @Expect(half.sampleWidth(), 3)
        @Expect(half.sampleHeight(), 4)
        @Expect(half.frameMillis(), 33)
        let braille = AsciiRenderOptions(width: 3, height: 2, mode: AsciiRenderMode.Braille)
        @Expect(braille.sampleWidth(), 6)
        @Expect(braille.sampleHeight(), 8)
        let options = AsciiRenderOptions(width: 1, height: 1, ramp: "@")
        @Expect(asciiAnimationFromRgba([], options).isNone())
        @Expect(asciiAnimationFromRgba(Array<Byte>(5, repeat: 255), options).isNone())
        @Expect(asciiAnimationFromRgba(Array<Byte>(257 * 4, repeat: 255), options).isNone())
        match (asciiAnimationFromRgba(Array<Byte>(256 * 4, repeat: 255), options)) {
            case Some(animation) =>
                @Expect(animation.frameCount(), 256)
                @Expect(animation.frameAtIndex(255).text(), "@")
                @Expect(animation.frameAtIndex(-1).text(), "@")
            case None => @Expect(false)
        }
        for ((width, height) in [(1, 0), (0, 1), (1, 2), (9223372036854775807, 1)]) {
            @Expect(rgbaToAsciiFrame([255, 255, 255, 255], width, height, options).lines.size, 0)
        }
    }

    @TestCase
    func oddDimensionsProducePartialHalfBlockAndBrailleCells(): Unit {
        let half = rgbaToAsciiFrame(Array<Byte>(2 * 3 * 4, repeat: 255), 2, 3,
            AsciiRenderOptions(mode: AsciiRenderMode.HalfBlock, color: true))
        @Expect(half.text(), "██\n▀▀")
        @Expect(isRgb(half.colorAt(1, 1), 255, 255, 255))
        @Expect(isReset(half.colorAt(2, 0)))
        let braille = rgbaToAsciiFrame(Array<Byte>(3 * 5 * 4, repeat: 255), 3, 5,
            AsciiRenderOptions(mode: AsciiRenderMode.Braille, color: true))
        @Expect(braille.text(), "⣿⡇\n⠉⠁")
        @Expect(isRgb(braille.colorAt(1, 1), 255, 255, 255))
        @Expect(isReset(braille.colorAt(0, 2)))
        @Expect(isReset(braille.colorAt(0, -1)))
        @Expect(brailleMask(0, 4), 0)
        @Expect(brailleMask(1, -1), 0)
    }

    @TestCase
    func invertedBinarySamplingAndAlphaThresholdUseInclusiveEndpoints(): Unit {
        let dark: Array<Byte> = [0, 0, 0, 10]
        let bright: Array<Byte> = [255, 255, 255, 10]
        let options = AsciiRenderOptions(invert: true, alphaThreshold: 10, binaryThreshold: 255)
        @Expect(visiblePixel(dark, 1, 1, 0, 0, options))
        @Expect(!visiblePixel(bright, 1, 1, 0, 0, options))
        @Expect(!visiblePixel([0, 0, 0, 9], 1, 1, 0, 0, options))
        for ((x, y) in [(0, -1), (1, 0), (0, 1)]) { @Expect(!visiblePixel(dark, 1, 1, x, y, options)) }
        let half = rgbaToAsciiFrame([0, 0, 0, 10, 255, 255, 255, 10], 1, 2,
            AsciiRenderOptions(mode: AsciiRenderMode.HalfBlock, invert: true, alphaThreshold: 10, color: true))
        @Expect(half.text(), "▀")
        @Expect(isRgb(half.colorAt(0, 0), 0, 0, 0))
        @Expect(asciiRampChar(0, 0, 0, 10, AsciiRenderOptions(ramp: "é🙂", invert: true, alphaThreshold: 10)).toString(), "🙂")
        @Expect(asciiRampChar(255, 255, 255, 10, AsciiRenderOptions(ramp: "é🙂", invert: true, alphaThreshold: 10)).toString(), "é")
        @Expect(asciiRampChar(-10, -10, -10, 255, AsciiRenderOptions(ramp: "ab")).toString(), "a")
        @Expect(asciiRampChar(300, 300, 300, 255, AsciiRenderOptions(ramp: "ab")).toString(), "b")
    }

    @TestCase
    func averageColorClipsTheSamplingRectangleAndIgnoresInvisiblePixels(): Unit {
        let options = AsciiRenderOptions(alphaThreshold: 10, binaryThreshold: 1)
        let pixels: Array<Byte> = [100, 40, 20, 10, 200, 80, 40, 255, 0, 0, 0, 255, 255, 255, 255, 0]
        @Expect(isRgb(averagePixelColor(pixels, 2, 2, -1, -1, 4, 4, options), 150, 60, 30))
        @Expect(isRgb(averagePixelColor(pixels, 2, 2, 1, 0, 2, 3, options), 200, 80, 40))
        @Expect(isReset(averagePixelColor(pixels, 2, 2, 0, 0, 0, 2, options)))
        @Expect(isReset(averagePixelColor(pixels, 2, 2, 0, 0, 2, 0, options)))
        @Expect(isReset(averagePixelColor(pixels, 2, 2, 3, 0, 1, 1, options)))
        @Expect(isRgb(pixelColor(-10, 300, 127, 10, options), 0, 255, 127))
        @Expect(isRgb(pixelColor(300, -10, 300, 10, options), 255, 0, 255))
    }

    @TestCase
    func colorEqualityDistinguishesEveryVariantAndRgbChannel(): Unit {
        let colors: Array<Color> = [Color.Reset, Color.Black, Color.Red, Color.Green, Color.Yellow,
            Color.Blue, Color.Magenta, Color.Cyan, Color.White, Color.Indexed(1), Color.Rgb(1, 2, 3)]
        for (i in 0..colors.size) {
            for (j in 0..colors.size) { @Expect(colorEqualsLocal(colors[i], colors[j]), i == j) }
        }
        @Expect(!colorEqualsLocal(Color.Rgb(1, 2, 3), Color.Rgb(9, 2, 3)))
        @Expect(!colorEqualsLocal(Color.Rgb(1, 2, 3), Color.Rgb(1, 9, 3)))
        @Expect(!colorEqualsLocal(Color.Rgb(1, 2, 3), Color.Rgb(1, 2, 9)))
    }

    @TestCase
    func zoomClipsWholeGraphemesAndKeepsColorColumnsAligned(): Unit {
        @Expect(zoomAsciiLine("界a", 2, 3), "界")
        @Expect(zoomAsciiLine("界a", 2, 5), "界界a")
        @Expect(zoomAsciiLine("\u{301}a", 2, 2), "aa")
        @Expect(zoomAsciiLine("界a", 1, 1), "")
        let frame = AsciiFrame(["\u{301}界a"], colors: [[Color.Red, Color.Green]])
        let buffer = Buffer(Rect(0, 0, 5, 1))
        let canvas = Canvas(buffer, buffer.area)
        renderColoredAsciiLine(canvas, 0, 0, frame.lines[0], frame, 0, 2, 5, Style(bg: Color.Blue))
        @Expect(buffer.getCell(0, 0).symbol, "界")
        @Expect(buffer.getCell(2, 0).symbol, "界")
        @Expect(buffer.getCell(4, 0).symbol, "a")
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red, bg: Color.Blue))
        @Expect(buffer.getCell(4, 0).style, Style(fg: Color.Green, bg: Color.Blue))
        let narrow = Buffer(Rect(0, 0, 1, 1))
        renderColoredAsciiLine(Canvas(narrow, narrow.area), 0, 0, "界", frame, 0, 1, 1, Style())
        @Expect(narrow.getCell(0, 0).symbol, " ")
    }

    @TestCase
    func animationViewStopsAtTheVerticalClipAndElapsedBoundaries(): Unit {
        let animation = AsciiAnimation([AsciiFrame(["a", "b", "c"], durationMillis: 1), AsciiFrame(["d"], durationMillis: 2)])
        @Expect(animation.frameAtElapsed(-1).text(), "a\nb\nc")
        @Expect(animation.frameAtElapsed(1).text(), "d")
        @Expect(animation.frameAtElapsed(2).text(), "d")
        @Expect(animation.frameAtElapsed(3).text(), "a\nb\nc")
        let buffer = Buffer(Rect(0, 0, 2, 3))
        AsciiAnimationView(animation, zoom: 2).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(buffer.getCell(0, 1).symbol, "a")
        @Expect(buffer.getCell(0, 2).symbol, "b")
        AsciiAnimationView(animation).render(Rect(0, 0, 2, 0), buffer)
        @Expect(buffer.getCell(0, 0).symbol, "a")
        @Expect(modPositive(-6, 3), 0)
        @Expect(modPositive(6, -1), 0)
        @Expect(runeAt("é🙂", -1).toString(), " ")
        @Expect(runeAt("é🙂", 1).toString(), "🙂")
    }
}
