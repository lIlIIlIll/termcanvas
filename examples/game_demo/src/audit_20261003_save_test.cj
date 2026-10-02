package game_demo

import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003SaveVersionTest {
    @TestCase
    func unrecognizedSaveFilesArePreserved(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/farm.save"
        try {
            for (original in ["unrelated UTF-8 text\n", "version=2\nday=123\n", "day=123\n", "version=1\nversion=2\nday=123\n"]) {
                File.writeTo(path, original.toArray())
                let game = FarmGame(path, false)
                @Expect(!game.saveLoaded)
                @Expect(!game.saveAllowed)
                game.save()
                @Expect(String.fromUtf8(File.readFrom(path)), original)
            }
        } finally {
            remove(directory, recursive: true)
        }
    }
}
