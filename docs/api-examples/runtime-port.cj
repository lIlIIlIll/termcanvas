package cjtui_api_example

import core.*

main(): Int64 {
    let port = ExternalPort<Int64>(capacity: 2)
    port.enableLatencyMeasurement()
    let one = port.tryEnqueue(1)
    let two = port.tryEnqueue(2)
    let overflow = port.tryEnqueue(3)
    match ((one, two, overflow)) {
        case (ExternalEnqueueResult.Accepted, ExternalEnqueueResult.Accepted, ExternalEnqueueResult.Full) => ()
        case _ => throw IllegalStateException("unexpected queue result")
    }
    if (port.capacity() != 2 || port.size() != 2 || port.acceptedCount() != 2 || port.fullCount() != 1 ||
        port.wakeSignals() != 1 || port.wakeCoalesced() != 1) { throw IllegalStateException("incorrect port counters") }
    port.close()
    match (port.tryEnqueue(4)) {
        case ExternalEnqueueResult.Closed => ()
        case _ => throw IllegalStateException("closed port accepted input")
    }
    if (port.closedCount() != 1 || port.size() != 0) { throw IllegalStateException("incorrect port close") }
    let frame = FrameSchedulingSnapshot(reason: "example", frameRequests: 3, framesPresented: 2,
        frameRequestsMerged: 1, frameDeadlineWakes: 1, pendingFramePromotions: 1,
        backgroundFrameRequests: 1, interactiveFrameRequests: 1, resizeFrameRequests: 1,
        updatesPerFrame: 2, dirtyRectsBeforeMerge: 3, dirtyRectsAfterMerge: 1,
        firstInvalidationToFrameMillis: 4, lastUpdateToFrameMillis: 2,
        frameDelayDueToCoalescingMillis: 4, framesAvoided: 1)
    if (frame.reason != "example" || frame.frameRequests != 3 || frame.framesPresented != 2 ||
        frame.frameRequestsMerged != 1 || frame.frameDeadlineWakes != 1 || frame.pendingFramePromotions != 1 ||
        frame.backgroundFrameRequests != 1 || frame.interactiveFrameRequests != 1 || frame.resizeFrameRequests != 1 ||
        frame.updatesPerFrame != 2 || frame.dirtyRectsBeforeMerge != 3 || frame.dirtyRectsAfterMerge != 1 ||
        frame.firstInvalidationToFrameMillis != 4 || frame.lastUpdateToFrameMillis != 2 ||
        frame.frameDelayDueToCoalescingMillis != 4 || frame.framesAvoided != 1) {
        throw IllegalStateException("incorrect frame snapshot")
    }
    return 0
}
