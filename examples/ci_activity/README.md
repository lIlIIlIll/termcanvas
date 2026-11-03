# CI activity

This full-screen example draws an animated CI activity view with simulated
jobs. It does not connect to GitHub or start commands. Use a terminal font with
support for the displayed Unicode symbols.

From the repository root:

```bash
scripts/cangjie_cmd.sh examples/ci_activity cjpm run
```

Press Space to pause or resume, `r` to restart the simulation, and `q` or
Ctrl-C to quit. The example uses the terminal's default background, so a
configured terminal background image or transparency can remain visible.

The app passes `TaskActivity` data and an animation frame to the experimental
`core.TaskActivityView` widget. The app owns the simulation, timer, input, and
task state. The sample uses both count-based and individual task progress.
