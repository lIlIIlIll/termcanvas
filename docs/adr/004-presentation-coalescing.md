# ADR-004: Presentation Coalescing

## Status

Accepted as internal runtime policy.

## Context

After single-frame transcript and Composer work became cheap, streaming still produced close to one physical frame per token.

## Decision

Coalesce physical presentations, never application updates. Runtime owns one pending frame with a fixed non-sliding deadline and accumulated existing DirtyRects. Interactive and resize work promote presentation eligibility. Shutdown discards pending presentation.

## Evidence

Step 1B preserved update count/order while reducing frame count, summed render/draw work, and burst CPU.

## Consequences

No public Scheduler object or consumer scheduling API is introduced. The current deadline value is an implementation policy, not a stable promise.

## Rejected alternatives

Public Scheduler framework, sliding debounce, event coalescing, refresh-rate/VSYNC model, and per-token timers.

## Revisit conditions

Expose policy only if real consumers must control presentation and internal promotion/deadline semantics are insufficient.

## Fitness functions

Update order/count is unchanged; input and resize promote; deadline is bounded/non-sliding; shutdown produces no delayed terminal access.
