# ADR-010: Metrics and Performance Contracts

## Status

Accepted.

## Context

Architecture Proof required detailed counters and raw traces, but not every attribution field is suitable for permanent stable compatibility.

## Decision

Metrics have three compatibility levels: stable high-level totals, experimental detailed attribution, and internal/test-only proof counters. Performance decisions use correctness differential plus structural counters plus latency distributions. Metrics-off is latency truth; metrics-on is attribution truth.

## Evidence

Steps 0 through 3D separated metadata, wrap, paint, diff, write, queue, frame, and consumer stages; several rejected hypotheses looked plausible from wall-clock alone.

## Consequences

Permanent fitness gates are separated into fast, architecture, release, and microbenchmark tiers. Raw binaries/JSONL are not API contracts and may be archived outside the repository.

Detailed `AppTraceSink` callbacks remain experimental and opt-in through a per-App pre-run attachment. Normal App construction and trace-disabled runtime paths do not require observability configuration.

## Rejected alternatives

Stable compatibility for every counter, RSS as managed allocation, one noisy sample as a regression gate, and permanent retention of every proof workload.

## Revisit conditions

Promote a detailed metric only after multiple operational consumers need the same stable semantic definition.

## Fitness functions

The architecture fitness manifest references valid commands/evidence; structural gates remain machine-readable; proof-only workloads have explicit retention disposition.
