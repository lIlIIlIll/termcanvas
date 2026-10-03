package cjtui_native_terminal_probe

@FastNative
@When[os == "Windows"]
foreign func GetStdHandle(which: Int32): CPointer<Unit>

@FastNative
@When[os == "Windows"]
foreign func GetConsoleMode(handle: CPointer<Unit>, mode: CPointer<UInt32>): Int32

@FastNative
@When[os == "Windows"]
foreign func GetConsoleCursorInfo(handle: CPointer<Unit>, info: CPointer<UInt32>): Int32

@When[os == "Windows"]
func consoleMode(which: Int32): UInt32 {
    let mode = Array<UInt32>(1, repeat: 0u32)
    unsafe {
        let raw = acquireArrayRawData(mode)
        let result = GetConsoleMode(GetStdHandle(which), CPointer<UInt32>(raw.pointer))
        releaseArrayRawData(raw)
        if (result == 0) { throw Exception("probe GetConsoleMode failed") }
    }
    mode[0]
}

@When[os == "Windows"]
func consoleCursor(): Array<UInt32> {
    // CONSOLE_CURSOR_INFO is DWORD size followed by BOOL visible (both 32 bit).
    let info = Array<UInt32>(2, repeat: 0u32)
    unsafe {
        let raw = acquireArrayRawData(info)
        let result = GetConsoleCursorInfo(GetStdHandle(-11), CPointer<UInt32>(raw.pointer))
        releaseArrayRawData(raw)
        if (result == 0) { throw Exception("probe GetConsoleCursorInfo failed") }
    }
    info
}

@When[os == "Windows"]
func nativeConsoleRaw(): Bool {
    let input = consoleMode(-10)
    let output = consoleMode(-11)
    // LINE_INPUT and ECHO_INPUT disabled; VT input/output enabled.
    (input & 0x0006u32) == 0u32 && (input & 0x0200u32) != 0u32 && (output & 0x0004u32) != 0u32
}

@When[os == "Windows"]
class NativeConsoleSnapshot {
    let input: UInt32
    let output: UInt32
    let cursor: Array<UInt32>
    init() {
        input = consoleMode(-10)
        output = consoleMode(-11)
        cursor = consoleCursor()
    }
    func assertRestored(observation: NativeObservation): Unit {
        let afterCursor = consoleCursor()
        if (input != consoleMode(-10) || output != consoleMode(-11) ||
            cursor[0] != afterCursor[0] || cursor[1] != afterCursor[1]) {
            throw Exception("probe Windows console modes or cursor state were not restored")
        }
        observation.mark("NATIVE_CONSOLE_RESTORED")
    }
}

@When[os != "Windows"]
func nativeConsoleRaw(): Bool { false }

@When[os != "Windows"]
class NativeConsoleSnapshot {
    func assertRestored(_: NativeObservation): Unit {}
}
