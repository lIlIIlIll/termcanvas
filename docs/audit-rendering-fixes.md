# Rendering audit fixes

This change preserves the existing public API and the single immediate-rendering
path. It addresses concrete findings from the comparison at
`cedde456a9caf2a28a762ba4c17818d49726307e`; it is not a claim that all rendering,
Unicode, or runtime coverage work is complete.

## Supplementary ideograph widths

`displayWidth(Rune)` now treats U+20000..U+2FFFD and U+30000..U+3FFFD as two
columns under both ambiguous-width policies. Unicode 17's EastAsianWidth data
assigns `W` to these ranges, including unassigned positions. The final two
noncharacters in each plane are deliberately outside the change.

Source: https://www.unicode.org/Public/17.0.0/ucd/EastAsianWidth.txt

Regression tests exercise rune and string widths, an ideographic variation
sequence, prefix/truncation and wrapping, Canvas placement/clipping, and a
wide-to-narrow terminal update. This targeted repair does not replace the
remaining hand-maintained width tables or redefine emoji presentation policy.

## Dirty rectangle invariants and fragmentation

When merging expands a rectangle, previously skipped rectangles are checked
again. This prevents overlapping entries and double-counted cells after a
transitive merge. The regression includes all six insertion orders of a
three-rectangle reproducer.

At most 64 rectangles are retained. A 65th disjoint rectangle causes conservative
coalescing into one bounding rectangle; subsequent invalidations keep extending
that rectangle until `clear()`. Copies retain this batch state without sharing
storage. Clearing removes entries from the tail rather than repeatedly shifting
the collection from the front.

Dirty rectangles are conservative paint coverage, not an exact changed-cell set.
As with existing bounding unions, coalescing can include unchanged cells. Render
callbacks must paint the current model over the advertised dirty coverage
(`Frame.isDirty` / `Frame.dirtyRects`), including unchanged gaps; they must not
paint only event-origin coordinates and assume gaps are preserved. The regression
compares coalesced partial painting with full painting, including unchanged gaps
and rows outside the dirty region.

This bounds the rectangle-list factor in merge, clipping, snapshot lookup, and
diff scanning. It does not remove the current full-height loop per rectangle,
make snapshot lookup constant time, or promise less repaint area for fragmented
workloads. Coarser repaint is the explicit tradeoff for bounded bookkeeping.

## Coverage reporting versus the legacy CI gate

The coverage job now writes:

- `coverage-cjcov.xml`: the original, unmodified cjcov XML.
- `coverage.xml`: all **reported production package files**, excluding test
  sources and examples, but including app/event/pty/terminal when reported.
- `coverage-gate.xml`: the historical CI-gated subset.
- `coverage-scope.json`: both file lists, counters, and each legacy gate
  exemption, including an explicit flag when its report was not produced.

The existing 90% line / 80% branch thresholds are unchanged. The four whole-file
exemptions remain **gate debt**; the report no longer disguises that narrower
scope as overall production coverage. Extracting deterministic parser/diff logic
from those files and tightening the gate needs a separately validated change.
No threshold was lowered to make this fix pass.

Missing or invalid counters and conflicting duplicate reports fail closed.
Identical duplicate pages are counted once. Paths are normalized before scope
classification, so an absolute or `./` path cannot bypass an exemption.

## Validation

The SDK-independent report fixtures run from `scripts/coverage.sh` and can also
be executed directly:

```bash
python3 scripts/test_coverage_report.py
bash -n scripts/coverage.sh
```

Cangjie regressions are in
`packages/core/src/audit_rendering_regression_test.cj`; the existing core test and
release/coverage jobs discover them. Run the canonical SDK gate before merging:

```bash
scripts/release_gate.sh
scripts/coverage.sh
```
