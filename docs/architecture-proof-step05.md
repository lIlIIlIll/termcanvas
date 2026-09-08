# Architecture Proof Step 0.5: Consumer Attribution Bridge

## Status and applicability

Step 0.5 is measurement-only. It connects the existing `termcanvas` metrics to
the real `learn_agent_cj/agent_tui` consumer without changing event ordering,
rendering, layout, invalidation, virtualization, or scheduling semantics.
Measurement and proof do not change product behavior. This contract covers the
reachable consumer paths, the listed input domains, and the executed coverage
boundary below; it does not turn an unavailable oracle into a product claim.

## Input domains

- History: 100, 1,000, 10,000, and 100,000 items.
- Terminal geometry: 100x28 default; small width oscillation, large width jump,
  continuous width changes, height-only changes, and width+height changes.
- Text: ASCII, CJK, emoji, combining marks, ANSI-like fixture text, short
  same-line append, wrap-crossing append, complete line, and new item.
- Instrumentation: trace off, trace with core metrics off, and trace with core
  metrics on. Latency comparisons use OFF/ON/OFF ordering.
- State: follow-bottom, manual scroll, modal closed/open/switching, first frame,
  repeated frames, and shutdown.

## Semantic scenario matrix

| Scenario ID | Input | Pre-state | Path IDs | Expected behavior | Required assertions | Type | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S001 | isolated release build | current dirty workspaces | P001 | binary uses the live sibling `termcanvas` source | resolved path, dirty hashes, compiler/build mode, binary hash and trace schema recorded | regression | P0 |
| S002 | startup/input with core metrics OFF | trace enabled | P003,P005 | timing trace works without hot counters | core-metrics flag false; counter fields unavailable; frame timing ordered | normal | P0 |
| S003 | same workload with core metrics ON | trace enabled | P004,P005 | same visible behavior with counters | final snapshot/hash matches OFF; counters are non-negative and frame scoped | regression | P0 |
| S004 | ASCII/CJK/backspace/cursor/Up-Down at 100k | fixture ready | P003,P004,P005 | input reaches a completed frame | 120 samples per workload; update/render/diff/write distributions present | normal,boundary | P0 |
| S005 | line/page/continuous scroll | histories selected | P005 | viewport work is attributable | line covers all histories; page/continuous cover 100 and 100k; materialization stays bounded | performance | P0 |
| S006 | streaming A/B/C | dedicated live item exists | P007 | same item is updated with no-wrap, wrap, or line append payload | item count unchanged; trace identifies actual metadata/document/wrap/buffer work | performance | P0 |
| S007 | streaming D | fixture ready | P008 | exactly one fixture item is appended per operation | item count grows; metadata/index work and latency are recorded for all histories | performance | P0 |
| S008 | five resize patterns | 100k fixture; scaling subset all histories | P009 | geometry change is traced without semantic changes | resize frame and transcript counters present; width scaling distinguishable from height-only | boundary,performance | P0 |
| S009 | overlay open/close/switch | normal screen visible | P006 | overlay timing is separated from normal regions | overlay duration present; close restores selected final snapshot | regression | P0 |
| S010 | narrow modal dirty region with wide cells | product fixture | P010 | existing behavior is observed, not repaired | final snapshot compared; any mismatch is reported as correctness blocker | regression | P0 |
| S011 | trace disabled and traced shutdown | active terminal session | P002,P011 | instrumentation does not alter shutdown | startup/smoke/shutdown tests pass and terminal exits normally | lifecycle | P0 |

## Test and benchmark plan

