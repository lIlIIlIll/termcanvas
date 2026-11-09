package cjtui_api_example

import core.*

main(): Int64 {
    let driver = LinuxTerminalDriver()
    if (driver.name() != "linux-glibc") { throw IllegalStateException("Linux driver failed") }
    _ = TerminalMode.lastError()
    return 0
}
