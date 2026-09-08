package game_demo

import core.*
import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class FarmGameRegressionTest {
    @TestCase
    func fullShippingBoxKeepsCropsAndShowsTheCapacityNotice(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            File.writeTo(path, "version=1\nplayer=24,4\nfacing=1\ninventory=2,0,0\nshipping=1000000,0,0\n".toArray())
            let game = FarmGame(path, false)
            game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Expect(renderedFarmText(game).contains("shipping box full; crops remain in bag"))
            game.save()
            let saved = String.fromUtf8(File.readFrom(path))
            @Expect(saved.contains("inventory=2,0,0\n"))
            @Expect(saved.contains("shipping=1000000,0,0\n"))
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func emptyBagHasADifferentNoticeFromAFullShippingBox(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            File.writeTo(path, "version=1\nplayer=24,4\nfacing=1\ninventory=0,0,0\nshipping=1000000,0,0\n".toArray())
            let game = FarmGame(path, false)
            game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Expect(renderedFarmText(game).contains("no crops in bag to ship"))
            game.save()
            let saved = String.fromUtf8(File.readFrom(path))
            @Expect(saved.contains("inventory=0,0,0\n"))
            @Expect(saved.contains("shipping=1000000,0,0\n"))
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func partialShippingCapacityTransfersOnlyTheAvailableSpace(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            File.writeTo(path, "version=1\nplayer=24,4\nfacing=1\ninventory=2,0,0\nshipping=999999,0,0\n".toArray())
            let game = FarmGame(path, false)
            game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Expect(renderedFarmText(game).contains("boxed 1 crops for tonight"))
            let saved = String.fromUtf8(File.readFrom(path))
            @Expect(saved.contains("inventory=1,0,0\n"))
            @Expect(saved.contains("shipping=1000000,0,0\n"))
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func realHeadlessFlowIncludesAnimatedDirtyRegionsAndSaveReload(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            let game = FarmGame(path, false)
            @Expect(game.headlessSmoke())
            @Expect(String.fromUtf8(File.readFrom(path)).contains("version=1\n"))
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func failedDecodePreservesTheExistingFileDuringLaterSaveAttempts(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        let original: Array<Byte> = [0xFF, 0x31, 0x32, 0x33]
        try {
            File.writeTo(path, original)
            let game = FarmGame(path, false)
            game.save()
            @Expect(!game.headlessSmoke())
            @Expect(File.readFrom(path), original)
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func extremeSaveValuesRemainWithinTheDocumentedGameDomain(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        let limit = "9223372036854775807"
        let text = "version=1\nday=" + limit + "\nmoney=" + limit +
            "\nshipping=" + limit + "," + limit + "," + limit + "\n"
        try {
            File.writeTo(path, text.toArray())
            let game = FarmGame(path, false)
            @Expect(game.shippingValue(), 255000000)
            game.save()
            let saved = String.fromUtf8(File.readFrom(path))
            @Expect(saved.contains("day=1000000000\n"))
            @Expect(saved.contains("money=1000000000000000\n"))
            @Expect(saved.contains("shipping=1000000,1000000,1000000\n"))
        } finally {
            remove(directory, recursive: true)
        }
    }

    @TestCase
    func interactiveCommandsDecodeEdgesAndFrameModesStayCovered(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            let malformed = "version=1\nday=bad\nminute=bad\nmoney=bad\nenergy=bad\nplayer=x\nfacing=99\ntool=99\nseed=-1\nseeds=1\ninventory=2,3\nshipping=4,5\nlastEarned=bad\nplots=bad|4,6,1,2,99,1|99,99,1,1,1,1\nignored=value\n"
            File.writeTo(path, malformed.toArray())
            let game = FarmGame(path, false)
            @Expect(game.day, 1)
            @Expect(game.minute, DAY_START)
            @Expect(game.facing, DIR_LEFT)
            @Expect(game.selectedTool, TOOL_HARVEST)
            @Expect(game.selectedCrop, CROP_COUNT - 1)
            @Expect(game.seeds[0], 1)
            @Expect(game.inventory[1], 3)
            @Expect(game.shipping[1], 5)
            @Expect(game.plots[0].crop, CROP_BERRY)
            @Expect(game.plots[0].growth, cropDays(CROP_BERRY))
            @Expect(game.plots[0].watered)

            @Expect(game.tileAt(-1, 0), "#")
            @Expect(game.tileAt(1, 1), ".")
            game.playerX = 1
            game.playerY = 1
            game.facing = DIR_LEFT
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Left)))
            @Expect(game.status, "blocked")
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'1'))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'2'))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'3'))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'4'))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'['))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r']'))))
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
            _ = game.update(Event.KeyUp(KeyEvent(KeyCode.Char(r'x'))))
            _ = game.update(Event.FocusIn)
            game.energy = 0
            game.playerX = 4
            game.playerY = 6
            game.facing = DIR_RIGHT
            game.selectedTool = TOOL_HOE
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Expect(game.status, "too tired: save or sleep")

            game.energy = MAX_ENERGY
            game.plots[0].tilled = true
            game.plots[0].crop = CROP_TURNIP
            game.plots[0].growth = cropDays(CROP_TURNIP)
            game.plots[0].watered = true
            game.inventory[CROP_TURNIP] = 0
            game.playerX = 3
            game.playerY = 6
            game.facing = DIR_RIGHT
            game.selectedTool = TOOL_HARVEST
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Expect(game.inventory[CROP_TURNIP], 1)
            game.playerX = 24
            game.playerY = 3
            game.facing = DIR_RIGHT
            game.money = 0
            _ = game.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
            @Assert(game.status.contains("need"))
            _ = game.update(Event.Tick(TickEvent(frameIndex: 24, deltaMillis: -1)))
            game.minute = DAY_END - 1
            _ = game.update(Event.Tick(TickEvent(frameIndex: 32, deltaMillis: 1000)))

            let smallBuffer = Buffer(Rect(0, 0, 80, 20))
            FarmScene(game).render(smallBuffer.area, smallBuffer)
            @Expect(smallBuffer.getCell(0, 0).symbol, "t")
            let fullBackend = TestBackend(area: Rect(0, 0, VIEW_W, VIEW_H))
            let terminal = Terminal(fullBackend, renderMode: RenderMode.Full)
            let scene = FarmScene(game)
            _ = terminal.draw { frame => scene.renderFrame(frame, frame.area) }
            @Assert(fullBackend.snapshot().contains("MEADOW"))
            let tinyBackend = TestBackend(area: Rect(0, 0, 80, 20))
            let tinyTerminal = Terminal(tinyBackend, renderMode: RenderMode.Full)
            _ = tinyTerminal.draw { frame => scene.renderFrame(frame, frame.area) }
            @Assert(tinyBackend.snapshot().contains("terminal too small"))
        } finally {
            remove(directory, recursive: true)
        }
    }
}

func renderedFarmText(game: FarmGame): String {
    let buffer = Buffer(Rect(0, 0, 184, 51))
    FarmScene(game).render(buffer.area, buffer)
    var text = ""
    for (y in 0..buffer.area.height) {
        for (x in 0..buffer.area.width) { text += buffer.getCell(x, y).symbol }
        text += "\n"
    }
    text
}
