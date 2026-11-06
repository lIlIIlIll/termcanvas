package media

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class MediaVisualContextTest {
    @TestCase
    func coloredAndPlainAnimationUseDestinationWidthForZoomAndClip(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        for (colored in [false, true]) {
            let colors: Array<Array<Color>> = if (colored) { [[Color.Red, Color.Blue]] } else { [] }
            let frame = AsciiFrame(["·x"], colors: colors)
            let buffer = Buffer(Rect(0, 0, 6, 2))
            buffer.setTextWidthOptions(wide)
            AsciiAnimationView(AsciiAnimation([frame]), zoom: 2).render(buffer.area, buffer)
            @Expect(buffer.getCell(0, 0).symbol, "·")
            @Expect(buffer.getCell(2, 0).symbol, "·")
            @Expect(buffer.getCell(4, 0).symbol, "x")
            @Expect(buffer.getCell(5, 0).symbol, "x")
            if (colored) {
                @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
                @Expect(buffer.getCell(4, 0).style, Style(fg: Color.Blue))
            }
            let clipped = Buffer(Rect(0, 0, 1, 1))
            clipped.setTextWidthOptions(wide)
            AsciiAnimationView(AsciiAnimation([frame])).render(clipped.area, clipped)
            @Expect(clipped.getCell(0, 0).symbol, " ")
        }
    }

    @TestCase
    func defaultAnimationStylesInheritThemeButExplicitAndPixelColorsWin(): Unit {
        let theme = Theme(normal: Style(fg: Color.Green, bg: Color.Blue), warning: Style(fg: Color.Yellow, bg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 3, 1))
        buffer.setTheme(theme)
        let animation = AsciiAnimation([AsciiFrame(["x"], colors: [[Color.Red]])])
        AsciiAnimationView(animation).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red, bg: Color.Blue))
        AsciiAnimationView(animation, paused: true).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red, bg: Color.Red))
        AsciiAnimationView(animation, style: Style(fg: Color.White, bg: Color.Magenta)).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red, bg: Color.Magenta))
        AsciiAnimationView(animation, style: Style.default()).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
        let plain = Buffer(Rect(0, 0, 2, 1))
        AsciiAnimationView(AsciiAnimation([AsciiFrame(["x"])]), paused: true).render(plain.area, plain)
        @Expect(plain.getCell(0, 0).style, Style(fg: Color.Yellow))
    }
}
