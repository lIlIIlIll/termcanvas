# Architecture Proof Step 0

## Status and applicability

This document freezes the meaning of the Step-0 measurements. It is a
measurement contract: measurement and proof do not change product behavior or
rendering design.

The contract applies to the currently observable draw, transcript, diff, PTY,
and resize paths. Its boundaries are:

- Production behavior is unchanged when instrumentation is disabled.
- Counters are monotonic within one observed draw or one
  `VirtualTranscriptView` lifetime and never become canonical UI state.
- Timing uses the monotonic clock. Test assertions use structural counters and
  final buffers, never elapsed-time thresholds.
- `regionVisits` is not applicable until a Region architecture exists.
- Managed and native allocation are unavailable. RSS is reported only as RSS.
- Real PTY measurements stop at terminal flush; they are not keyboard-to-photon
  latency.

## Input-domain boundaries

Text classes are ASCII, CJK, emoji, combining sequences, and wide cells.
History boundaries are 100, 1,000, 10,000, and 100,000 items. Terminal
boundaries include height-only changes, small width oscillation, large width
jumps, and combined width/height changes. Streaming distinguishes unchanged
visual height, wrap crossing, complete-line append, and new-item append.

## Scenario matrix

| Scenario ID | Path ID | Scenario and expected assertion |
| --- | --- | --- |
| S001 | P006 | ASCII/CJK/emoji/combining/wide fixtures: full and incremental final Buffers must equal |
| S002 | P006 | streaming and wrap-boundary updates: final Buffers must equal and stale old bounds are cleared |
| S003 | P006 | manual scroll/follow-bottom/resize/modal/style changes: final Buffers must equal |
| S004 | P006 | deliberately incomplete dirty scope: oracle must detect inequality |
| S005 | P004 P005 | append one item at each history boundary: counters expose all metadata and cache work without asserting a new algorithm |
| S006 | P005 | steady line/page/continuous scroll: documents and metadata work are recorded per frame |
| S007 | P005 | streaming A/B/C/D: document, wrap, metadata, Buffer and diff work remain separately attributable |
| S008 | P008 | resize matrix at each history boundary: invalidation and reflow work are recorded |
| S009 | P001 | ASCII/CJK typing, backspace, cursor movement and key repeat: dispatch/update/render/write stages are recorded |
| S010 | P007 | minimal, omp normal and omp 10k process starts: first visible frame is sampled in independent processes |
| S011 | P001 | overlay open/close/switch: behavior and frame distribution are recorded |
| S012 | P002 P003 P005 | identical workload with metrics off/on: raw samples support P50/P95/P99/max overhead comparison |

## Test plan

| Test ID | Scenario ID | Path ID | Test and expected assertion |
| --- | --- | --- | --- |
| T001 | S001 | P006 | differential Unicode fixture expects exact `Cell` equality including style and `CellKind` |
| T002 | S002 | P006 | differential streaming fixture expects exact final Buffer equality |
| T003 | S003 | P006 | differential state matrix expects exact final Buffer equality after every deterministic step |
| T004 | S004 | P006 | sensitivity fixture expects the oracle to report a mismatch |
| T005 | S005 | P004 P005 | transcript append probe expects counters to be non-negative and internally consistent |
| T006 | S006 | P005 | scroll probe expects requested/materialized/cache counters to describe the executed path |
| T007 | S007 | P005 | four streaming probes expect distinct named raw records and stable final content |
| T008 | S008 | P008 | resize probe expects invalidation and wrap counters to be emitted for every size transition |
| T009 | S009 | P001 | PTY input records expect ordered stage timestamps; absent photon timing is explicitly unchanged/unavailable |
| T010 | S010 | P007 | cold-start runner expects one independent process sample per configured iteration |
| T011 | S011 | P001 | overlay fixture expects open/close/switch final-state assertions and raw timings |
| T012 | S012 | P002 P003 P005 | overhead report expects matched off/on sample counts and distribution statistics |

## Reproduction commands

The pinned SDK and harness paths below are host-specific inputs copied from the
original measurement environment. They are not repository prerequisites; replace
them with paths available on the machine that runs the proof. The source-bearing
microbenchmark fixture lives beside its manifest and results, outside the
user-facing example inventory. Build that deterministic driver, then run the
manifest's complete core matrix:

