# Examples, templates, and architecture proof audit

Baseline: `e30b1c5`. Reviewed source was read directly; previous audit conclusions were not used. The original scope contains 29 Cangjie source/test files (8,526 lines), plus 10 architecture-proof Python scripts (2,169 lines). The two benchmark manifests and examples index were read for contracts. Findings below use baseline line numbers.

## Confirmed findings and fixes

| ID | Severity | Baseline location | Trigger and impact | Fix and regression evidence |
| --- | --- | --- | --- | --- |
| EX-01 | P2 | `examples/assistant_console/src/main.cj:24-25`; `examples/form_studio/src/main.cj:27`; `examples/oh_my_pi_skin/src/main.cj:261-294` | Normal letters are intercepted before the focused editor. Typing `aqua` in Assistant opens approval and exits on `q`; Form cannot type `q`; Skin cannot type `/btq` in its focused Composer. Skin also routes unrecognized keys to Composer while Todo owns focus. | Assistant uses F2 for approval and Ctrl-C for exit; Form uses Ctrl-C; Skin routes all non-Tab input to the focused Composer and ignores unhandled Todo input. Three new real-update-path tests fail on baseline and pass after repair. Existing shortcut tests were updated to the corrected contract. |
| EX-02 | P1 | `examples/game_demo/src/main.cj:486-491,527-544` | Loader never validates the emitted `version=1` marker. An unrelated valid UTF-8 file, missing version, unsupported version, or conflicting version lines sets `saveLoaded=true` and enables subsequent overwrite. This bypasses the existing preservation behavior for failed loads. | Validate exactly one supported version before mutating game state. Regression writes each unsupported input, constructs FarmGame, calls `save`, and verifies the original bytes remain. Baseline failed; fixed test passes. The existing version-1 permissive field/default behavior remains. |
| EX-03 | P1 | `examples/btm_clone/src/main.cj:2045-2047` | `truncateLocal("a界x", 2)` slices inside a UTF-8 sequence and throws `IllegalArgumentException: Invalid utf8 byte sequence`. A valid non-ASCII process command can terminate rendering at a column boundary. Byte length also mishandles wide characters and combining sequences. | Use existing `graphemePrefix` to fit terminal columns. Regression covers CJK, a split boundary, and a combining cluster. Baseline produced an exception; fixed test passes. |
| EX-04 | P2 | `examples/btm_clone/src/main.cj:1399-1401,1424-1438` | Open process detail, then navigate in Diff mode. The update marks both selected rows and detail dirty; frame preparation clears both. The row-only fast path ignores dirty rectangles outside the table and returns before redrawing detail. The detail panel disappears. | Use the row-only optimization only when detail is closed. Regression compares the actual partial redraw after navigation against a subsequent full redraw of unchanged state. Baseline differs; fixed snapshots match. |
| EX-05 | P1 | `examples/terminal_lab/src/main.cj:32-37` | PTY reads expose arbitrary bytes, not complete UTF-8 strings. Feed `中` as `[0xE4]`, then `[0xB8,0xAD]`, or feed `[0xFF,'x']`. Unchecked String construction reaches the transcript renderer and throws. | Incremental decoder retains at most an incomplete code-point suffix, validates each completed rune, replaces malformed input, maintains separate stdout/stderr state, flushes an incomplete suffix on exit, and clears state on restart. Both original repro tests raised errors before repair; fixed tests pass, with additional stream-isolation and exit/restart coverage. |
| EX-06 | P1 | `scripts/architecture_proof_step3b5_long_gate.py:78-98,124` | A process exiting 0 with no proof output passes the gate. Parsed evidence explicitly showing lost content, wrong transcript count, or excessive materialized documents also passes if the child exit status is 0. | Require both proof records, positive frame count, requested configured history, matching transcript counts, preserved content, the documented materialization bound, and successful differential status. Reject empty run sets. Python regression invokes the real main path with controlled child results: 2 cases/4 subcases failed before repair; all 3 cases now pass. Summary retains a per-run `passed` result. |

## Validation

