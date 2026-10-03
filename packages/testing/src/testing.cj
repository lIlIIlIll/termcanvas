package cjtui_testing

import core.*

// This package owns the downstream contract. Repository test machinery stays
// behind private fields and is never part of its public signatures.
public class TestReport {
    public let passed: Bool
    public let exited: Bool
    public let frames: Array<Buffer>
    public let snapshots: Array<String>
    public let failures: Array<String>

    public init(passed: Bool, exited: Bool, frames: Array<Buffer>, snapshots: Array<String>, failures: Array<String>) {
        this.passed = passed
        this.exited = exited
        this.frames = frames.clone()
        this.snapshots = snapshots.clone()
        this.failures = failures.clone()
    }

    public func lastSnapshot(): String {
        if (snapshots.isEmpty()) { "" } else { snapshots[snapshots.size - 1] }
    }
}

public class TestScenario {
    private let script = HeadlessScript()

    public init() {}

    public func event(value: Event): TestScenario { script.event(value); this }
    public func key(value: KeyEvent): TestScenario { script.key(value); this }
    public func paste(text: String): TestScenario { script.paste(text); this }
    public func message(text: String): TestScenario { script.message(text); this }
    public func render(): TestScenario { script.render(); this }

    public func resize(width: Int64, height: Int64): TestScenario {
        requireSize(width, height)
        script.resize(Rect(0, 0, width, height))
        this
    }

    public func tick(count!: Int64 = 1): TestScenario {
        if (count < 0) { throw IllegalArgumentException("tick count must be non-negative") }
        script.tick(count: count)
        this
    }

    public func expectSnapshot(text: String): TestScenario { script.expectSnapshot(text); this }
    public func expectCell(x: Int64, y: Int64, symbol: String): TestScenario {
        script.expectCell(x, y, symbol)
        this
    }

    public func run(
        render: (Frame) -> Unit,
        update: (Event) -> UpdateResult,
        width!: Int64 = 80,
        height!: Int64 = 24,
        tickDeltaMillis!: Int64 = 16
    ): TestReport {
        requireSize(width, height)
        if (tickDeltaMillis <= 0) { throw IllegalArgumentException("tick interval must be positive") }
        let result = AppTestRunner.run(script, render, update, options: HeadlessRunOptions(
            area: Rect(0, 0, width, height), tickDeltaMillis: tickDeltaMillis
        ))
        let exited = match (result.flow) { case ControlFlow.Exit => true; case _ => false }
        TestReport(result.passed(), exited, result.frames, result.snapshots, result.failures)
    }

    private func requireSize(width: Int64, height: Int64): Unit {
        if (width <= 0 || height <= 0) { throw IllegalArgumentException("test dimensions must be positive") }
    }
}