| Test ID | Scenario IDs | Path IDs | Input | Expected result | Assertions | Type |
| --- | --- | --- | --- | --- | --- | --- |
| T001 | S001 | P001 | isolated snapshot build | provenance linkage succeeds | exact resolved path and hashes; fresh binary hash | minimal |
| T002 | S002,S003 | P003,P004,P005 | one deterministic frame OFF/ON | trace schema remains parseable | ordered timestamps; OFF unavailable; ON counters present | minimal |
| T003 | S004 | P003,P004,P005 | five 100k input workloads | 120 completed frames each | sample count and stage distributions | extended |
| T004 | S005 | P005 | scroll matrix | completed viewport frames | sample counts and metadata/materialization counters | extended |
| T005 | S006 | P007 | streaming A/B/C | existing item updated | workload label, no count growth, counter deltas | extended |
| T006 | S007 | P008 | streaming D, 100..100k | new item appended | count growth and metadata scaling | extended |
| T007 | S008 | P009 | resize matrix | completed resize frames | geometry, counter and timing distributions | boundary |
| T008 | S009 | P006 | overlay open/close/switch | overlay stage isolated | final snapshots and overlay duration | regression |
| T009 | S010 | P010 | wide-cell modal path | no silent oracle weakening | exact final screen comparison or explicit blocker | regression |
| T010 | S011 | P002,P011 | focused consumer tests and PTY exit | behavior unchanged | test exit status and graceful process exit | lifecycle |
| T011 | S002,S003 | P003,P004 | OFF/ON/OFF representative workloads | perturbation measured without correction | three raw distributions and execution order | performance |
| T012 | S005,S006,S007,S008 | P005,P007,P008,P009 | closest core/product workloads | work, not latency, is correlated | metadata, documents, wrap and Buffer counters compared | performance |

## Executed coverage boundary

The real PTY driver records completed frames, terminal bytes, process exit, and
all timing/counter fields above. It does not emulate the terminal into a Cell
grid, so S003/S009/S010 do not claim a product-level final-screen hash. Existing
core differential/wide-cell tests remain the Cell-level oracle. The product
modal/CJK path was exercised without an observed crash or shutdown failure, but
the known partial-dirty/wide-cell interaction remains unclosed rather than being
silently treated as passed.

## Control-flow paths

| Path ID | Conditions | Reachability | Observable result |
| --- | --- | --- | --- |
| P001 | `agent_tui` resolves `core` and `markdown` through sibling path dependencies | reachable | isolated build log, resolved real path, source hashes, and binary hash agree |
| P002 | product trace disabled | reachable | no trace plumbing or core counters execute |
| P003 | product trace enabled, core metrics disabled | reachable | stage timing is emitted; instrumentation counters are marked unavailable |
| P004 | product trace and core metrics enabled | reachable | stage timing and frame-scoped counter deltas are emitted |
| P005 | normal frame with transcript dirty | reachable | transcript and normal-region stages are attributed separately |
| P006 | modal or plan-review frame | reachable | overlay stage is separated while any real background-region work remains visible in its own stage |
| P007 | fixture appends to the existing streaming item | reachable | A/B/C workloads preserve item identity and expose reflow work |
| P008 | fixture appends a new transcript item | reachable | D workload exposes count/index metadata work |
| P009 | width or height changes | reachable | resize trace associates geometry change with transcript counters |
| P010 | partial dirty rectangle intersects wide-cell guard columns | reachable, known risk | differential/product snapshot records whether adjacent cells are lost |
| P011 | benchmark shuts down with tracing enabled | reachable | terminal exits and restores without trace-induced failure |

## Stable attribution semantics

- Product stage durations are measured only while product tracing is enabled.
- Core metrics OFF is the latency source of truth. Core metrics ON is the work
  attribution source; no corrected latency is calculated.
- VirtualTranscript work fields are cumulative inside the view and exported as
  non-negative per-frame deltas. A view-generation reset starts a new delta
  baseline rather than attributing old work to a new view.
- `product_other_ns` is a residual inside the product render closure after
  screen preparation, transcript, activity, queue/todo, composer, and overlay
  durations. It is not a new independently timed stage.
- Product output records are emitted only after `Terminal.draw` returns, so
  Buffer, diff, ANSI, and write metrics refer to the same completed frame.
- End-to-end measurements stop at terminal flush and are not photon latency.

## Known non-goals

No ExternalPort, queue rewrite, scheduling/coalescing, OwnerToken, Region,
VirtualTranscript index/cache change, AgentScreen decomposition, focus/overlay
redesign, or partial-dirty correctness fix is part of Step 0.5.
