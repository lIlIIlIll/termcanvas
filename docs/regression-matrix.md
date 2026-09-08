# Regression Matrix

The regression matrix combines parser tests, adapter tests, core unit tests, script replay, golden snapshots, API baseline checks, example builds, and pressure-oriented scenarios.

Run the full matrix:

```bash
scripts/run_regression_matrix.sh
```

Matrix lanes:

- Markdown parser tests: `packages/cj_markdown`
- Markdown adapter tests: `packages/markdown`
- Terminal output adapter tests: `packages/terminal`
- Diff adapter tests: `packages/diff`
- Core unit and workflow tests: `(cd packages/core && cjpm test --no-color)`
- Event script validation: `scripts/run_event_script.sh packages/core/tests/events/basic.events packages/core/tests/events/scenario.events`
- Core component compositions: `packages/example_smoke` exercises `Composer`, `CommandPalette`, `RequestDialog`, and `VirtualTable`
- CLI application smoke: `scripts/test_examples.sh` runs `btm_clone`, `media_gallery`, and `game_demo` with `--headless-smoke`
- Golden snapshot file validation: `scripts/check_golden_snapshots.sh`
- API baseline check: `scripts/generate_api_index.sh --check`
- Example builds: `scripts/build_examples.sh`
- Example package tests: every `examples/*/src/*_test.cj` package discovered by `scripts/release_gate.sh`
- Pressure gate: `scripts/run_pressure.sh`
- Windows VM smoke: `scripts/run_windows_smoke.sh`
- macOS smoke: `MACOS_REPO=/path/to/cj_tui scripts/run_macos_smoke.sh`

Pressure gate:

```bash
scripts/run_pressure.sh
```

Application behavior is checked by each discovered `examples/*/src/*_test.cj` package. The component-composition package does not stand in for those application tests. `scripts/test_examples.sh` separately validates the example inventory and source expectations before running the three CLI headless smoke commands listed above.

Pressure coverage currently focuses on large editable text, virtual tables, repeated renders, async command bursts, deterministic performance regression guards, application examples, and the `game_pressure_suite` example covering roguelike, snake, 2048, minesweeper, turn-based strategy, and lightweight real-time action loops. The deterministic guards cover Terminal diff locality, unsorted and unfiltered VirtualTable viewport provider reads, large TextArea edit locality, and btm_clone application-owned timer/async/dirty isolation without using wall-clock thresholds. `scripts/run_pressure.sh` must not run `cjpm bench`; benchmark cases are explicit non-gating diagnostics. Add a pressure case whenever a real app exposes slow rendering, excessive diff churn, or task lifecycle problems.

API baseline:

```bash
scripts/generate_api_index.sh
scripts/generate_api_index.sh --check
```

The generated `docs/api-index.txt` uses repo-relative paths so module splits do not introduce machine-local paths into release artifacts.

External dependencies:

- `packages/markdown` depends on the in-repository `packages/cj_markdown` package.
- The GitHub Actions workflow pins `CANGJIE_SDK_VERSION` to the same canonical compiler accepted by `scripts/check_sdk.sh`, then installs it through `scripts/resolve_nightly_sdk.py`. Resolution order is explicit `CANGJIE_SDK_URL`, `CANGJIE_SDK_MANIFEST`, then DevRepo lookup with `DEVREPO_TOKEN`/`TOKEN`.
- `scripts/resolve_nightly_sdk.py --install --emit-github-env` writes both SDK command directories to `GITHUB_PATH`, plus `CANGJIE_HOME`, `CANGJIE_SDK_ROOT`, `CJ_TUI_NIGHTLY_SDK_VERSION`, and SDK library paths for subsequent CI steps.
- If the release gate fails under a nightly SDK on a non-PR CI run, `scripts/archive_nightly_failure.sh` creates and pushes `archive/nightly-fail/<sdk-version>/<short-sha>` pointing at the tested commit. The script skips an existing remote archive branch for the same commit; local invocations remain non-pushing unless `CJ_TUI_PUSH_NIGHTLY_ARCHIVE=1` is set.
- Full CI coverage runs from a single checkout; no sibling Markdown parser repository is required.

Platform smoke:

```bash
scripts/run_windows_smoke.sh
```

The Windows smoke wrapper expects the local VM share layout used by `run-vbox-cj-tests`: `SHARE` defaults to `/home/elliot/share`, with the Windows SDK under `$SHARE/sdk`. Override `BACKEND`, `SHARE`, or `RUN_VBOX_CJ_TESTS` when needed. After its prechecks pass, the wrapper takes a share-local lock, stages the current checkout in a unique `$SHARE/cases/cj_tui.*` directory, installs `scripts/windows_repo_smoke.ps1` as a temporary custom runner, restores any previous shared runner on exit, and removes only its own staging directory.

macOS validation uses the same public smoke package, but it must run from a checkout already present on the macOS host or from an explicitly approved source transfer to that host.

```bash
MACOS_REPO=/path/to/cj_tui scripts/run_macos_smoke.sh
```

`MACOS_HOST` defaults to `cjlibs@10.0.0.10`. Set `MACOS_CANGJIE_ROOT` when the remote shell does not already expose `cjc` and `cjpm`; set `MACOS_SDKROOT` when the remote linker cannot infer a macOS SDK. The wrapper checks the canonical compiler and cjpm versions, validates the Darwin library layout when an SDK root is supplied, runs `packages/example_smoke`, and then builds `examples/game_pressure_suite` directly with that macOS `cjpm`. It does not transfer repository contents. The Windows custom runner uses the same package sequence inside the VM. The former `packages/document` and `packages/editor` alias facades have retired; canonical document and editor behavior remains covered by core, markdown, and example gates.
