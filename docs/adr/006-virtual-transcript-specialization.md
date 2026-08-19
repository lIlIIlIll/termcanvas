# ADR-006: VirtualTranscript Specialization

## Status

Accepted as a specialized experimental public view.

## Context

Transcript workloads require append-friendly height lookup, anchoring, lazy width measurement, viewport materialization, and precise streaming paint.

## Decision

Keep `VirtualTranscriptView` specialized. Append uses an append-friendly index; width/theme changes bump a generation and remeasure visible work lazily; heavy documents remain viewport/overscan bounded; same-height item changes use precise item dirty; offscreen tail changes do not paint. Real follow-bottom mapping shifts may conservatively repaint the viewport.

## Evidence

Steps 2A, 2B, and 3B changed historical work to bounded/viewport work. Step 3D's geometry-suffix prototype recorded 0 selective hits in 295 real frames and no CPU reduction, so it returned STOP.

## Consequences

Index, generations, ranges, and caches remain internal. Precise dirty hints and the view API remain EXPERIMENTAL pending a second consumer.

## Rejected alternatives

Generic VirtualViewport, history-sized retained item tree, and retained geometry-suffix snapshots.

## Revisit conditions

Genericize only after two independent virtualized views share anchor, index, cache, append, and removal semantics. Revisit suffix mapping only with material stable-origin hit rate.

## Fitness functions

Append is history-independent; width work is viewport-dependent; same-height update paints one item; offscreen tail paints zero; materialization is bounded.
