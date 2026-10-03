package core

import std.unittest.*
import std.unittest.testmacro.*

func consoleUnitText(decoder: ConsoleUtf16Decoder, unit: UInt32): String {
    unsafe { String.fromUtf8Unchecked(decoder.push(unit)) }
}

@Test
class ConsoleInputTest {
    @TestCase
    func unicodeConsoleUnitsPreserveSplitPairsAndRecoverMalformedInput(): Unit {
        let decoder = ConsoleUtf16Decoder()
        @Expect(consoleUnitText(decoder, 0x754Cu32), "界")
        @Expect(decoder.push(0xD83Du32).isEmpty())
        @Expect(consoleUnitText(decoder, 0xDE00u32), "😀")
        @Expect(decoder.push(0xD83Du32).isEmpty())
        @Expect(consoleUnitText(decoder, 0x61u32), "\u{FFFD}a")
        @Expect(consoleUnitText(decoder, 0xDE00u32), "\u{FFFD}")
        @Expect(decoder.push(0xD83Du32).isEmpty())
        @Expect(consoleUnitText(decoder, 0xD83Du32), "\u{FFFD}")
        @Expect(consoleUnitText(decoder, 0xDE00u32), "😀")
        @Expect(consoleUnitText(decoder, 0x1Bu32), "\u{1B}")
    }
}
