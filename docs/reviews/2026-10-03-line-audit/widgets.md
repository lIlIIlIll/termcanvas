# Widget audit — 2026-10-03

Baseline: `e30b1c5`. All locations below refer to that baseline, not shifted post-fix line numbers. Review used current implementation, current tests and `docs/widgets.md`; earlier review conclusions were not treated as findings.

## Line-review coverage

| Production file (`packages/core/src/`) | Baseline lines | Reviewed surface |
| --- | ---: | --- |
| `command_widgets.cj` | 377 | menu/palette navigation, toast lifetime, spinner, dialog sizing and confirmation |
| `container_widgets.cj` | 233 | vertical/horizontal distribution, overlays, padding, docking and scrolling |
| `content_widgets.cj` | 1011 | transcript layout/status, composer history/paste/completion, request dialogs and editing helpers |
| `dashboard_widgets.cj` | 301 | metrics/meters, legends, charts, bars and status/empty overlays |
| `data_widgets.cj` | 1049 | pagination, virtual table render/navigation/cache/filter/sort, trees and file picker |
| `form_widgets.cj` | 427 | buttons/check/radio/select/dropdown, colors, multi-selection and dates |
| `visual_widgets.cj` | 304 | progress, sparkline, gauge, chart and log rendering |
| **Total** | **3702** | All lines read; targeted executable coverage below |

The container finding concerns an extreme but valid Int64 gap. Reading every line does not prove that every possible input or interleaving is correct.

## Confirmed findings and fixes

All findings below are P2 functional defects. There are 12 findings covered by 14 new tests, not 14 independently counted defects.

### WG-01: visual scaling overflows before division

- Baseline: `visual_widgets.cj:104,132,141,161,193,218,271`.
- Trigger: `ProgressBar(Int64.Max, total: Int64.Max)` in a 10-column viewport; a segment with `Int64.Max`; `Chart([Int64.Max, ...])` in a two-row viewport. Sparkline levels and percentage labels use the same unsafe multiply-then-divide formula.
- Impact: legal `Int64` input raises `OverflowException: mul` during rendering even when the final scaled result is tiny and representable. Negative chart/sparkline inputs may also overflow before being clamped.
- Baseline evidence: `progressScalingAcceptsLargeCounters`, `progressSegmentsScaleAndClipLargeValues`, and `chartAndSparklineScaleLargeAndNegativeSamples` each terminated with multiplication overflow. The latter stops at Chart before reaching its Sparkline assertions; the Sparkline path is established by the source formula and covered after the fix, not claimed as separately observed before-fix execution.
- Fix: reuse the existing exact integer wide-product division helper, add zero/full-extent guards, clamp samples before scaling, and use it consistently for horizontal/vertical progress, segments, labels, Chart and Sparkline. No floating-point approximation or relaxed bound.

### WG-02: custom progress symbols paint neighboring regions

- Baseline: `visual_widgets.cj:89-108,122,135,148,157,164`.
- Trigger: render a progress segment with symbol `"XY"` in a three-column subregion of a larger Buffer.
- Impact: repeating symbols by cell count writes six columns; three cells outside the assigned area change.
- Baseline evidence: `progressCustomSymbolsStayInsideTheAssignedArea` observed 3 changed outside cells for the segmented bar.
- Fix: scope the whole progress render to its assigned canvas clip and bound filled/head/segment writes to their allotted display columns.

### WG-03: paginator ceiling division overflows

- Baseline: `data_widgets.cj:15,21`.
- Trigger: `Paginator(pageSize: 2, total: Int64.Max)`; the mathematically valid page count is 4611686018427387904.
- Impact: construction raises `OverflowException: add` because `total + pageSize - 1` overflows before division.
- Baseline evidence: `paginatorCeilingDivisionDoesNotOverflow` ERROR at constructor line 15.
- Fix: use `(total - 1) / pageSize + 1` for positive totals. The test also checks End/offset and a one-item page of `Int64.Max` size.

