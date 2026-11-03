# CI activity

This full-screen example draws an animated CI activity view with simulated
jobs. It does not connect to GitHub or start commands. Use a terminal font with
support for the displayed Unicode symbols.

From the repository root:

```bash
scripts/cangjie_cmd.sh examples/ci_activity cjpm run
```

Press Space to pause or resume, Up/Down to scroll tasks, `n` to cycle through
Unicode, Nerd Font, and ASCII icons, `r` to restart the simulation, and `q` or
Ctrl-C to quit. The status line shows the selected icon set. Nerd Font icons
require an installed Nerd Font; when the terminal reports no Unicode support,
built-in icons fall back to ASCII regardless of the selection. The example uses the terminal's default background, so a
configured terminal background image or transparency can remain visible.

The app passes `TaskActivity` data and an animation frame to the experimental
`core.TaskActivityList` widget. The list combines compact and expanded
`TaskActivityListEntry` values, draws hidden-task counts and adapts its built-in
symbols to terminal capabilities. The app owns the simulation, timer, input,
scroll offset, and task state. The sample uses both count-based and individual
task progress. Expanded rows align elapsed times within 88 columns by default;
`maxHeaderWidth` changes that limit, and `0` uses the full available width.

Terminal captures at 120 × 36 cells: [Unicode](screenshots/ci-unicode-120x36.png) and [ASCII](screenshots/ci-ascii-120x36.png).
