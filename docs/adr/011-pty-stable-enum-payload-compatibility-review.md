# ADR-011: PTY Stable Enum Payload Compatibility Review

## Status

Accepted and implemented by Phase 5A-I. The exact five-value PTY data cohort
is STABLE, while PTY runtime integration remains EXPERIMENTAL and concrete
platform implementations remain INTERNAL. Known stable-to-nonstable debt is
zero.

## Frozen scope

Phase 4 consolidation remains complete, and Phase 5A-I is complete. The exact
five-value cohort (`PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and
`PtyExitStatus`) and the existing stable `Command`/`Event` constructors are
the frozen data-protocol scope. This review does not stabilize PTY runtime,
attachment, process ownership, readiness, or platform implementation
contracts. `PtyRuntime`, `PtyProcess`, `EventSource`, and
`App.attachPtyRuntime` remain EXPERIMENTAL, and concrete platform
implementations remain INTERNAL.

## Pre-decision review record (Phase 5A)

The following sections preserve the Phase 5A review record from before the
owner compatibility decision. Their conflicts, payload shapes, risks, and
uncertainty are historical evidence, not the current implementation state.
## Frozen scope at pre-decision (Phase 5A)

Phase 4 consolidation remained complete. At that point, this review did not
change production PTY, `Command`, `Event`, `App`, runtime, consumer, or API
classification source. The stable and experimental contracts and the exact
five known dependency debts remained active until a separately authorized
implementation.


## Contradiction (pre-decision)

`Command` and `Event` are STABLE, so their constructors inherit STABLE tier.
Five constructors expose EXPERIMENTAL payload types:

| Stable constructor | Experimental payload |
| --- | --- |
| `Command.PtyStart` | `PtySpec` |
| `Command.PtyResize` | `PtySize` |
| `Command.PtySendSignal` | `PtySignal` |
| `Event.PtyOutput` | `PtyOutputStream` |
| `Event.PtyExited` | `PtyExitStatus` |

`Command.PtyWrite`, `Command.PtyClose`, `Event.PtyStarted`, and
`Event.PtyFailed` expose only builtin or already-stable payloads and therefore
do not add debt.

## Surface and ownership (pre-decision)

The public PTY family under review at that time separated into three
responsibilities:

- Protocol values: `PtySpec`, `PtySize`, `PtySignal`, `PtyOutputStream`, and
  `PtyExitStatus`.
- Optional integration: `PtyRuntime`, `PtyProcess`, `EventSource`,
  `EventSourceInterest`, and the EXPERIMENTAL `App.attachPtyRuntime` member.
- Runtime/platform implementation: `UnsupportedPtyRuntime`, `LinuxPtyRuntime`,
  `LinuxPtyProcess`, and package-private Linux readiness/process helpers.

The value cohort has a closed public signature dependency graph. `PtySpec`
depends on `String`, `Array<String>`, and `PtySize`; all other value dependencies
terminate in builtin/library primitives. No value holds a runtime, process,
descriptor, callback, mutable lifecycle state, or resource-ownership handle.
Consequently, stabilizing the value protocol without stabilizing the runtime is
technically coherent and does not create a promotion explosion.

## Exact value contracts (pre-decision)

- `PtySpec` is a public class with non-reassignable `command`, `args`, `cwd`,
  `env`, and `size` fields. Defaults are empty args/cwd/env and `PtySize()`.
  It exposes raw environment strings and mutable array values by reference; it
  performs no command/env/cwd validation and does not establish deep
  immutability or thread-safety.
- `PtySize` is an immutable public struct with `cols` and `rows`. Defaults are
  80 by 24 and both dimensions are clamped to at least one. It has no pixel
  geometry or runtime state.
- `PtySignal` is a public enum with `Interrupt`, `Terminate`, `Kill`, and
  `User(Int32)`. The named cases map to POSIX signals and `User` forwards a raw
  native number, so the pre-decision contract included a platform-shaped escape
  hatch.
- `PtyOutputStream` is a public identity enum with `Stdout` and `Stderr`. It is
  not an IO stream and owns no handle or resource.
- `PtyExitStatus` is an immutable public struct with optional `code` and
  `signal`, plus `exited` and `signaled` factories. Its public initializer also
  permits both fields to be absent or both to be present; it does not encode
  core-dump or another explicit status kind.

## Adoption and test evidence (pre-decision)

`terminal_lab` is the only example adopter and is machine-classified as a
feature demo. It constructs `PtySpec`, emits `Command.PtyStart`, matches all PTY
events and both output-stream cases, attaches `LinuxPtyRuntime`, and can execute
a real `/bin/sh` command. No recommended example uses the PTY API.

The principal `agent_tui`, `agent_app`, and omp-cj source and manifests depend on
termcanvas `core`/`markdown` but do not reference this PTY family. Their performance
scripts use an operating-system PTY to drive the application; that is not API
adoption of termcanvas `PtyRuntime` or its payload values.

Four focused core test cases cover fake-runtime command/event routing, a bounded
Linux process, App-owned PTY cleanup and pre-run attachment, and the unsupported
fallback. The tests exercise all five value types indirectly, but there are no
independent value-contract tests that freeze all constructor defaults, invalid
states, raw signal semantics, or future enum evolution. The official
`terminal_lab` smoke is a source-token check; it does not execute the real PTY
path.

## Documentation and compatibility authority (pre-decision)

At that time, the README, API, versioning, platform, and limitation documents
described PTY as optional or experimental integration. The stable
`Command`/`Event` constructors already exposed the exact data concepts, so the
product narrative and machine contract did not then answer whether the data
model itself was a long-term stable promise.

Repository policy permits intentional documented pre-1.0 breaks, but the Phase
4E authorization was explicitly narrow and consumed by `Event.ComponentTick`.
It did not authorize removing these constructors or replacing their payload
types. Either operation is a stable source-contract change, breaks explicit
construction/pattern-match callers, affects exhaustive matches, and carries
enum layout/ABI risk that the source-level contract does not prove safe.
External stable `Command`/`Event` and PTY consumers are unknown.

## Review disposition before owner decision (pre-decision)

The pre-decision repository evidence did not yet answer:

> Does termcanvas intend to guarantee the exact current PTY command/event data model
> as STABLE?

The answer was therefore `NOT YET DECIDABLE`, and the Phase 5A disposition was:

```text
OWNER COMPATIBILITY DECISION REQUIRED
```

At that pre-decision point, no tier changes or stable enum contraction were
authorized by this review. The exact five debts remained active, new debt
remained forbidden, and there was no Phase 5A-I implementation until the owner
chose one of these boundaries:

1. `YES`: freeze the current five-value cohort as the stable request/result data
   model while leaving PTY runtime, attachment, process ownership, readiness,
   and platform implementations experimental/internal.
2. `NO`: keep the protocol experimental and separately authorize stable enum
   contraction/re-homing at an explicit breaking boundary, with exact caller
   migration and source/exhaustiveness/ABI review.

Extracting duplicate stable types, splitting the cohort merely to reduce the
debt count, reclassifying `Command`/`Event`, stabilizing the entire runtime,
adding a generic message/event bus, or hiding the validator debt are rejected.

## Current implementation (Phase 5A-I owner decision and implementation)

Phase 5A-I closed the owner decision. The owner chose the stable PTY
data-protocol boundary without stabilizing PTY runtime integration. Before
promotion, Phase 5A-I hardened the experimental payload shapes:

- `PtySpec` snapshots caller-provided `args` and `env` arrays. It retains raw
  string command/cwd/environment representation and does not move runtime
  validation timing.
- `PtySize` retains 80-by-24 defaults and lower-bound clamping.
- `PtySignal` retains `Interrupt`, `Terminate`, and `Kill`; the unused
  `User(Int32)` raw-native escape hatch was removed.
- `PtyOutputStream` retains exactly `Stdout` and `Stderr`.
- `PtyExitStatus` is now exactly `Exited(Int64)` or `Signaled(Int32)`, matching
  fake and Linux runtime truth and making ambiguous states unrepresentable.

Direct value-contract tests and the existing fake/Linux/App runtime tests passed
before the five types were promoted atomically to STABLE. The existing stable
PTY `Command`/`Event` constructors were neither removed nor rehomed. Runtime,
process, attachment, and readiness contracts remain EXPERIMENTAL; concrete
platform implementations remain INTERNAL.

## Final machine-state invariant (current)

Phase 5A-I is complete. The current machine-state invariant is:

```text
known PTY debt = 0
new violations = 0
unclassified = 0
stable Command/Event constructor removals = 0
stable PTY value cohort = 5
experimental PTY runtime integration remains = true
```
