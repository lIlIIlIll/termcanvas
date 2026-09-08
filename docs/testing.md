# Testing

Verification is layered:

- package/core unittests prove local behavior;
- headless scripts and snapshots prove deterministic application workflows;
- all 17 current official examples are built and smoked against their machine
  inventory;
- API, architecture, and fitness validators enforce classified surface and
  permanent invariants; and
- `scripts/release_gate.sh` is the final repository-wide authority.

Retired architecture self-tests and the retired `style_lab` example are not
current workloads. Their historical results remain in ADR/evidence records.

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

Deterministic performance regression tests live in the release gate as ordinary unittest cases, not as benchmarks. Do not assert wall-clock elapsed time in those tests. Prefer scale invariants such as dirty cell count, diff write spans, viewport row count, provider call count, visible window bounds, and regional update/render counts. Current release-gate guards cover Terminal diff locality, the unsorted and unfiltered `VirtualTable` provider path, TextArea viewport/diff locality, and btm_clone timer, async-completion, focus, resize, and regional dirty isolation through its headless smoke entry.

Use `@Bench` / `cjpm bench` for real elapsed-time and slope diagnosis. Benchmark cases are explicit and non-gating; they must not be run by release-gate scripts or used as release pass/fail thresholds. The core benchmark entrypoint is:

```bash
CANGJIE_SDK_ROOT=/path/to/20260817/cangjie \
  scripts/cangjie_cmd.sh packages/core cjpm bench --filter=CjTuiPerformanceBench
```

Canonical verification uses Cangjie
`1.1.0-alpha.20260817040003` with cjpm `1.1.3`. The package manifests retain
`cjc-version = "1.1.0"` as their language compatibility declaration; the exact
compiler identity is enforced by `scripts/check_sdk.sh`. A mutable `daily` SDK
may be used for local exploratory commands only and is not acceptance authority.
`scripts/release_gate.sh` requires `CANGJIE_SDK_ROOT`, rejects any version other
than the canonical compiler before building, and places every cjpm invocation in
a target namespace containing the validated toolchain identity. This prevents
objects produced by another compiler from satisfying the canonical gate.

Cangjie `1.1.0-alpha.20260803040049` is not a valid verification compiler for
this repository: its test-macro code generation produces a deterministic
SIGSEGV while enumerating a legal suite containing `@Bench`.

Additional workflow scripts:

- `scripts/run_event_script.sh packages/core/tests/events/basic.events packages/core/tests/events/scenario.events`
- `scripts/check_golden_snapshots.sh`
- `scripts/generate_api_index.sh`
- `packages/example_smoke` through `scripts/release_gate.sh` for four core component compositions: `Composer`, `CommandPalette`, `RequestDialog`, and `VirtualTable`.
- Every example package that contains `src/*_test.cj` is discovered and run by `scripts/release_gate.sh`; these tests exercise the corresponding application package.
- `scripts/test_examples.sh` checks the example inventory and source expectations, then runs CLI headless smoke for `btm_clone`, `media_gallery`, and `game_demo`.
- `python3 scripts/test_windows_smoke.py` validates Windows runner generation and shared-file restoration with local command doubles; it does not start a Windows VM.
- `python3 scripts/test_resolve_nightly_sdk.py` validates SDK candidate selection with local manifest and response fixtures; it does not download an SDK.
- `scripts/run_windows_smoke.sh` for Windows VM package smoke and game pressure build coverage of the staged current checkout.
- `scripts/run_macos_smoke.sh` for macOS package smoke and game pressure build coverage from an already-present remote checkout.
- `scripts/run_regression_matrix.sh`
- `scripts/run_pressure.sh`

Full unittest execution may need permission to create the local test runner TCP socket.
