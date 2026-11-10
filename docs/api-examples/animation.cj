package cjtui_api_example

import core.*

main(): Int64 {
    let clock = TestClock()
    let config = AnimationConfig(durationMillis: 1000, framesPerSecond: 20, enabled: true)
    let scheduler = AnimationScheduler(clock: clock, maxFramesPerSecond: 20)
    if (!config.enabled || config.durationMillis != 1000 || config.framesPerSecond != 20 ||
        !scheduler.register("screen", "spinner", config: config, group: Some("sync"))) {
        throw IllegalStateException("animation registration failed")
    }
    clock.advanceMillis(250)
    let sample = scheduler.sample("screen", "spinner").getOrThrow()
    let direct = AnimationSample(1250, 1000)
    if (sample.elapsedMillis != 250 || sample.cycleMillis != 250 || sample.durationMillis != 1000 ||
        direct.cycleMillis != 250) { throw IllegalStateException("incorrect animation sample") }
    scheduler.framePresented()
    if (scheduler.nextTimeoutMillis().getOrThrow() != 50 ||
        !scheduler.setConfig("screen", "spinner", config) ||
        !scheduler.setVisible("screen", "spinner", false) || !scheduler.nextTimeoutMillis().isNone()) {
        throw IllegalStateException("incorrect animation scheduling")
    }
    if (!scheduler.remove("screen", "spinner") || !scheduler.register("other", "spinner")) {
        throw IllegalStateException("animation cleanup failed")
    }
    scheduler.removeScope("other")
    if (!scheduler.sample("other", "spinner").isNone()) { throw IllegalStateException("scope was not removed") }
    return 0
}
