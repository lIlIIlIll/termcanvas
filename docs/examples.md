# Examples

Use this page to choose an example by the part of `cjtui` you want to learn. All
17 current examples are grouped by support and purpose; the links open their
source directories. For the directory-local index and commands, see
[`examples/README.md`](../examples/README.md).

## Before running an example

Run commands from the repository root. Set `CANGJIE_SDK_ROOT` to the canonical
Cangjie SDK used by the repository wrapper:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

Replace `taskpad` with any linked example directory. To build the complete
example set instead of launching one application:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie scripts/build_examples.sh
```

## Recommended applications (8)

These are the best starting points for application-shaped code on the primary
application-owned state → `App`/`update` → immediate `Widget` path.

- [`taskpad`](../examples/taskpad/): task-board workflow with input, `KeyMap`,
  command palette, and toasts.
- [`form_studio`](../examples/form_studio/): form workflow with focus policy,
  paste, controls, and status feedback.
- [`ops_dashboard`](../examples/ops_dashboard/): real-time dashboard with ticks,
  timers, progress, charts, logs, and status bars.
- [`data_browser`](../examples/data_browser/): data and file browser with virtual
  table, tree, file picker/dialog, and paginator.
- [`markdown_studio`](../examples/markdown_studio/): Markdown editing with
  completion, preview, and outline.
- [`command_center`](../examples/command_center/): command runtime with async
  tasks, timers, dialogs, spinner, and toasts.
- [`assistant_console`](../examples/assistant_console/): transcript, composer,
  activity timeline, and request/decision dialogs.
- [`oh_my_pi_skin`](../examples/oh_my_pi_skin/): terminal-native skin with canvas,
  transcript, composer, palette, status line, and timed regions.

## Experimental applications (2)

These applications exercise capabilities whose compatibility tier is
`EXPERIMENTAL`; they are not alternate application architectures.

- [`btm_clone`](../examples/btm_clone/): nontrivial primary-model application
  with application-owned state, core timers, async completions, focus/layout,
  regional dirty rendering, process interaction, and deterministic headless
  proof.
- [`media_gallery`](../examples/media_gallery/): direct terminal media placement,
  `DocumentLine.image` integration, protocol fallback, and capability reporting.

## Feature demonstrations (6)

Use these when a specific input, rendering, game, or terminal extension is the
next concept you need.

- [`arcade`](../examples/arcade/): held-key and tick-driven `Canvas` application
  with resize fallback and metrics.
- [`crystal_caves`](../examples/crystal_caves/): side-scrolling game with tile
  markers, sensors, physics, animation, and camera scrolling.
- [`debug_lab`](../examples/debug_lab/): terminal capabilities, keyboard
  options, mouse/focus events, metrics, and debug overlay.
- [`game_demo`](../examples/game_demo/): farm-sim game with `Canvas`, stores,
  physics, tiles, sprites, saves, and headless smoke.
- [`gif_ascii`](../examples/gif_ascii/): ffmpeg-backed ASCII, half-block, or
  braille animation with playback and display controls.
- [`terminal_lab`](../examples/terminal_lab/): PTY, terminal transcript, and diff
  integration lab.

## Proof workload (1)

- [`game_pressure_suite`](../examples/game_pressure_suite/): six-category
  deterministic tick, input, and render pressure workload.

## Focused commands

Create a new example scaffold from the repository root:

```bash
scripts/new_example.sh my_example
```

Run Markdown Studio with its built-in Markdown sample. The editor and preview
both color the `main`, `Int64`, and `0` tokens in its `cj` code block:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run
```

The example does not open a file argument. Paste or edit Markdown in its editor;
source and preview colors update together. Fenced code recognizes these AST
language names (case-insensitively, after ASCII whitespace trim):

| Language | Fence names |
| --- | --- |
| Cangjie | `cj`, `cangjie` |
| C | `c`, `h` |
| C++ | `cpp`, `c++`, `cxx`, `cc`, `hpp`, `hxx` |
| JavaScript | `js`, `javascript`, `mjs`, `cjs` |
| TypeScript | `ts`, `typescript` |
| Python | `py`, `python`, `python3` |
| JSON | `json` |
| Shell | `sh`, `bash`, `shell`, `zsh` |

