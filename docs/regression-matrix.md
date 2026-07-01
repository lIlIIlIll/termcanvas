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
- Golden snapshot file validation: `scripts/check_golden_snapshots.sh`
- API baseline check: `scripts/generate_api_index.sh --check`
- Example builds: `scripts/build_examples.sh`
- Pressure gate: `scripts/run_pressure.sh`

Pressure gate:

```bash
scripts/run_pressure.sh
```

Pressure coverage currently focuses on large editable text, virtual tables, repeated renders, async command bursts, and application examples. Add a pressure case whenever a real app exposes slow rendering, excessive diff churn, or task lifecycle problems.

API baseline:

```bash
scripts/generate_api_index.sh
scripts/generate_api_index.sh --check
```

The generated `docs/api-index.txt` uses repo-relative paths so module splits do not introduce machine-local paths into release artifacts.

External dependencies:

- `packages/markdown` depends on the in-repository `packages/cj_markdown` package.
- The GitHub Actions workflow expects a Cangjie SDK on `PATH` or a `CANGJIE_SDK_URL` secret that points to a downloadable SDK archive.
- Full CI coverage runs from a single checkout; no sibling Markdown parser repository is required.
