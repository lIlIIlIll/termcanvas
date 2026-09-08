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