### WG-04: frozen table columns hide the selected scrolling column

- Baseline: `data_widgets.cj:484-497`.
- Trigger: three columns of width 3, viewport width 8, first column frozen, third column selected.
- Impact: visibility calculation charges the frozen column once and then removes it while scrolling, although render always paints it again. The body renders `"aaa bbb "`; selected column `ccc` disappears, violating the documented selected-column visibility behavior.
- Baseline evidence: `frozenColumnsReserveSpaceForTheSelectedScrollingColumn` observed `columnOffset=1` and `"aaa bbb "` instead of offset 2 and `"aaa ccc "`.
- Fix: subtract frozen widths first, then budget scrolling columns backward from the selection. Width accumulation is bounded; it avoids introducing a new sum overflow.

### WG-05: initial MultiSelect contains duplicates and nonexistent indices

- Baseline: `form_widgets.cj:352`.
- Trigger: `MultiSelect(["zero", "one"], selected: [0, 0, -1, 2])`, then toggle cursor 0.
- Impact: `selectedIndices()` exposes nonexistent choices; removing one copy of 0 leaves the same item checked, so one toggle cannot deselect it.
- Baseline evidence: `multiselectInitialSelectionIsASetOfValidIndices` initially returned four entries and still returned three after toggling.
- Fix: retain only valid unique indices, preserving their first-occurrence order.

### WG-06: default FilePicker cannot navigate to its parent

- Baseline: `data_widgets.cj:1027-1041`.
- Trigger: `FilePicker()` defaults to path `"."`; choose the visible `".."` entry or call `parent()`.
- Impact: `parentPath(".")` returns `"."`; selecting parent points to the current directory and `parent()` returns false. Relative `".."` also previously computed the wrong next parent.
- Baseline evidence: `filePickerCanNavigateAboveTheDefaultRelativeDirectory` observed selected path `"."`, false parent navigation, and unchanged path on both attempts.
- Fix: handle relative dot/parent components and trailing dot/slash paths while retaining lexical paths and absolute-root behavior. No symlink resolution was introduced.

### WG-07: a one-row Dialog writes buttons above its assigned area

- Baseline: `command_widgets.cj:347-357`, especially `by = dialogArea.bottom - 2` at line 352.
- Trigger: render Dialog into `Rect(2, 3, 6, 1)`.
- Impact: the border has no body, but button painting still writes row 2, outside the dialog. Four outside cells changed in the regression.
- Baseline evidence: `oneRowDialogDoesNotPaintButtonsAboveItsArea` reported 4 outside changes.
- Fix: skip body/buttons when the border leaves no positive-width, positive-height interior.

### WG-08: zero-height Menu and InlineAlert still paint

- Baseline: `command_widgets.cj:66-74`; `dashboard_widgets.cj:263-273`.
- Trigger: render a titled Menu or InlineAlert into a nonzero-width, zero-height rectangle.
- Impact: title/message writes occur despite the empty region, corrupting another layout region. The combined regression observed six changed cells.
- Baseline evidence: `emptyHeightMenuAndAlertDoNotPaint` reported 6 outside changes.
- Fix: return before painting when either dimension is nonpositive.

### WG-09: Legend treats UTF-8 bytes as display columns

- Baseline: `dashboard_widgets.cj:98-100`.
- Trigger: `Legend([LegendItem("a"), LegendItem("b")], gap: "界")`.
- Impact: three UTF-8 bytes are charged for a two-column gap; the next marker and label shift right and may be prematurely clipped.
- Baseline evidence: `legendUsesDisplayColumnsForUnicodeGaps` found spaces at columns 5 and 7 where `#` and `b` should be.
- Fix: advance by display width and truncate gap painting to remaining columns.

### WG-10: Composer Enter submits a draft instead of accepting completion