Names such as `go`, `jsonc`, `jsx`, and `tsx`, fences with no language, and
indented code remain a single code color. Colors indicate lexical tokens
(strings, comments, numbers, keywords, types), not semantic diagnostics or
function definitions.

To add an experimental lexer, save this UTF-8 file as `palette.syntax` in the
repository root:

```text
syntax 1
language workflow
aliases flow
keywords task stage
types Pipeline
numbers decimal
line-comment "#"
block-comment "/*" "*/" nested
string "\"" "\"" "\\" single
style keyword #12ab34 bold
style type indexed:45
end
```

Launch Studio with that file (or add `--vim` before the config option):

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/markdown_studio cjpm run \
    --run-args="--syntax-config=../../palette.syntax"
```

Paste a `workflow` fenced block containing `task Pipeline` into the editor.
`task` appears bold green and `Pipeline` uses palette index 45 in both the
source and preview. `flow` is an alias. The config is read once at startup:
edit the file and restart Studio to apply changes. Without the option, only
the built-in languages above are colored.

The first non-comment line must be `syntax 1`. Each `language NAME` starts
a new lexer; `end` closes it. To retain a built-in lexer and add words or
styles, use `extend cj` instead. To discard its built-in token rules, use
`language cj replace`. Built-in aliases resolve to the same configured
language. Each declaration must occur between a language header and `end`:

| Declaration | Behavior |
| --- | --- |
| `aliases NAME...` | Additional fence names for this language. |
| `keywords WORD...`, `types WORD...`, `literals WORD...` | Exact identifier matches; literals use the keyword token kind. |
| `line-comment OPEN` | Colors through the physical line ending. |
| `block-comment OPEN CLOSE flat` or `nested` | Colors through the closer; `nested` permits matching openers inside. |
| `string OPEN CLOSE ESCAPE single` or `multi` | `single` ends at the physical line ending; an empty quoted escape disables escaping. |
| `numbers PROFILE` | `none`, `decimal`, `cj`, `c`, `cpp`, `js`, `ts`, `py`, or `json`. |
| `style KIND COLOR [MODIFIER...]` | Override `keyword`, `type`, `string`, `number`, `comment`, `directive`, `variable`, or `property`. |

Colors are `inherit`, `black`, `red`, `green`, `yellow`, `blue`,
`magenta`, `cyan`, `white`, `#RRGGBB`, or `indexed:0` through
`indexed:255`. Modifiers are `bold`, `italic`, `underline`, and
`reversed`; each may appear once. Quoted arguments permit `\`, `\"`,
`\n`, `\r`, and `\t` escapes. Lines may use LF, CRLF, or CR;
leading `#` comments and a UTF-8 BOM are accepted. Invalid input prints a
line-numbered error and exits before the UI starts. Configuration is limited
to 256 KiB, 64 languages, 64 aliases and delimiters per language, and 4096
words per language. `extend` retains the built-in delimiter and number
rules, so use `replace` when those need to change.

To opt into the limited Vim editor policy, pass `--vim` as a run argument:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie scripts/cangjie_cmd.sh examples/markdown_studio cjpm run --run-args=--vim
```

The status bar starts in `NORMAL`. Press `i` to edit, `Esc` to return to Normal,
`F2` to switch between editor and preview, and `Ctrl-C` to quit. In Insert,
`F3` requests completion. Normal supports motion (`h/j/k/l`, `w/b`, `0/$`,
`gg/G`), insert entry (`i/a/I/A/o/O`), `x`, `dd`, `u`, and `Ctrl-r`.
On terminals that support DECSCUSR cursor styling, Normal uses a steady block
and Insert a steady bar. Preview and exit restore the terminal default; terminals
that ignore cursor styling still show the mode in the status bar.
Without `--vim`, the original two-caret editing and shortcuts remain active.

Play an ffmpeg-decodable image, GIF, or video with `gif_ascii`:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/media-file --width 80 --height 32 --fps 12"
```

Braille mode provides higher effective sample density per terminal cell:

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/gif_ascii cjpm run \
    --run-args="/path/to/video.mp4 --width 120 --height 50 --fps 15 --mode braille --color --threshold 110"
```

`gif_ascii` runtime controls include `space` to pause, `+/-` to zoom, `[]` to
change speed, and `,/.` or `<>` to adjust threshold.
