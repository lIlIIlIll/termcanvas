package cjtui_api_example

import core.*

main(): Int64 {
    let metrics = AppMetrics(maxFrames: Some(2))
    metrics.record(FrameMetrics(frameIndex: 1, fps: 10, droppedTicks: 2, terminalSize: Rect(0, 0, 80, 24)))
    metrics.record(FrameMetrics(frameIndex: 2, fps: 30))
    metrics.record(FrameMetrics(frameIndex: 3, fps: 20, droppedTicks: 1))
    let frames = metrics.frames()
    if (frames.size != 2 || frames[0].frameIndex != 2 || metrics.lastFrame().getOrThrow().frameIndex != 3 ||
        metrics.averageFps() != 25 || metrics.droppedTicks() != 1 || metrics.runtime().queueProcessed != 0) {
        throw IllegalStateException("frame metrics failed")
    }
    let render = RenderMetrics(size: Rect(0, 0, 10, 2), dirtyCells: 4)
    metrics.record(render, frameIndex: 4, tickDeltaMillis: 50)
    if (metrics.lastFrame().getOrThrow().fps != 20 || metrics.lastFrame().getOrThrow().dirtyCells != 4) {
        throw IllegalStateException("render metrics failed")
    }
    let runtime = RuntimeMetricsSnapshot(queueEnqueued: -1, queueProcessed: 2)
    if (runtime.queueEnqueued != 0 || runtime.queueProcessed != 2) { throw IllegalStateException("runtime snapshot failed") }
    metrics.reset()
    if (metrics.lastFrame().isSome()) { throw IllegalStateException("metrics reset failed") }
    return 0
}