SDK: repository-pinned Cangjie 1.1.3 at `/tmp/termcanvas-sdk/cangjie`. Tests use isolated target directories. The runtime cannot initialize in the restricted execution sandbox, so authorized test commands were run with execution escalation.

```sh
CANGJIE_SDK_ROOT=/tmp/termcanvas-sdk/cangjie \
  CJ_TUI_CANONICAL_TARGET_ROOT=/tmp/termcanvas-examples-target \
  scripts/cangjie_cmd.sh examples/assistant_console cjpm test
# Repeat for form_studio, game_demo, oh_my_pi_skin, btm_clone, terminal_lab.
python3 -m unittest discover -s scripts -p test_architecture_proof_audit_20261003.py
```

| Package | Before new regressions | After |
| --- | --- | --- |
| assistant_console | 3 pass, 1 fail | 4 pass |
| form_studio | 2 pass, 1 fail | 3 pass |
| game_demo | 7 pass, 1 fail | 8 pass |
| oh_my_pi_skin | 8 pass, 1 fail | 9 pass |
| btm_clone | 5 pass, 1 fail, 1 error | 7 pass |
| terminal_lab | 2 pass, 2 errors | 6 pass, including 2 added boundary cases |
| architecture long gate | 3 cases, 4 failing assertions/subcases | 3 pass |

Raw local execution evidence: `/tmp/termcanvas-audit-logs/examples-*-before.log`, `/tmp/termcanvas-audit-logs/examples-*-after.log`, and `/tmp/termcanvas-audit-logs/architecture-long-gate-{before,after}.log`. Initial assistant red log is `examples-assistant-before.log`. These are execution evidence, not committed runtime dependencies. `git diff --check` passes.

## Per-file coverage

All files below were read in full. “No additional confirmed finding” means this review did not establish a reproducible defect; it is not a proof of absence.

