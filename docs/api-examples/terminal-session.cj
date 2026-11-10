package cjtui_api_example

import core.*

class EmptyInput <: InputSource {
    public func readAvailable(maxBytes: Int64): Array<Byte> { [] }
}

main(): Int64 {
    let backend = TestBackend()
    let options = KeyboardOptions(mode: KeyboardProtocolMode.Basic, probe: TerminalProbeMode.Disabled)
    let probe = TerminalProbe.run(backend, EmptyInput(), base: TerminalCapabilities(), budgetMillis: 0)
    if (probe.consumedBytes.size != 0 || probe.budgetMillis != 0) { throw IllegalStateException("probe failed") }
    let session = TerminalSession(backend, driver: FallbackTerminalDriver(), rawMode: false,
        alternateScreen: false, bracketedPaste: false, hideCursor: false, keyboard: options)
    if (!session.start() || session.rawModeEnabled || session.probeResult().isSome()) { throw IllegalStateException("session start failed") }
    session.stop()
    return 0
}
