# Testing

Use `TestBackend` for render tests:

- `lastBuffer()` returns the most recent rendered buffer.
- `snapshot()` returns a plain text view of the current buffer.
- `snapshots()` returns every rendered frame captured by the backend.
- `snapshotAt(index)` returns one captured frame.
- `assertSnapshot(expected)` checks the current plain text buffer.
- `assertSnapshotAt(index, expected)` checks one captured frame.
- `assertCell(x, y, symbol, style)` checks one cell.
- `lastDiffOps()` records diff size for the last draw.
- `lastDiffWrites()` records span-coalesced partial-refresh write count for the last draw.
- `setSize(area)` changes the reported terminal size for resize tests.

`Terminal.draw()` returns `RenderMetrics`, so render tests can assert full redraws, dirty cell counts, diff write spans, copied cell counts, media op counts, and frame timing fields without inspecting private state.

Use `EventScript` for deterministic input tests. It can run ordinary `Event -> ControlFlow` updates or command-based `Event -> UpdateResult` updates. `EventScript.fromText()` accepts `key:a`, named keys such as `key:enter`, `message:load`, `paste:text`, `resize:80x24`, `tick`, and `ctrl-c`.

Use `EventScenario` for workflow tests that need rendering and assertions. A scenario can mix input lines with expectations:

```text
scenario:basic
resize:8x1
key:b
expect:cell:0,0,b
expect:flow:continue
```

Supported expectation lines:

- `expect:flow:continue`
- `expect:flow:exit`
- `expect:cell:x,y,symbol`
- `expect:snapshot:text`

Use `AppTestRunner` for full headless app workflows. `HeadlessScript` can mix key, mouse, paste, message, resize, render, tick, and expectation steps. `HeadlessRunOptions` controls the initial area, synthetic tick count, tick delta, and whether buffers/snapshots are captured. `HeadlessRunResult` exposes captured `Buffer` frames, snapshots, `AppMetrics`, flow, and failures.

Use `SnapshotDiff.text(expected, actual)` or `SnapshotDiff.buffer(expected, actual)` when snapshot failures should include the first mismatching line and column.

For component-runtime tests, prefer `ComponentHost` with small probe components and fixed `Rect`s. Assert local-to-global dirty mapping, timer routing through `Event.ComponentTick`, component-scoped async/data completion routing, and `ComponentProfile` / `ProfilerSnapshot` counters. These tests should assert structural behavior such as dirty rect coverage, update/render counts, skipped renders, datasource pending/error/version state, profiler lookup/sorting/reset behavior, and focused-vs-global key precedence, not elapsed-time thresholds.

Deterministic performance regression tests live in the release gate as ordinary unittest cases, not as benchmarks. Do not assert wall-clock elapsed time in those tests. Prefer scale invariants such as dirty cell count, diff write spans, viewport row count, provider call count, visible window bounds, and component render/update counts. Current release-gate guards cover Terminal diff locality, the unsorted and unfiltered `VirtualTable` provider path, TextArea viewport/diff locality, and btm_clone component isolation through its headless smoke entry.

Use `@Bench` / `cjpm bench` for real elapsed-time and slope diagnosis. Benchmark cases are explicit and non-gating; they must not be run by release-gate scripts or used as release pass/fail thresholds. The core benchmark entrypoint is:

```bash
DISABLE_ZOXIDE=1 CANGJIE_SDK_ROOT=/home/elliot/cangjie_sdk/daily scripts/cangjie_cmd.sh packages/core cjpm bench --filter=CjTuiPerformanceBench
```

Additional workflow scripts:

- `scripts/run_event_script.sh tests/events/basic.events tests/events/scenario.events`
- `scripts/check_golden_snapshots.sh`
- `scripts/generate_api_index.sh`
- `packages/example_smoke` through `scripts/release_gate.sh` for headless, script-driven smoke coverage of the main example workflows.
- `scripts/run_windows_smoke.sh` for Windows VM package smoke and game pressure build coverage of the staged current checkout.
- `scripts/run_macos_smoke.sh` for macOS package smoke and game pressure build coverage from an already-present remote checkout.
- `scripts/run_regression_matrix.sh`
- `scripts/run_pressure.sh`

Full unittest execution may need permission to create the local test runner TCP socket.
