package core

import std.collection.*
import std.sync.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

private class GlyphNoInput <: InputSource {
    public func readAvailable(_: Int64): Array<Byte> { [] }
}

private class GlyphBufferedInput <: InputSource {
    private var sent = false
    public func readAvailable(_: Int64): Array<Byte> {
        if (sent) { return [] }
        sent = true
        [b'x', b'q']
    }
}

private class GlyphGatedProvider <: GlyphCapabilityProvider {
    let gate = Semaphore(1)
    let started = Semaphore(1)
    let finished = Semaphore(1)
    init() { gate.acquire(); started.acquire(); finished.acquire() }
    public func probe(_: Int64): GlyphCapability {
        started.release()
        gate.acquire()
        finished.release()
        GlyphCapability.VerifiedSupported
    }
}

private class GlyphSequenceProvider <: GlyphCapabilityProvider {
    private var calls: Int64 = 0
    public func probe(_: Int64): GlyphCapability {
        calls++
        if (calls == 1) { GlyphCapability.Unsupported } else { GlyphCapability.VerifiedSupported }
    }
}

private class GlyphRetryState {
    var requested = false
    var verified = false
}

private func glyphCode(value: IconSet): Int64 {
    match (value) { case IconSet.Unicode => 0; case IconSet.NerdFont => 1; case IconSet.Ascii => 2 }
}

private func glyphTestApp(): App {
    App(
        backend: TestBackend(area: Rect(0, 0, 4, 1)),
        inputSource: GlyphNoInput(),
        terminalDriver: FallbackTerminalDriver(area: Rect(0, 0, 4, 1)),
        probeInputSource: GlyphNoInput(),
        rawMode: false, alternateScreen: false, bracketedPaste: false,
        hideCursor: false, resize: false
    )
}

@Test
class GlyphCapabilityTest {
    @TestCase
    func unknownDefaultsToUnicodeAndThemeUsesExplicitOverrides(): Unit {
        let glyphs = GlyphCapabilitySession()
        @Expect(glyphCode(glyphs.iconSet()), 0)
        @Expect(glyphCode(glyphs.applyTo(Theme()).iconSet), 0)
        glyphs.setOverride(Some(IconSet.Ascii))
        @Expect(glyphCode(glyphs.applyTo(Theme()).iconSet), 2)
        glyphs.setOverride(Some(IconSet.NerdFont))
        @Expect(glyphCode(glyphs.iconSet()), 1)
        glyphs.setOverride(Option<IconSet>.None)
        @Expect(glyphCode(glyphs.iconSet()), 0)
        glyphs.close()
    }

