# ADR-001: State Ownership

## Status

Accepted. Consolidation migration remains pending.

## Context

Architecture Proof compared application-owned state with retained component-owned state. The principal consumer keeps business truth in its application/reducer and uses explicit control models plus derived rendering caches.

## Decision

Applications own canonical business and persistent UI truth. A control model may own only its unique interaction state. Geometry, wrapping, layout, and materialization are derived caches. Background workers produce immutable results and cannot directly mutate application, control, Widget, Buffer, or terminal state.

## Evidence

Step 1A required runtime-boundary mutation and stale-generation rejection. The principal consumer does not require component-owned canonical state. See `architecture/evidence-index.json`.

## Consequences

Every state category has one owner. Cache invalidation may discard and recompute derived state without changing canonical truth.

## Rejected alternatives

Universal retained Component state and duplicated application/component/runtime copies of transcript state.

## Revisit conditions

Revisit retained local lifecycle/state only after two independent real consumers show requirements that App plus explicit control models cannot express cleanly.

## Fitness functions

Background completion mutation occurs only through the runtime boundary; stale owner generations cannot mutate a reused owner.