- Baseline: `content_widgets.cj:351-359`.
- Trigger: start with `pri`, open completion candidates `print/private`, press Down then Enter.
- Impact: Composer intercepts Enter before TextArea can accept completion, emits a submission for the incomplete draft and clears the editor. In a command/chat host this sends unintended content.
- Baseline evidence: `composerAcceptsCompletionBeforeSubmitting` returned a submission on the first Enter and cleared the value instead of keeping `private` in the editor.
- Fix: while completion is visible, delegate its Enter/Tab/Up/Down/Esc keys to TextArea before composer submit/history handling. The next Enter after acceptance submits the completed draft normally.

### WG-11: a clipped virtual table column overflows its next x position

- Baseline: `data_widgets.cj:461`.
- Trigger: `VirtualTable([TableColumn("A", width: Int64.Max)], 1, ...)` in a four-column viewport.
- Impact: cell text is correctly clipped to four columns, but returning `cx + column.width + 1` raises `OverflowException: add`; even the header cannot finish rendering.
- Before-fix evidence: `clippedTableColumnDoesNotOverflowItsNextPosition` ERROR in `/tmp/termcanvas-audit-logs/widgets-extra-before.log`. The initial widget fixes were present, but this production path was unchanged from the baseline.
- Fix: advance by the clipped width and return the viewport right edge directly when the cell consumes all remaining columns.

### WG-12: HBox/VBox overflow when gaps exceed their viewport

- Baseline: `container_widgets.cj:19,26,46,53`.
- Trigger: three children, `gap: Int64.Max`, in a small positive-size viewport.
- Impact: `gap * (children.size - 1)` raises multiplication overflow. Fixing the product alone would still leave `coordinate += size + gap` vulnerable.
- Before-fix evidence: `oversizedContainerGapsDoNotOverflow` ERROR at HBox's multiplication. It reaches VBox assertions only after HBox is fixed; both implementations contain the same expression and both are covered after the fix.
- Fix: bound the total gap by the viewport before multiplication, and check whether the next gap exhausts remaining space before advancing the coordinate. Zero-sized children and existing remainder distribution semantics are preserved.

## Executable evidence

Regression file: `packages/core/src/audit_20261003_widgets_test.cj`, suite `Audit20261003WidgetsTest`.

- Canonical compiler: Cangjie STS 1.1.3, provided through the repository's SDK wrapper.
- Before implementation changes: 12/12 new cases failed (8 FAILED, 4 ERROR) in `/tmp/termcanvas-audit-logs/core-before.log`; this run used the unmodified production baseline plus new tests.
- After the initial six-file fixes: the root agent's integrated core suite passed 698/698 cases.
- Two additional unchanged-production regressions: 12 widget tests PASS, 2 ERROR, 686 unrelated cases SKIPPED in `/tmp/termcanvas-audit-logs/widgets-extra-before.log`.
- Final widget-only result after both additional fixes: **14 PASS, 0 FAILED, 0 ERROR**, 686 unrelated cases SKIPPED, in `/tmp/termcanvas-audit-logs/widgets-after.log`.
- `git diff --check` passed for the current patch.

Reproduction command from repository root, with the canonical SDK installed:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie-sts-1.1.3 \
  scripts/cangjie_cmd.sh packages/core cjpm test --filter='Audit20261003WidgetsTest.*'
```

The final root report records the integrated core/release-gate result and persistent evidence locations.

## Boundaries and unverified candidates

- Tests execute on Linux. Windows path separators, drive roots and filesystem-specific behavior were not validated by this module's tests; FilePicker's documented simple lexical path behavior remains.
- Arbitrarily mutated public fields, cyclic/deep TreeNode graphs, enormous text allocations and overflow-sized viewport coordinates were not exhaustively exercised.
- Existing behavior that draws a minimum one-row chart bar for zero/negative values was preserved; changing chart semantics was not required to fix scaling overflow.
