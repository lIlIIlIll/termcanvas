package core

import std.unittest.*
import std.unittest.testmacro.*

private class PresentationInput <: InputSource {
    let clock: TestClock
    var frames: Int64 = 0
    var sent = false
    init(clock: TestClock) { this.clock = clock }
    public func readAvailable(_: Int64): Array<Byte> {
        if (frames >= 2) { return [b'q'] }
        if (frames == 1 && !sent) {
            sent = true
            clock.advanceMillis(90)
            return [b'x']
        }
        []
    }
}

@Test
class AnimationPresentationTest {
    @TestCase
    func fullEventFrameResetsAnimationDeadline(): Unit {
        let clock = TestClock()
        let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 10)
        @Assert(scheduler.register("app", "activity", config: AnimationConfig(framesPerSecond: 10)))
        let input = PresentationInput(clock)
        let app = App(backend: TestBackend(area: Rect(0, 0, 4, 1)), inputSource: input,
            terminalDriver: FallbackTerminalDriver(area: Rect(0, 0, 4, 1)),
            probeInputSource: input, rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false)
        app.attachAnimationScheduler(scheduler)
        app.runWithCommands({ _ => input.frames++ }, { event =>
            match (event) {
                case Event.KeyDown(key) => match (key.code) {
                    case KeyCode.Char(r'q') => UpdateResult.exit()
                    case _ => UpdateResult.next()
                }
                case _ => UpdateResult.unchanged()
            }
        })
        @Expect(input.frames, 2)
        @Expect(scheduler.nextTimeoutMillis().getOrThrow(), 100)
    }
}
