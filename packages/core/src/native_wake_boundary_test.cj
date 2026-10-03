package core

import std.unittest.*
import std.unittest.testmacro.*

@When[os != "Windows"]
@Test
class NativeWakeBoundaryTest {
    @TestCase
    func externalWakeDescriptorIsNonblockingBeforeAnyDrain(): Unit {
        let port = ExternalPort<Int64>(capacity: 2)
        try {
            let fd = port.eventSource().fd().getOrThrow()
            // Assert the kernel flags before reading an empty pipe. A wrong
            // variadic FFI call can report successful F_SETFL without setting
            // O_NONBLOCK on Apple ARM64, which otherwise hangs this drain.
            let statusFlags = unsafe { fcntl(fd, F_GETFL, 0) }
            let descriptorFlags = unsafe { fcntl(fd, F_GETFD, 0) }
            @Assert(statusFlags >= 0)
            @Assert((statusFlags & O_NONBLOCK) != 0)
            @Assert(descriptorFlags >= 0)
            @Assert((descriptorFlags & FD_CLOEXEC) != 0)
            @Expect(port.drain().isEmpty())
            match (port.tryEnqueue(17)) {
                case ExternalEnqueueResult.Accepted => ()
                case _ => @Fail("wake source rejected an open empty port")
            }
            @Expect(port.drain(), [Int64(17)])
            @Expect(port.drain().isEmpty())
        } finally { port.close() }
    }

    @TestCase
    func idleAsyncRuntimeCanDrainAndCloseWithoutAnyProducer(): Unit {
        let runtime = AsyncRuntime()
        try {
            let fd = runtime.eventSource().fd().getOrThrow()
            let flags = unsafe { fcntl(fd, F_GETFL, 0) }
            @Assert(flags >= 0 && (flags & O_NONBLOCK) != 0)
            @Expect(runtime.pendingCount(), 0)
            @Expect(runtime.drain().isEmpty())
            @Expect(runtime.drain().isEmpty())
        } finally { runtime.cancelAll() }
        @Expect(runtime.eventSource().fd().isNone())
        @Expect(runtime.drain().isEmpty())
    }
}
