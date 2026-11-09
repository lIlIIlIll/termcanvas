package cjtui_api_example

import core.*

main(): Int64 {
    let backend = TestBackend()
    let driver: TerminalDriver = FallbackTerminalDriver(area: Rect(0, 0, 80, 24))
    if (driver.name() != "fallback" || driver.enterRawMode() || driver.size().isNone()) { throw IllegalStateException("fallback driver failed") }
    if (driver.capabilities(backend).driverName != "fallback") { throw IllegalStateException("driver capabilities failed") }
    driver.restore()
    if (defaultTerminalDriver().name().isEmpty() || MacOSTerminalDriver().name().isEmpty() || WindowsTerminalDriver().name().isEmpty()) {
        throw IllegalStateException("driver name failed")
    }
    return 0
}