| File | Coverage/result |
| --- | --- |
| `examples/arcade/src/main.cj` | Input/tick integration, elapsed accumulators, movement bounds, resize fallback; no additional confirmed finding. |
| `examples/assistant_console/src/main.cj` | Request/composer ownership, paste routing, rendering; EX-01. |
| `examples/assistant_console/src/main_test.cj` | Existing real-update/request/render tests; revised documented shortcuts. |
| `examples/btm_clone/src/main.cj` | Proc parsing, sampling/async ownership, completion ordering, selection/scrolling, partial rendering, helper formatting; EX-03 and EX-04. |
| `examples/btm_clone/src/main_test.cj` | Existing parser, helper, async/filter, and render tests; identified absence of detail-navigation differential and Unicode clipping coverage. |
| `examples/command_center/src/main.cj` | Command dispatch, timers, async completion, toast lifecycle; no additional confirmed finding. |
| `examples/crystal_caves/src/main.cj` | Level tables, entity lifecycle, physics input, overlap transitions, camera, drawing; no additional confirmed finding. |
| `examples/data_browser/src/main.cj` | Focus/modal isolation, table viewport, file/tree navigation, rendering; no additional confirmed finding. |
| `examples/data_browser/src/main_test.cj` | Focus persistence, modal isolation, table paging coverage. |
| `examples/debug_lab/src/main.cj` | Capability/focus/mouse reporting, rendering; no additional confirmed finding. |
| `examples/form_studio/src/main.cj` | Focus routing, paste, widget updates, cursor; EX-01. |
| `examples/form_studio/src/main_test.cj` | Name/notes paste targeting and cursor tests. |
| `examples/game_demo/src/main.cj` | Save/load, economy/domain limits, clock/actions, plot lifecycle, dirty rectangles/full rendering, CLI; EX-02. |
| `examples/game_demo/src/main_test.cj` | Existing shipping, load-failure preservation, save-domain, and rendering tests. |
| `examples/game_pressure_suite/src/main.cj` | Six deterministic workloads, movement bounds, tick state, render sizing; no additional confirmed finding. |
| `examples/gif_ascii/src/main.cj` | Option parsing, async load revision/cancellation, threshold reload, frame rendering; external ffmpeg/cancellation integration not exercised. |
| `examples/markdown_studio/src/main.cj` | Edit/preview/Vim ownership, completion revision, config parsing/bounded reads, rendering; no additional confirmed finding. |
| `examples/markdown_studio/src/main_test.cj` | Existing editor/preview/outline/Vim/completion/syntax refresh tests. |
| `examples/media_gallery/src/main.cj` | Capability fallback, placement geometry, smoke assertions; no additional confirmed finding. |
| `examples/oh_my_pi_skin/src/main.cj` | Todo state/focus, palette, timers/dirty geometry, animation, composer routing; EX-01. |
| `examples/oh_my_pi_skin/src/main_test.cj` | Palette, Todo, focus, timer and rendering coverage; shortcut test explicitly changes focus before Todo commands. |
| `examples/ops_dashboard/src/main.cj` | Tick/timer state, progress ranges, layout; no additional confirmed finding. |
| `examples/ops_dashboard/src/main_test.cj` | Real dashboard tick/reset/timer/render tests. |
| `examples/taskpad/src/main.cj` | Keymap, paste sanitization, task selection/actions, palette, rendering; no additional confirmed finding. |
| `examples/taskpad/src/audit_input_test.cj` | Existing ordinary-text, paste, palette, and task-action regression coverage. |
| `examples/terminal_lab/src/main.cj` | PTY event handling, transcript/stream ownership, mode transitions; EX-05. |
| `examples/terminal_lab/src/main_test.cj` | Existing PTY/mode/failure/render tests. |
| `templates/basic_app/src/main.cj` | Update command/dirty behavior, rendering; no additional confirmed finding. |
| `benchmarks/architecture-proof-step0/fixture/src/main.cj` | Source revisions, workload mutations, measurement boundaries, emitted JSON; no additional confirmed finding. |
| `scripts/architecture_proof_step0.py` | Workload selection, source/binary provenance, collection and aggregation. |
| `scripts/architecture_proof_step0_cold.py` | PTY lifecycle and first-read latency boundary. |
| `scripts/architecture_proof_step0_pty.py` | Scenario generation, harness loading, record normalization. |
| `scripts/architecture_proof_step0_report.py` | Group replacement semantics, percentiles, summary composition. |
| `scripts/architecture_proof_step05_build.py` | Isolated copy, dependency resolution, compiler and source/binary provenance. |
| `scripts/architecture_proof_step05_pty.py` | Candidate identity, fixture settling, scenario generation, normalization. |
| `scripts/architecture_proof_step05_report.py` | Group mappings, scaling, perturbation reporting. |
| `scripts/architecture_proof_step3b5_burst.py` | Producer activation, token totals, geometry invariants, input/resize attribution and grouping. |
| `scripts/architecture_proof_step3b5_long_gate.py` | Subprocess evidence and pass/fail aggregation; EX-06. |
| `scripts/architecture_proof_step3c_composer.py` | Composer scenario setup, producer synchronization and frame observation. |

## Boundaries and non-promoted observations

- The actual external omp-cj consumer/harness and hardware terminal were not available in this checkout. Architecture proof integration and photon latency were not claimed as tested; gate failure behavior was reproduced independently of that consumer.
- BTM proc sampling tests use the Linux `/proc` environment. The detail regression compares two renders of the same application snapshot so sampling timing does not affect the assertion.
- `ProcFsSampler.sampleProcessesOnly` derives `error` from an intentionally empty `CpuSnapshot.cores`, so its internal error string is always `cpu unavailable`; the current UI does not display this field. This was not promoted to a user-visible defect or changed in this patch.
- Two Step-3 dynamic harness loaders do not register their module in `sys.modules`; compatibility with external dataclass/future-annotation harnesses needs the actual consumer to establish relevance. No speculative loader change was included.
- Version-1 farm field parsing remains intentionally permissive as covered by existing tests. This patch validates file identity/version; it does not claim transactional disk writes or strict validation of every field.
- The example PTY application owns one `demo` process. Decoder streams are isolated for that process; this is not a newly introduced multi-process terminal multiplexer.
- Non-modified examples received source review, not a claim that every interaction was exercised. Repository-wide gates are reported separately by the coordinating review.
