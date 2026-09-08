# Architecture Proof Step 1A: Runtime Correctness Foundation

Step 1A is a correctness and lifecycle proof. It does not change frame cadence,
render invalidation, layout, or transcript virtualization.

## Runtime contracts

- Every accepted runtime item receives a monotonically increasing sequence.
- The runtime consumes accepted items FIFO and invokes one application update
  at most once for each item.
- Commands produced by an update append work to the queue. They never invoke
  the application update synchronously.
- Update is run-to-completion: events accepted during update, render, or wake
  handling append to the queue and cannot re-enter update.
- `ExternalPort<A>` is bounded and non-blocking. Enqueue returns `Accepted`,
  `Full`, or `Closed`; no accepted action is silently lost.
- Wake is level-visible: while a port is non-empty, clearing one notification
  cannot make the runtime sleep indefinitely.
- Runtime lifetime is `Running -> Closing -> Closed`. Closing rejects new
  external actions, timers, and operations. Late completions are discarded.
- Async owner identity is `(slot, generation)`. Reusing a slot increments the
  generation; operation identity is independent from owner identity.
- Cancellation is a request, not settlement. Generation validation remains
  mandatory for late completions.
- A background loader publishes an immutable completion. Only the UI/runtime
  boundary applies that completion to retained `DataSource` state.

## Control-flow paths and input domains

| Path ID | Semantics / input domain | State and side effects |
| --- | --- | --- |
| P1 | terminal/input/timer/PTY Event is accepted | enqueue only; UI update owns mutation |
| P2 | update returns Emit, Message, or another Command | command processing appends Event; no recursive update |
| P3 | external producer submits an immutable action | bounded port result plus level-visible wake |
| P4 | async task completes or cancellation races completion | wake runtime, validate lifecycle, then settle |
| P5 | runtime exits or an update/render fails | Running to Closing to Closed; restore resources once |
| P6 | DataSource worker succeeds or fails | publish immutable completion; UI apply owns retained mutation |

Input equivalence classes include empty/non-empty/full/closed queues, first and
reused owner generations, completion before/after cancellation, due/not-due
clock boundaries, success/failure exits, and events accepted during update,
render, wake handling, or shutdown.

## Scenario matrix

| Scenario ID | Priority | Path ID | Scenario | Expected assertion |
| --- | --- | --- | --- | --- |
| S1 | P0 | P1 P2 P3 | input A emits B/C while external D arrives | accepted envelopes equal sequence order and update depth remains one |
| S2 | P0 | P2 | nested Emit and Message | assert no synchronous nested update |
| S3 | P0 | P3 | external enqueue during update/render | expected item runs after current turn |
| S4 | P0 | P3 | one idle external enqueue | expected waiter wakes without timer or input |
| S5 | P0 | P3 | burst, full, close, and wake-clear races | assert Accepted/Full/Closed explicitly and no lost wake |
| S6 | P0 | P4 | owner generation 1 completes after slot reuse | assert generation 2 state unchanged and orphan increments |
| S7 | P0 | P4 | cancel requested then completion arrives | expected completion settles only after generation validation |
| S8 | P0 | P6 | DataSource loader completes off-thread | assert retained fields unchanged until UI apply |
| S9 | P0 | P5 | shutdown with pending work or failure | assert no post-close work and restore exactly once |
| S10 | P1 | P1 P4 | timer/async/PTY/input interleave | expected accepted sequence defines mutation order |
| S11 | P1 | P1 | TestClock crosses a timer boundary | assert exact timer event and count without wall clock |
| S12 | P1 | P1 P2 | queue burst | assert FIFO accepted prefix and bounded processing |
| S13 | P1 | P1 | metrics off/on | assert identical final state/buffer |
| S14 | P2 | P1 P3 | product input/scroll/stream/resize/modal | expected no stable metrics-OFF regression |

## Test plan

| Test ID | Scenario ID | Path ID | Automated test / assertion |
| --- | --- | --- | --- |
| T1 | S1 S2 S12 | P1 P2 | `RuntimeFoundationTest` asserts FIFO and `maxUpdateDepth == 1` |
| T2 | S4 S5 | P3 | `ExternalPort` and idle-wake tests assert explicit capacity and wake behavior |
| T3 | S6 S7 | P4 | ownership test asserts stale completion is orphaned after generation reuse |
| T4 | S8 | P6 | DataSource tests assert no worker mutation before `apply(Event)` |
| T5 | S9 | P5 | failure test asserts each enabled terminal restore sequence occurs once |
| T6 | S10 | P1 P2 P4 | command, PTY, timer, and async suites assert ordered non-reentrant delivery |
| T7 | S11 | P1 | TestClock test asserts 24 ms not due and 25 ms exactly due |
| T8 | S13 | P1 | existing differential tests assert metrics do not alter final Buffer |
| T9 | S14 | P1 P3 | Step-0.5 workload rerun asserts metrics-OFF distributions have no stable regression |

## Reverse-review gaps

- Windows wait-handle code is source-reviewed in this Linux gate but still
  needs a native Windows execution artifact.
- Real keyboard-to-photon latency and managed allocation remain unavailable;
  neither is claimed as covered by Step 1A.
- Region invalidation and transcript scaling are deliberately uncovered here
  and remain Step 2/3 work.

## Scope exclusions

No Region, scheduler/frame deadline, frame coalescing, VirtualTranscript index or
cache change, AgentScreen decomposition, focus/overlay redesign, or public API
cleanup belongs to this step.
