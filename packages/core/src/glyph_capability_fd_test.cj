package core

import std.unittest.*
import std.unittest.testmacro.*

@When[os != "Windows"]
@Test
class GlyphCapabilityFdTest {
    @TestCase
    func closeReleasesUnattachedSessionWakeDescriptor(): Unit {
        let glyphs = GlyphCapabilitySession()
        let fd = glyphs.eventSource().fd().getOrThrow()
        @Expect(unsafe { fcntl(fd, F_GETFD, 0) } >= 0)
        glyphs.close()
        @Expect(unsafe { fcntl(fd, F_GETFD, 0) }, -1)
        glyphs.close()
    }
}
