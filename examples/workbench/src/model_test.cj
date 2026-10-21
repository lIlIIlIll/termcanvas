package cjtui_workbench

import std.unittest.*
import std.unittest.testmacro.*

@Test
class WorkbenchModelTest {
    @TestCase
    func progressUsesElapsedMillisecondsAndCompletesOnce(): Unit {
        let first = WorkbenchModel()
        let second = WorkbenchModel()
        _ = first.advance(1000)
        for (_ in 0..10) { _ = second.advance(100) }

        @Expect(first.job(1).getOrThrow().elapsedMillis, 1000)
        @Expect(second.job(1).getOrThrow().elapsedMillis, 1000)
        @Expect(first.job(1).getOrThrow().progressPercent, 16)
        @Expect(first.queuedCount, 119)
        @Expect(first.runningCount, 1)
        @Expect(first.doneCount, 0)

        _ = first.advance(4999)
        @Expect(first.job(1).getOrThrow().status, WorkbenchJobStatus.Running)
        _ = first.advance(1)
        @Expect(first.job(1).getOrThrow().status, WorkbenchJobStatus.Done)
        @Expect(first.job(1).getOrThrow().progressPercent, 100)
        @Expect(first.completedIds.size, 1)
        @Expect(first.completedIds[0], 1)
        _ = first.advance(100)
        @Expect(first.completedIds.isEmpty())
        @Expect(first.queuedCount, 119)
        @Expect(first.runningCount, 0)
        @Expect(first.doneCount, 1)
    }

    @TestCase
    func startLimitResetAndInvalidIdsPreserveModelState(): Unit {
        let model = WorkbenchModel()
        @Expect(!model.start(0))
        @Expect(!model.start(121))
        @Expect(!model.start(1))
        @Expect(model.start(2))
        @Expect(model.start(3))
        @Expect(model.start(4))
        @Expect(!model.start(5))
        @Expect(!model.start(2))
        @Expect(model.reset(2))
        @Expect(!model.reset(2))
        @Expect(model.start(5))
        @Expect(model.queuedCount, 116)
        @Expect(model.runningCount, 4)
        @Expect(model.doneCount, 0)
    }

    @TestCase
    func queryAndSortKeepNumericIdsAndUnicodeNames(): Unit {
        let model = WorkbenchModel()
        @Expect(model.setMetadata(2, "构建 Job", "High", true, ["build"], ""))
        let noProject: ?String = None
        let noStatus: ?WorkbenchJobStatus = None
        @Expect(model.setQuery("构建", noProject, noStatus))
        @Expect(model.visibleIds().size, 1)
        @Expect(model.visibleIds()[0], 2)
        @Expect(model.sortBy(1, descending: true))
        @Expect(model.visibleIds()[0], 2)
        @Expect(model.setQuery("not found", noProject, noStatus))
        @Expect(model.visibleIds().isEmpty())
        @Expect(model.queuedCount, 119)
        @Expect(model.runningCount, 1)
        @Expect(model.doneCount, 0)
    }

    @TestCase
    func boundedLogsAndHistoryRetainNewestValues(): Unit {
        let model = WorkbenchModel()
        for (i in 0..205) { model.recordLog("entry-${i}") }
        for (i in 0..70) { model.sampleHistory(i) }
        let logs = model.logs()
        let history = model.history()
        @Expect(logs.size, 200)
        @Expect(logs[0], "entry-5")
        @Expect(logs[199], "entry-204")
        @Expect(history.size, 60)
        @Expect(history[0], 10)
        @Expect(history[59], 69)
    }
}
