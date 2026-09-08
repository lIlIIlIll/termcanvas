# Reduced Runtime Metrics Contract Candidate

Status: **EXPERIMENTAL contract freeze; not promoted**.

This document defines the smallest Runtime Observability surface that may be
considered for a future stable contract. It does not change the current API
classification. `AppTraceSink`, `FrameSchedulingSnapshot`, `maxUpdateDepth`,
and `ExternalPort` diagnostics are outside this candidate.

The candidate surface is:

```text
RuntimeMetricsSnapshot
├─ queueEnqueued
├─ queueProcessed
└─ maxQueueDepth

AppMetrics.runtime()
```

`RuntimeMetricsSnapshot.scheduling`, `RuntimeMetricsSnapshot.maxUpdateDepth`,
and public construction of arbitrary snapshots remain experimental and are not
part of the candidate contract.

## Ownership and snapshot consistency

`AppMetrics` is application-owned mutable state. Runtime mutation,
`AppMetrics.runtime()`, and `AppMetrics.reset()` must be serialized by the
owner; the candidate does not make concurrent mutation or concurrent snapshot
creation safe.

Within that ownership rule, `AppMetrics.runtime()` returns a coherent
point-in-time value, not a best-effort mixture of epochs. The returned struct is
an independent immutable value. Reading it does not mutate or reset
`AppMetrics`, and later runtime updates or resets do not change an already
returned snapshot. After it has been safely published using ordinary Cangjie
happens-before synchronization, unrelated consumers may read the immutable
snapshot concurrently.

This contract does not expose `RuntimeQueue`, a physical queue count, a
scheduler, or a synchronization primitive.

## Reset epoch

`AppMetrics.reset()` remains the single public epoch boundary. Immediately
after an owner-thread reset, the three candidate fields are zero. Resetting does
not mutate snapshots that were already returned.

The stable-intended promise is limited to those three fields. The current
method may also clear frame history or experimental scheduling diagnostics, but
those additional effects are not part of this reduced contract and must not be
used to pull those diagnostics into a future stable closure.

Reset may occur while work admitted during the previous epoch is still pending.
Consequently, no contract is made that `queueProcessed <= queueEnqueued` within
an arbitrary epoch. Consumers must treat the counters independently rather than
derive a durable backlog by subtraction across reset.

## `queueEnqueued`

| Property | Contract |
| --- | --- |
| Meaning | Number of logical application-update work items successfully admitted during the current metrics epoch. Rejected work is not counted. |
| Source of truth | The runtime admission boundary, independent of its physical queue or scheduler representation. |
| Update point | Once, after a work item has been accepted into the runtime's pending-update set. |
| Reset behavior | Set to zero by `AppMetrics.reset()`. Previously returned snapshots are unchanged. |
| Thread ownership | Mutated and sampled only by the serialized `AppMetrics` owner. |
| Overflow behavior | Nonnegative and monotonic while representable. An increment beyond `Int64.Max` follows Cangjie's throwing integer-overflow behavior; wrapping is not part of the contract. |
| Unit | Logical work items. |
| Compatibility risk | Changing which admitted items can invoke application update changes the count. Physical queue count, priority, and ordering do not. |

## `queueProcessed`

| Property | Contract |
| --- | --- |
| Meaning | Number of logical work items whose application-update dispatch began during the current metrics epoch. It counts an attempted dispatch even if application update later throws. |
| Source of truth | Entry into the serialized application-update boundary. |
| Update point | Once, immediately before invoking application update for the admitted work item. |
| Reset behavior | Set to zero by `AppMetrics.reset()`. Work admitted in a previous epoch is counted if its update dispatch begins after reset. |
| Thread ownership | Mutated and sampled only by the serialized `AppMetrics` owner. |
| Overflow behavior | Nonnegative and monotonic while representable. An increment beyond `Int64.Max` follows Cangjie's throwing integer-overflow behavior; wrapping is not part of the contract. |
| Unit | Update dispatch attempts. |
| Compatibility risk | Moving the observation point to successful completion would be a semantic break. Callback, render, and frame completion are not included. |

## `maxQueueDepth`

| Property | Contract |
| --- | --- |
| Meaning | Maximum logical pending-update depth observed immediately after an admission during the current metrics epoch. |
| Source of truth | The number of admitted work items not yet removed for application-update dispatch, aggregated across any physical queues. |
| Update point | After each successful logical admission. Dequeue, processing, or sampling alone does not lower the maximum. |
| Reset behavior | Set to zero by `AppMetrics.reset()`. The next admission establishes a new maximum from the total logical pending depth then present, including work admitted before reset. |
| Thread ownership | Mutated and sampled only by the serialized `AppMetrics` owner. |
| Overflow behavior | The value is bounded by nonnegative `Int64` logical depth. A runtime unable to represent its pending depth must fail rather than wrap it negative. |
| Unit | Simultaneously pending logical work items. |
| Compatibility risk | Exact physical queue topology is free to change, but changing the logical pending-update boundary or sampling at another point changes the metric. |

## Runtime implementation freedom

A future runtime may replace the current single FIFO with multiple queues, a
priority queue, or an external scheduler without breaking this contract if it
preserves these logical observations:

1. each successfully admitted application-update work item increments
   `queueEnqueued` once;
2. each application-update dispatch attempt increments `queueProcessed` once;
3. `maxQueueDepth` observes the aggregate pending-update population after
   admission; and
4. all observations remain coherent within the owner-thread epoch.

The contract does not promise FIFO order, physical queue identity, scheduler
reason strings, frame coalescing behavior, or a relationship between work-item
counts and rendered frames.

## Consumer-neutral use

The candidate can support unrelated consumers without exposing runtime
internals:

- a diagnostics UI may take a snapshot on the App owner thread and render
  counts from that immutable value; and
- a telemetry exporter may receive an already-created snapshot over a
  synchronized application-owned channel and export it off-thread.

Neither consumer needs `AppTraceSink`, frame-scheduling taxonomy, wake counters,
or access to a mutable runtime queue.

## Promotion prerequisites

Promotion is not authorized by this document. It additionally requires:

- a second operational consumer using this same reduced contract;
- direct compatibility coverage for the approved declaration set;
- a clean stable dependency closure that excludes scheduling and diagnostics;
- stable-to-nonstable debt remaining zero; and
- an explicit promotion gate with no accidental promotion of excluded members.