```bash
cd benchmarks/architecture-proof-step0/fixture
OMP_CJ_SDK_ROOT=/home/elliot/cangjie_sdk/daily \
  /home/elliot/playground/learn_agent_cj/scripts/pinned_cangjie cjpm build
cd ../../..

python3 scripts/architecture_proof_step0.py \
  --output benchmarks/architecture-proof-step0/results/<run-id>
```

Run real PTY samples against an explicitly identified omp-cj candidate:

```bash
python3 scripts/architecture_proof_step0_pty.py \
  --harness /home/elliot/playground/learn_agent_cj/scripts/tui_pty_bench.py \
  --candidate '/absolute/path/to/agent_app --fixture' \
  --candidate-root /absolute/path/to/learn_agent_cj \
  --output benchmarks/architecture-proof-step0/results/<run-id>/pty
```

`architecture_proof_step0_cold.py` handles minimal applications that do not
emit application trace records. `architecture_proof_step0_report.py` merges
raw runs without discarding the individual JSONL artifacts. Result directories
are ignored by Git but remain stable on disk; `/tmp` is never their sole
location.

## Observable control-flow paths

| Path ID | Path | Observable boundary |
| --- | --- | --- |
| P001 | input -> application update -> render -> diff -> write | existing `AppTraceSink` timestamps and PTY trace |
| P002 | widget paint -> Buffer writes | attempted and accepted cell assignments |
| P003 | previous Buffer + next Buffer -> diff plan | diff scan time, changed cells, spans |
| P004 | VirtualTranscript sync -> height index | sync calls, metadata touches, reset/update touches |
| P005 | VirtualTranscript cache lookup -> materialization -> Document layout | requests, hits/misses, documents, wrap input bytes |
| P006 | full render and incremental render from the same state | cell-for-cell Buffer comparison |
| P007 | process spawn -> first terminal frame | independent PTY process sample |
| P008 | resize -> invalidation -> transcript reflow | invalidations, metadata, materialization and wrap counters |

## Metric definitions

| Metric | Definition |
| --- | --- |
| `eventsProcessed` | events for which application update returned; supplied by the existing application trace/driver |
| `regionVisits` | unavailable/not-applicable in v1 Step 0 |
| `layoutCalls` | transcript Document layout invocations; not a universal Widget measure count |
| `cacheHits` / `cacheMisses` | `materialize` requests whose full layout identity was reusable / required recomputation |
| `cacheEvictions` | unavailable for the current non-evicting transcript cache; always marked unavailable, never inferred |
| `documentRequests` | calls from the transcript view to `VirtualTranscriptSource.document` |
| `documentsMaterialized` | requested Documents whose rows were laid out in that call |
| `wrapInputBytes` | UTF-8 bytes in Document spans or append-only text presented to a wrapping/layout operation |
| `metadataTouches` | explicit transcript entry or height-index values read/written by sync, invalidation, lookup and update probes |
| `bufferCellAttempts` | cell assignment attempts issued during the render closure, including clipped/rejected assignments |
| `bufferCellWrites` | assignments accepted into a Buffer cell during the render closure; equality with prior value is still a write |
| `diffCells` | final cells found unequal by the front/back diff |
| `diffSpans` | coalesced terminal write spans in the diff plan |
| `ansiBytes` | encoded bytes written by a counting ANSI output; unavailable for backends that cannot expose it |
| `dispatch/update/layout/render/diff/write/total` | monotonic elapsed stage durations; layout is application trace or transcript layout, not universal Widget layout |

## Reverse review and known gaps

- Exact managed allocation, native allocation and keyboard-to-photon latency
  remain uncovered because no truthful current observer exists.
- Wall-clock timer determinism remains uncovered until Step 1; no TestClock is
  introduced here.
- A cache eviction count cannot be claimed because current VirtualTranscript
  has no eviction policy.
- The raw artifact path and build identity are emitted by the runner; reports
  must retain the raw JSON/JSONL files used for any coverage or performance
  claim.
