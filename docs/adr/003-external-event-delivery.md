# ADR-003: External Event Delivery

## Status

Accepted as a stable producer contract. Runtime readiness, lifecycle internals,
and diagnostics remain nonstable.

## Context

Real streaming completions previously depended on unrelated timer/input activity to enter the UI loop.

## Decision

`ExternalPort<A>` is bounded, non-blocking, and reports `Accepted`, `Full`, or
`Closed`. Empty-to-nonempty transitions wake the runtime with level-visible
semantics. Concurrent successful calls are mutex-linearized; sequential calls
from one producer preserve program order. `close()` is idempotent, rejects later
enqueue, and may discard accepted values not yet imported. Producers cannot carry
UI-mutating closures or access rendering/application state directly.

## Evidence

Step 1A proved idle wake, shutdown races, bounded backpressure, and integration
through the principal omp-cj consumer. Phase 5C-I added direct capacity,
multi-producer ordering, close-idempotence, accepted-before-close discard, and
post-close tests before stabilization.

## Consequences

The producer constructor, capacity, `tryEnqueue`, `close`, result enum, and
`App.runWithExternalPort` are STABLE. `drain`, readiness, closing barriers, and
runtime state are implementation-only; counters and latency capture remain
EXPERIMENTAL diagnostics. `Accepted` means port acceptance with required wake
publication, not `App.update` completion or durable eventual delivery.

## Rejected alternatives

Polling mailboxes, unbounded queues, silent drop, and producer-side UI mutation.

## Revisit conditions

Revisit the stable contract only through normal compatibility governance. Review
diagnostics or `EventSource` independently if real consumers require them.

## Fitness functions

Accepted action wakes an idle runtime; Full/Closed are observable; shutdown cannot execute late actions.
