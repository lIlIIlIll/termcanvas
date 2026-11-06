package game

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class GameVisualContextTest {
    @TestCase
    func spriteAndTileMapUseDestinationWidthPolicy(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let buffer = Buffer(Rect(0, 0, 6, 2))
        buffer.setTextWidthOptions(wide)
        SpriteRenderer().drawSprite(Canvas(buffer, buffer.area), Transform2D(),
            Sprite2D(["·X"], style: Style(fg: Color.Red)), Camera2D(viewport: buffer.area))
        @Expect(buffer.getCell(0, 0).symbol, "·")
        @Expect(buffer.getCell(1, 0).symbol, "")
        @Expect(buffer.getCell(2, 0).symbol, "X")
        @Expect(buffer.getCell(2, 0).style, Style(fg: Color.Red))

        let map = TileMap(["·#"], widthOptions: wide)
        @Expect(map.width, 3)
        @Expect(map.tileAt(2, 0), "#")
        map.render(Rect(0, 1, 6, 1), buffer, camera: Camera2D(viewport: Rect(0, 1, 6, 1)))
        @Expect(buffer.getCell(0, 1).symbol, "·")
        @Expect(buffer.getCell(1, 1).symbol, "")
        @Expect(buffer.getCell(2, 1).symbol, "#")
    }

    @TestCase
    func tileMapRetainsStyleMethodReference(): Unit {
        let area = Rect(0, 0, 2, 1)
        let map = TileMap(["#"])
        let render: (Rect, Buffer, Camera2D, Style) -> Unit = map.render
        let explicit = Style(fg: Color.Red)
        let buffer = Buffer(area)
        buffer.setTheme(Theme(normal: Style(fg: Color.Green)))
        render(area, buffer, Camera2D(), explicit)
        @Expect(buffer.getCell(0, 0).symbol, "#")
        @Expect(buffer.getCell(0, 0).style, explicit)
        map.render(area, buffer, style: Style(fg: Color.White))
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.White))
    }

    @TestCase
    func tileMapDefaultInheritsThemeAndExplicitStyleWins(): Unit {
        let theme = Theme(normal: Style(fg: Color.Green, bg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 4, 1))
        buffer.setTheme(theme)
        TileMap(["##"]).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, theme.adapted(buffer.capabilities()).normal)
        TileMap(["##"]).render(buffer.area, buffer, style: Style(fg: Color.Red))
        @Expect(buffer.getCell(0, 0).style, Style(fg: Color.Red))
        TileMap(["##"]).render(buffer.area, buffer, style: Style.default())
        @Expect(buffer.getCell(0, 0).style, Style.default())
        let plain = Buffer(Rect(0, 0, 2, 1))
        TileMap(["##"]).render(plain.area, plain)
        @Expect(plain.getCell(0, 0).style, Style(fg: Color.White))
    }
}
