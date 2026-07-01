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

`Terminal.draw()` returns `RenderMetrics`, so render tests can assert full redraws, dirty cell counts, diff write spans, media op counts, and frame timing fields without inspecting private state.

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

Additional workflow scripts:

- `scripts/run_event_script.sh tests/events/basic.events tests/events/scenario.events`
- `scripts/check_golden_snapshots.sh`
- `scripts/generate_api_index.sh`
- `scripts/run_regression_matrix.sh`
- `scripts/run_pressure.sh`

Full unittest execution may need permission to create the local test runner TCP socket.
