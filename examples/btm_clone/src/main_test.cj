package cjtui_btm_clone

import std.collection.*

import core.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class BtmCloneInputTest {
    @TestCase
    func searchBackspaceRemovesAWholeRune(): Unit {
        let app = BtmClone()
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'界'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Backspace)))

        let backend = TestBackend(area: Rect(0, 0, 100, 32))
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw({ frame => app.renderFrame(frame) })

        @Assert(backend.snapshot().contains("search: _"))
        @Assert(!backend.snapshot().contains("search: 界"))
    }

    @TestCase
    func staleBackgroundSampleDoesNotReplaceInteractiveFilter(): Unit {
        let app = BtmClone()
        var poll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
        if (!commandHasAsyncTask(poll.command)) {
            poll = app.update(Event.Timer(TimerEvent("proc", elapsedMillis: 1000)))
        }
        @Assert(commandHasAsyncTask(poll.command))

        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'界'))))
        let appliedBefore = app.appliedProcessRequestId()
        _ = runAsyncCommand(app, poll.command)

        @Expect(app.appliedProcessRequestId(), appliedBefore)
    }

    @TestCase
    func parserAndFormattingHelpersCoverTheirBoundaryContracts(): Unit {
        let history = HistoryRing(2)
        history.push(-5)
        history.push(150)
        history.push(50)
        @Expect(history.toArray(), [100, 50])
        @Expect(MemSnapshot(100, 50, 0, 1).percent(), 50)
        @Expect(MemSnapshot(100, 50, 200, 100).swapPercent(), 50)
        @Expect(NetSnapshot(1024 * 1024, 0).percent(), 1)
        @Expect(DiskSample("/", 5, 10).percent(), 50)

        let proc = ProcessSample(7, "worker", "worker --serve", "R", 1234, 567, 2048, 1024, 9, 11)
        let row = ProcessDisplayRow(proc, 8)
        @Expect(row.columns().size, 6)
        @Expect(row.command, "worker -")
        @Expect(percent2(-1), "0.00")
        @Expect(percent2(1234), "12.34")
        @Expect(twoDigits(4), "04")
        @Expect(twoDigits(14), "14")
        @Expect(bytesText(0), "0B")
        @Expect(bytesText(1024), "1K")
        @Expect(bytesText(1024 * 1024), "1M")
        @Expect(bytesText(1024 * 1024 * 1024), "1.0G")
        @Expect(rateText(1024), "1K/s")
        @Expect(percentOf(-1, 0), 0)
        @Expect(percentOf(200, 100), 100)
        for (i in 0..8) { _ = colorForIndex(i) }

        @Expect(words("  cpu\t  4\n"), ["cpu", "4"])
        @Expect(splitBy("a:b:", b':'), ["a", "b", ""])
        @Expect(trimAscii("\t hello \n"), "hello")
        @Expect(parseInt("-42x"), -42)
        @Expect(parseInt(""), 0)
        @Expect(parsePid("123"), 123)
        @Expect(parsePid(""), -1)
        @Expect(parsePid("1x"), -1)
        @Expect(indexOfByte("abc", b'b'), 1)
        @Expect(indexOfByte("abc", b'x'), -1)
        @Expect(lastIndexOfByte("abca", b'a'), 3)
        @Expect(lastIndexOfByte("abc", b'x'), -1)
        @Expect(replaceNulWithSpace("a\u{0}b"), "a b")
        @Expect(unescapeMount("a\\040b"), "a b")
        @Expect(unescapeMount("plain"), "plain")
        @Expect(isSpace(b' '), true)
        @Expect(isSpace(b'x'), false)
        @Expect(isDigit(b'7'), true)
        @Expect(isDigit(b'x'), false)
        @Expect(clampLocal(-1, 0, 10), 0)
        @Expect(clampLocal(20, 0, 10), 10)
        @Expect(repeatLocal("ab", 3), "ababab")
        @Expect(padLeft("x", 3), "  x")
        @Expect(padLeft("xxx", 2), "xxx")
        @Expect(truncateLocal("abc", 0), "")
        @Expect(truncateLocal("abc", 2), "ab")
        @Expect(truncateLocal("abc", 4), "abc")
        @Expect(intersectLocal(Rect(0, 0, 2, 2), Rect(3, 3, 2, 2)).width, 0)
        @Expect(intersectLocal(Rect(0, 0, 4, 4), Rect(2, 1, 4, 4)), Rect(2, 1, 2, 3))
    }

    @TestCase
    func parsingSortingAndDirtyHelpersCoverAllModes(): Unit {
        let counters = parseCpuLine("cpu 10 20 30 40 50")
        @Expect(counters.total, 150)
        @Expect(counters.idle, 90)
        @Expect(cpuUsage(CpuCounters(100, 20), CpuCounters(50, 10)), 80)
        @Expect(cpuUsage(CpuCounters(10, 10), CpuCounters(10, 10)), 0)
        match (parseProcStat("bad")) {
            case None => ()
            case Some(_) => @Expect(false)
        }
        let stat = "42 (worker) S 0 0 0 0 0 0 0 0 0 0 11 13 0 0 0 0 0 0 17 4096 3"
        match (parseProcStat(stat)) {
            case Some(value) =>
                @Expect(value.name, "worker")
                @Expect(value.cpuTotal, 24)
                @Expect(value.rssBytes, 3 * PAGE_BYTES)
            case None => @Expect(false)
        }
        @Expect(fsTypeFromMountInfo(["a", "b", "-", "ext4"]), "ext4")
        @Expect(fsTypeFromMountInfo(["a", "b"]), "")
        @Expect(interestingMount("/", "rootfs"))
        @Expect(!interestingMount("/proc", "proc"))
        @Expect(!interestingMount("/mnt", "tmpfs"))
        @Expect(interestingMount("/mnt", "ext4"))

        let rows = ArrayList<ProcessSample>()
        rows.add(ProcessSample(2, "z", "z", "S", 10, 1, 0, 20, 0, 0))
        rows.add(ProcessSample(1, "a", "a", "S", 20, 1, 0, 10, 0, 0))
        for (mode in [SortMode.Cpu, SortMode.Memory, SortMode.Pid, SortMode.Name]) {
            sortProcesses(rows, mode)
        }
        let disks = ArrayList<DiskSample>()
        disks.add(DiskSample("/"))
        @Expect(containsDisk(disks, "/"))
        @Expect(!containsDisk(disks, "/home"))

        @Expect(dirtyRectCount(UpdateResult.dirty(Rect(1, 2, 3, 4))), 1)
        @Expect(dirtyRectCount(UpdateResult.next()), -1)
        @Expect(dirtyRectText(UpdateResult.next()), "none")
        @Expect(dirtyRectText(UpdateResult.dirty(Rect(1, 2, 3, 4))), "1,2,3,4")
        let dirty = DirtyRects()
        addProcessRowDirty(dirty, Rect(0, 0, 20, 4), 1, 0)
        addProcessRowDirty(dirty, Rect(0, 0, 20, 4), 9, 0)
        @Expect(dirty.rects().size, 1)

        let buffer = Buffer(Rect(0, 0, 30, 8))
        writeAsciiOrText(buffer, 0, 0, "ascii", Style())
        writeAsciiOrText(buffer, 0, 1, "界", Style())
        let canvas = Canvas(buffer, buffer.area)
        drawGraph(canvas, Rect(0, 2, 20, 5), [], 100, CYAN, "CPU", "%")
        drawGraph(canvas, Rect(0, 2, 20, 5), [0, 50, 100], 100, CYAN, "CPU", "%")
        drawGraph(canvas, Rect(0, 0, 3, 2), [1], 100, CYAN, "CPU", "%")
        drawDisk(canvas, 0, 0, 40, 150, "/", RED)
        drawMeter(buffer, 0, 6, 10, -1, RED, "disk")
        @Expect(buffer.getCell(0, 1).symbol, "界")
    }

    @TestCase
    func applicationKeysAsyncUpdatesAndBothRenderSurfacesStayCovered(): Unit {
        let app = BtmClone()
        @Expect(app.panelUpdateCount("missing"), -1)
        @Expect(app.panelRenderCount("missing"), -1)

        let capabilities = app.update(Event.Capabilities(TerminalCapabilities()))
        match (capabilities.command) {
            case Command.Batch(items) => @Expect(items.size, 5)
            case _ => @Expect(false)
        }
        for (key in [
            KeyCode.Char(r'c'), KeyCode.Char(r'm'), KeyCode.Char(r'p'), KeyCode.Char(r'n'),
            KeyCode.Char(r' '), KeyCode.Char(r'd'), KeyCode.Char(r'+'), KeyCode.Char(r'='),
            KeyCode.Char(r'-'), KeyCode.Char(r'_'), KeyCode.Down, KeyCode.Up,
            KeyCode.Char(r'j'), KeyCode.Char(r'k'), KeyCode.Enter
        ]) {
            _ = app.update(Event.KeyDown(KeyEvent(key)))
        }
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'x'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Backspace)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Esc)))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'/'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'y'))))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Enter)))
        @Expect(app.refreshInterval(), Duration.millisecond * 1000)

        for (id in ["cpu", "memory", "network", "disk", "proc"]) {
            let poll = app.update(Event.Timer(TimerEvent(id, elapsedMillis: 1000)))
            if (commandHasAsyncTask(poll.command)) {
                _ = runAsyncCommand(app, poll.command)
            }
        }
        for (id in ["btm:cpu", "btm:memory", "btm:network", "btm:disk", "btm:processes"]) {
            _ = app.update(Event.AsyncFailed(id, "synthetic failure"))
            _ = app.update(Event.AsyncCancelled(id))
        }
        _ = app.update(Event.AsyncCompleted("unknown", Event.Message("ignored")))
        _ = app.update(Event.Resize(Rect(0, 0, 100, 32)))
        _ = app.moveProcessSelection(1)
        _ = app.toggleProcessDetail()
        _ = app.dirtyProcessesArea()

        let small = Buffer(Rect(0, 0, 80, 20))
        app.render(small.area, small)
        @Assert(small.getCell(1, 1).symbol.contains("b"))
        let large = Buffer(Rect(0, 0, 100, 32))
        app.render(large.area, large)
        let backend = TestBackend(area: Rect(0, 0, 100, 32))
        let terminal = Terminal(backend, renderMode: RenderMode.Full)
        _ = terminal.draw { frame => app.renderFrame(frame) }
        @Assert(backend.snapshot().contains("btm"))
        let quit = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'))))
        match (quit.flow) {
            case ControlFlow.Exit => ()
            case _ => @Expect(false)
        }
    }
}
