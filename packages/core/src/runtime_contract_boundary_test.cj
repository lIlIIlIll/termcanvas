package core

import std.time.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class RuntimeContractBoundaryTest {
    @TestCase
    func gracefulQueueCloseRetainsAcceptedWorkAndRejectsAllFurtherAdmissions(): Unit {
        let queue = RuntimeQueue<Int64>(capacity: 600)
        @Expect(queue.capacity(), 600)
        for (i in 0..600) { @Expect(queue.enqueueExternal(i), Some(i + 1)) }
        // This crosses compaction while both consumed and pending ranges exist.
        for (i in 0..301) {
            let entry = queue.dequeue().getOrThrow()
            @Expect(entry.sequence, i + 1)
            match (entry.envelope) { case RuntimeEnvelope<Int64>.ExternalItem(value) => @Expect(value, i); case _ => @Expect(false) }
        }
        @Expect(queue.size(), 299)
        queue.beginClosing(); queue.beginClosing()
        @Expect(queue.enqueueExternal(700).isNone())
        @Expect(queue.enqueueEvent(Event.Message("closed")).isNone())
        @Expect(queue.enqueueQuit().isNone())
        queue.close(discardPending: false)
        for (i in 301..600) {
            match (queue.dequeue().getOrThrow().envelope) { case RuntimeEnvelope<Int64>.ExternalItem(value) => @Expect(value, i); case _ => @Expect(false) }
        }
        @Expect(queue.dequeue().isNone())
        queue.close(); queue.close()
        @Expect(queue.size(), 0)
        @Expect(queue.maxQueueDepth(), 600)
        var invalidCapacity = false
        try { _ = RuntimeQueue<Unit>(capacity: 0) } catch (_: IllegalArgumentException) { invalidCapacity = true }
        @Expect(invalidCapacity)
        var underflow = false
        try { queue.leaveUpdate() } catch (_: IllegalStateException) { underflow = true }
        @Expect(underflow)
    }

    @TestCase
    func ownershipRejectsUnknownOperationsWithoutSettlingValidOnes(): Unit {
        let runtime = AsyncOwnershipRuntime()
        let owner = runtime.acquireOwner(0)
        @Expect(runtime.start(OwnerToken(20, 1)).isNone())
        @Expect(!runtime.requestCancel(OperationId(99)))
        match (runtime.complete(OwnedAsyncCompletion(owner, OperationId(99), Event.Message("unknown")))) {
            case CompletionDisposition.Orphan => (); case _ => @Expect(false)
        }
        let operation = runtime.start(owner).getOrThrow()
        @Expect(runtime.requestCancel(operation))
        @Expect(!runtime.requestCancel(operation))
        match (runtime.complete(OwnedAsyncCompletion(owner, operation, Event.Message("done")))) {
            case CompletionDisposition.Applied => (); case _ => @Expect(false)
        }
        @Expect(!runtime.requestCancel(operation))
        @Expect(runtime.releaseOwner(owner))
        @Expect(!runtime.releaseOwner(owner))
        @Expect(runtime.orphanCompletions(), 1)
    }

    @TestCase
    func emptyAndPartialExternalDrainsPreserveTimestampsAndWakeUntilConsumed(): Unit {
        let port = ExternalPort<Int64>(capacity: 3)
        try {
            port.enableLatencyMeasurement()
            @Expect(port.capacity(), 3)
            match (port.tryEnqueue(1)) { case ExternalEnqueueResult.Accepted => (); case _ => @Expect(false) }
            match (port.tryEnqueue(2)) { case ExternalEnqueueResult.Accepted => (); case _ => @Expect(false) }
            @Expect(port.drainEntries(maxEntries: -1).size, 0)
            @Expect(port.size(), 2)
            let one = port.drainEntries(maxEntries: 1)
            @Assert(one.size, 1)
            @Expect(one[0].action, 1)
            @Expect(one[0].acceptedAt.isSome())
            @Expect(port.size(), 1)
            let rest = port.drainEntries(maxEntries: 3)
            @Assert(rest.size, 1)
            @Expect(rest[0].action, 2)
            @Expect(rest[0].acceptedAt.isSome())
            @Expect(port.drainEntries().size, 0)
            @Expect(port.wakeSignals(), 1)
            @Expect(port.wakeCoalesced(), 1)
            port.beginClosing(); port.beginClosing()
            match (port.tryEnqueue(3)) { case ExternalEnqueueResult.Closed => (); case _ => @Expect(false) }
            @Expect(port.closedCount(), 1)
        } finally { port.close(); port.close() }
    }

    @TestCase
    func lostWakeEndpointRollsBackAdmissionAndTransitionsToClosing(): Unit {
        let port = ExternalPort<Int64>(capacity: 1)
        try {
            let source = port.eventSource()
            @Expect(source.id(), "runtime-external-wake")
            match (source.interests()) { case EventSourceInterest.Read => (); case _ => @Expect(false) }
            @Expect(source.drain().isEmpty())
            source.onReady(false, true, false, false)
            source.onReady(true, true, false, false)
            source.onReady(false, true, true, false)
            source.onReady(false, true, false, true)
            source.close(); source.close()
            @Expect(source.fd().isNone())
            match (port.tryEnqueue(42)) { case ExternalEnqueueResult.Closed => (); case _ => @Expect(false) }
            @Expect(port.size(), 0)
            @Expect(port.acceptedCount(), 0)
            @Expect(port.closedCount(), 1)
            @Expect(port.wakeSignals(), 0)
            match (port.state()) { case RuntimeState.Closing => (); case _ => @Expect(false) }
            @Expect(port.drainEntries().isEmpty())
        } finally { port.close() }
    }

    @TestCase
    func frameDeadlinesRejectEarlyPresentationAndPromoteResizeOnlyOnce(): Unit {
        let clock = TestClock()
        let scheduler = FrameCoalescingState(10, clock: clock)
        var rejected = 0
        try { _ = scheduler.presented(0, 0) } catch (_: IllegalStateException) { rejected++ }
        scheduler.request(FrameRequestKind.Background)
        _ = scheduler.presented(1, 1)
        scheduler.request(FrameRequestKind.Background)
        @Expect(scheduler.nextWakeMillis(), Some(Int64(10)))
        try { _ = scheduler.presented(0, 0) } catch (_: IllegalStateException) { rejected++ }
        @Expect(rejected, 2)
        clock.advance(Duration.millisecond * 2)
        scheduler.request(FrameRequestKind.SurfaceCritical)
        scheduler.request(FrameRequestKind.SurfaceCritical)
        @Expect(scheduler.readyToPresent())
        @Expect(scheduler.nextWakeMillis().isNone())
        let resized = scheduler.presented(3, 1)
        @Expect(resized.reason, "resize")
        @Expect(resized.pendingFramePromotions, 1)
        @Expect(resized.resizeFrameRequests, 2)
        scheduler.request(FrameRequestKind.Background)
        clock.advance(Duration.millisecond * 10)
        @Expect(scheduler.readyToPresent())
        @Expect(scheduler.readyToPresent())
        let deadline = scheduler.presented(1, 0)
        @Expect(deadline.frameDeadlineWakes, 1)
        @Expect(deadline.frameDelayDueToCoalescingMillis, 10)
        scheduler.request(FrameRequestKind.Interactive)
        scheduler.request(FrameRequestKind.Interactive)
        @Expect(scheduler.presented(2, 0).pendingFramePromotions, 1)
        scheduler.discard()
        @Expect(!scheduler.readyToPresent())
        @Expect(scheduler.nextWakeMillis().isNone())
    }
}