    @TestCase
    func backgroundResultUpdatesAppAndStaleResultCannotReplaceOverride(): Unit {
        let provider = GlyphGatedProvider()
        let glyphs = GlyphCapabilitySession(provider: provider, timeoutMillis: 10000)
        let app = glyphTestApp()
        let port = ExternalPort<Event>()
        let applied = Semaphore(1)
        let checked = Semaphore(1)
        applied.acquire()
        checked.acquire()
        let seen = ArrayList<Int64>()
        let duringSecondProbe = ArrayList<Int64>()
        app.attachGlyphCapabilitySession(glyphs)
        let producer = spawn {
            provider.started.acquire()
            _ = port.tryEnqueue(Event.Message("override"))
            applied.acquire()
            provider.gate.release()
            provider.finished.acquire()
            _ = port.tryEnqueue(Event.Message("auto"))
            provider.started.acquire()
            _ = port.tryEnqueue(Event.Message("check"))
            checked.acquire()
            provider.gate.release()
        }
        app.runWithExternalPort(port, { _ =>
            let icon = glyphCode(glyphs.applyTo(Theme()).iconSet)
            seen.add(icon)
            // Hold the old probe until the explicit override has actually
            // been presented. Background invalidations may coalesce.
            if (icon == 2) { applied.release() }
            if (icon == 1) { _ = port.tryEnqueue(Event.Message("exit")) }
        }, { event =>
            match (event) {
                case Event.Message("override") =>
                    glyphs.setOverride(Some(IconSet.Ascii))
                    UpdateResult.unchanged()
                case Event.Message("auto") =>
                    glyphs.setOverride(Option<IconSet>.None)
                    UpdateResult.unchanged()
                case Event.Message("check") =>
                    duringSecondProbe.add(glyphCode(glyphs.iconSet()))
                    checked.release()
                    UpdateResult.unchanged()
                case Event.Message("exit") => UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
        })
        producer.get()
        @Expect(duringSecondProbe.size, 1)
        @Expect(duringSecondProbe[0], 0)
        @Expect(seen.contains(2))
        @Expect(seen.contains(1))
    }

    @TestCase
    func manualReprobeAfterUnsupportedCanUseFreshVerifiedResult(): Unit {
        let glyphs = GlyphCapabilitySession(provider: GlyphSequenceProvider(), timeoutMillis: 10000)
        let app = glyphTestApp()
        let port = ExternalPort<Event>()
        let state = GlyphRetryState()
        app.attachGlyphCapabilitySession(glyphs)
        app.runWithExternalPort(port, {_ =>
            match (glyphs.detected()) {
                case GlyphCapability.Unsupported =>
                    if (!state.requested) { state.requested = true; glyphs.requestProbe() }
                case GlyphCapability.VerifiedSupported =>
                    state.verified = glyphCode(glyphs.iconSet()) == 1
                    _ = port.tryEnqueue(Event.Message("exit"))
                case GlyphCapability.Unknown => ()
            }
        }, {event =>
            match (event) { case Event.Message("exit") => UpdateResult.exit(); case _ => UpdateResult.unchanged() }
        })
        @Expect(state.requested)
        @Expect(state.verified)
    }

    @TestCase
    func timeoutAndRepeatedRequestsDoNotBlockExitOrStartMoreWorkers(): Unit {
        let provider = GlyphGatedProvider()
        let glyphs = GlyphCapabilitySession(provider: provider, timeoutMillis: 5)
        let app = glyphTestApp()
        let port = ExternalPort<Event>()
        let observed = ArrayList<Int64>()
        let retries = ArrayList<Int64>()
        app.attachGlyphCapabilitySession(glyphs)
        let producer = spawn {
            provider.started.acquire()
            for (_ in 0..20) { _ = port.tryEnqueue(Event.Message("retry")) }
            sleep(Duration.millisecond * 30)
            _ = port.tryEnqueue(Event.Message("exit"))
        }
        app.runWithExternalPort(port, {_ =>}, {event =>
            match (event) {
                case Event.Message("retry") =>
                    glyphs.requestProbe()
                    retries.add(1)
                    UpdateResult.unchanged()
                case Event.Message("exit") =>
                    observed.add(glyphCode(glyphs.iconSet()))
                    UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
        })
        producer.get()
        @Expect(retries.size, 20)
        @Expect(observed[0], 0)
        @Expect(!provider.started.tryAcquire())
        provider.gate.release()
    }

    @TestCase
    func resultArrivingAfterDeadlineCannotEnableIcons(): Unit {
        let provider = GlyphGatedProvider()
        let clock = TestClock()
        let glyphs = GlyphCapabilitySession(provider: provider, timeoutMillis: 100, clock: clock)
        let app = glyphTestApp()
        let port = ExternalPort<Event>()
        let advanced = Semaphore(1)
        advanced.acquire()
        let seen = ArrayList<Int64>()
        app.attachGlyphCapabilitySession(glyphs)
        let producer = spawn {
            provider.started.acquire()
            _ = port.tryEnqueue(Event.Message("advance"))
            advanced.acquire()
            provider.gate.release()
            provider.finished.acquire()
            sleep(Duration.millisecond * 40)
            _ = port.tryEnqueue(Event.Message("exit"))
        }
        app.runWithExternalPort(port, {_ => seen.add(glyphCode(glyphs.iconSet()))}, {event =>
            match (event) {
                case Event.Message("advance") =>
                    clock.advanceMillis(101)
                    advanced.release()
                    UpdateResult.unchanged()
                case Event.Message("exit") =>
                    seen.add(glyphCode(glyphs.iconSet()))
                    UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
        })
        producer.get()
        @Expect(!seen.contains(1))
    }

    @TestCase
    func providerDoesNotConsumeApplicationInput(): Unit {
        let glyphs = GlyphCapabilitySession()
        let input = GlyphBufferedInput()
        let app = App(
            backend: TestBackend(area: Rect(0, 0, 4, 1)), inputSource: input,
            terminalDriver: FallbackTerminalDriver(area: Rect(0, 0, 4, 1)),
            probeInputSource: GlyphNoInput(), rawMode: false, alternateScreen: false,
            bracketedPaste: false, hideCursor: false, resize: false
        )
        let keys = ArrayList<String>()
        app.attachGlyphCapabilitySession(glyphs)
        app.runWithCommands({_ =>}, {event =>
            match (event) {
                case Event.KeyDown(key) => match (key.code) {
                    case KeyCode.Char(r'x') => keys.add("x"); UpdateResult.unchanged()
                    case KeyCode.Char(r'q') => keys.add("q"); UpdateResult.exit()
                    case _ => UpdateResult.unchanged()
                }
                case _ => UpdateResult.unchanged()
            }
        })
        @Expect(keys.toArray(), ["x", "q"])
    }
    @TestCase
    func closeBeforeRunIsIdempotentAndDisablesFurtherRequests(): Unit {
        let glyphs = GlyphCapabilitySession()
        glyphs.setOverride(Some(IconSet.Ascii))
        let app = glyphTestApp()
        app.attachGlyphCapabilitySession(glyphs)
        glyphs.close()
        glyphs.close()
        glyphs.setOverride(Some(IconSet.NerdFont))
        glyphs.requestProbe()
        @Expect(glyphCode(glyphs.iconSet()), 2)
        let port = ExternalPort<Event>()
        _ = port.tryEnqueue(Event.Message("exit"))
        app.runWithExternalPort(port, {_ =>}, {event =>
            match (event) { case Event.Message("exit") => UpdateResult.exit(); case _ => UpdateResult.unchanged() }
        })
        @Expect(glyphCode(glyphs.iconSet()), 2)
        let other = glyphTestApp()
        @ExpectThrows[Exception](other.attachGlyphCapabilitySession(glyphs))
    }

}
