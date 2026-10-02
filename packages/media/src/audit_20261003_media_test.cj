package media

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003MediaTest {
    @TestCase
    func animationPreservesWideGlyphsAcrossRenderBoundary(): Unit {
        for (colored in [false, true]) {
            let colors: Array<Array<Color>> = if (colored) { [[Color.Red]] } else { [] }
            let view = AsciiAnimationView(AsciiAnimation([AsciiFrame(["a"], colors: colors)]))
            let buffer = Buffer(Rect(0, 0, 4, 1))
            buffer.setString(0, 0, "中")
            let lead = buffer.getCell(0, 0)
            let tail = buffer.getCell(1, 0)
            view.render(Rect(1, 0, 1, 1), buffer)
            @Expect(buffer.getCell(0, 0), lead)
            @Expect(buffer.getCell(1, 0), tail)
        }
    }

    @TestCase
    func animationClipsAndZoomsWholeGraphemesByDisplayWidth(): Unit {
        for (colored in [false, true]) {
            let colors: Array<Array<Color>> = if (colored) { [[Color.Red, Color.Blue]] } else { [] }
            let frame = AsciiFrame(["中x"], colors: colors)
            let buffer = Buffer(Rect(0, 0, 7, 1))
            let sentinel = Cell("Z")
            buffer.fill(buffer.area, sentinel)
            AsciiAnimationView(AsciiAnimation([frame]), zoom: 2).render(Rect(1, 0, 3, 1), buffer)
            @Expect(buffer.getCell(1, 0).symbol, "中")
            @Expect(buffer.getCell(2, 0).symbol, "")
            @Expect(buffer.getCell(3, 0), sentinel)
            @Expect(buffer.getCell(4, 0), sentinel)
        }
        @Expect(zoomAsciiLine("e\u{301}x", 2, 4), "e\u{301}e\u{301}xx")
    }

    @TestCase
    func rgbaDimensionsRejectUnrepresentableFrameSizes(): Unit {
        @Expect(rgbaToAsciiFrame([], Int64.Max, 2, AsciiRenderOptions()).lines.size, 0)
        @Expect(rgbaToAsciiFrame([], 2, Int64.Max, AsciiRenderOptions()).lines.size, 0)
    }
}
