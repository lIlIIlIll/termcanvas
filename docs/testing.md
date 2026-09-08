# Testing

## Reader goal and verification order

Use this page to choose the smallest verification surface for a change, run it
with the repository's accepted toolchain, and locate the next boundary when a
check fails. The layers are deliberately different:

1. package/core unit tests prove local behavior.
2. Headless scripts and snapshots prove deterministic application workflows.
3. All 17 current official examples are built and smoked against their machine
   inventory.
4. API, architecture, and fitness validators enforce classified surface and
   permanent invariants.
5. `scripts/release_gate.sh` is the final repository-wide authority.

Retired architecture self-tests and the retired `style_lab` example are not
current workloads. Their historical results remain in ADR/evidence records.

## Choose a deterministic test helper

### Rendering: `TestBackend`

Use `TestBackend` for render tests. It exposes observable buffers and draw
measurements without requiring private backend state:

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

`Terminal.draw()` returns `RenderMetrics`. Assert full redraws, dirty cell counts,
diff write spans, copied cell counts, media op counts, and frame timing fields
through that result rather than inspecting private state.

### Input: `EventScript`

Use `EventScript` for deterministic input tests. It can run ordinary
`Event -> ControlFlow` updates or command-based `Event -> UpdateResult` updates.
`EventScript.fromText()` accepts `key:a`, named keys such as `key:enter`,
`message:load`, `paste:text`, `resize:80x24`, `tick`, and `ctrl-c`.

### Workflows: `EventScenario` and `AppTestRunner`

Use `EventScenario` when a workflow needs rendering and assertions. A scenario
mixes input lines with expectations:

```text
scenario:basic
resize:8x1
key:b
expect:cell:0,0,b
expect:flow:continue
```

Supported expectation lines are:

- `expect:flow:continue`
- `expect:flow:exit`
- `expect:cell:x,y,symbol`
- `expect:snapshot:text`

Use `AppTestRunner` for a full headless App workflow. `HeadlessScript` can mix
key, mouse, paste, message, resize, render, tick, and expectation steps.
`HeadlessRunOptions` controls the initial area, synthetic tick count, tick
delta, and whether buffers/snapshots are captured. `HeadlessRunResult` exposes
captured `Buffer` frames, snapshots, `AppMetrics`, flow, and failures.

When a snapshot failure needs a location, use
`SnapshotDiff.text(expected, actual)` or `SnapshotDiff.buffer(expected, actual)`;
the diff includes the first mismatching line and column.

## Keep performance checks in the right lane

Deterministic performance regression tests live in the release gate as ordinary
unittest cases, not as benchmarks. Do not assert wall-clock elapsed time in
those tests. Prefer scale invariants such as dirty cell count, diff write spans,
viewport row count, provider call count, visible window bounds, and regional
update/render counts.

Current release-gate guards cover Terminal diff locality, the unsorted and
unfiltered `VirtualTable` provider path, TextArea viewport/diff locality, and
btm_clone timer, async-completion, focus, resize, and regional dirty isolation
through its headless smoke entry.

Use `@Bench` / `cjpm bench` for real elapsed-time and slope diagnosis. Benchmark
cases are explicit and non-gating: release-gate scripts must not run them, and
they must not become release pass/fail thresholds. The core benchmark entrypoint
is:

```bash
CANGJIE_SDK_ROOT=/path/to/20260817/cangjie \
  scripts/cangjie_cmd.sh packages/core cjpm bench --filter=CjTuiPerformanceBench
```

The benchmark is a diagnostic, not a gate. If a performance change needs a
release decision, express the deterministic contract as an ordinary regression
invariant instead of adding a wall-clock threshold.

## Use the accepted compiler and scripts

Canonical verification uses Cangjie
`1.1.0-alpha.20260817040003` with cjpm `1.1.3`. Package manifests retain
`cjc-version = "1.1.0"` as their language compatibility declaration; the exact
compiler identity is enforced by `scripts/check_sdk.sh`.

A mutable `daily` SDK may be used for local exploratory commands only and is not
acceptance authority. `scripts/release_gate.sh` requires `CANGJIE_SDK_ROOT`,
rejects any version other than the canonical compiler before building, and puts
every cjpm invocation in a target namespace containing the validated toolchain
identity. This prevents objects produced by another compiler from satisfying
the canonical gate.

Cangjie `1.1.0-alpha.20260803040049` is not a valid verification compiler for
this repository: its test-macro code generation produces a deterministic
SIGSEGV while enumerating a legal suite containing `@Bench`.

The repository's additional workflow commands are:

- `scripts/run_event_script.sh packages/core/tests/events/basic.events packages/core/tests/events/scenario.events`
- `scripts/check_golden_snapshots.sh`
- `scripts/generate_api_index.sh`
- `packages/example_smoke` through `scripts/release_gate.sh` for four core component compositions: `Composer`, `CommandPalette`, `RequestDialog`, and `VirtualTable`.
- Every example package that contains `src/*_test.cj` is discovered and run by `scripts/release_gate.sh`; these tests exercise the corresponding application package.
- `scripts/test_examples.sh` checks the example inventory and source expectations, then runs CLI headless smoke for `btm_clone`, `media_gallery`, and `game_demo`.
- `python3 scripts/test_windows_smoke.py` validates Windows runner generation and shared-file restoration with local command doubles; it does not start a Windows VM.
- `python3 scripts/test_resolve_nightly_sdk.py` validates SDK candidate selection with local manifest and response fixtures; it does not download an SDK.
- `scripts/run_windows_smoke.sh` provides Windows VM package smoke and game pressure build coverage of the staged current checkout.
- `scripts/run_macos_smoke.sh` provides macOS package smoke and game pressure build coverage from an already-present remote checkout.
- `scripts/run_regression_matrix.sh`
- `scripts/run_pressure.sh`
- `scripts/coverage.sh [output-dir]` runs Cangjie package/example tests with coverage instrumentation and writes a `coverage.xml` report for Codecov. The enforced 90% line / 80% branch scope contains production package sources; test files, demo applications, and the OS-specific terminal lifecycle files (`packages/core/src/{app,event,pty,terminal}.cj`) are excluded from the aggregate. Example tests still run in the same command as regression coverage.

Full unittest execution may need permission to create the local test runner TCP
socket.

## Where to look when verification fails

- A failure in the final acceptance decision belongs to `scripts/release_gate.sh`,
  which is the repository-wide authority; confirm `CANGJIE_SDK_ROOT` and the
  canonical compiler identity before interpreting build or test output.
- A snapshot mismatch belongs at the first mismatching line and column reported
  by `SnapshotDiff`, then at the captured `TestBackend` frame or
  `RenderMetrics` values.
- A deterministic rendering or workflow regression belongs in the relevant
  `TestBackend`, `EventScript`, `EventScenario`, or `AppTestRunner` layer before
  escalating to the full matrix.
- A benchmark result is diagnostic evidence only; it cannot establish a release
  pass/fail result.
- If the full unittest runner cannot start, check whether it has permission to
  create its local test runner TCP socket.
