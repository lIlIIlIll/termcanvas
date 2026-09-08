# ADR-007: Composer Paint Ownership

## Status

Accepted.

## Context

Input attribution showed the large frame cost came from consumer-owned Composer clear/chrome/prompt work, not TextArea wrapping.

## Decision

Composer screen chrome and its narrow content dirty scope remain consumer-owned. TextArea retains text/control behavior without a generic incremental-control framework.

## Evidence

Step 3C reduced ordinary single-row input to the narrow content path while preserving full/selective differential correctness.

## Consequences

Consumer-specific paint optimization does not expand core TextArea API or copy canonical text state.

## Rejected alternatives

Generic DiffableWidget, row Component tree, RenderNode/VDOM, and speculative incremental wrapping.

## Revisit conditions

Extract a shared mechanism only after another independent control proves the same edit/dirty ownership contract.

## Fitness functions

Single-row edit does not repaint header/chrome; geometry-changing edit takes the correct layout fallback; optimized/full Buffers match.
