# Capture the visual matrix

Use this fixture to capture declared widget and primitive states in a real
Linux terminal. The [inventory](../../scripts/visual_inventory.json) is not a
complete list of the project. `python3 scripts/visual_inventory.py` reports
conservatively discovered missing subjects and returns a failure while project
coverage and state completeness remain unverified.

## Prepare a controlled build

Run these commands from the repository root. You need Python 3.11 or later, Cangjie STS
1.2.0, native C build tools, Sway, Foot, Grim, `swaymsg`, `fc-match`, a UTF-8
locale, Linux pidfd support, and a writable `XDG_RUNTIME_DIR`. Set
`CANGJIE_SDK_ROOT` to the SDK and `MARKDOWN_SOURCE` to a local markdown source
checkout for the fixture's declared dependency. The build records that checkout
but does not verify that it matches the dependency's Git tag.

Create a private work directory on a disk-backed filesystem. The build output
must not already exist or be inside either source tree.

```sh
: "${CANGJIE_SDK_ROOT:?Set the Cangjie 1.2.0 SDK root}"
: "${MARKDOWN_SOURCE:?Set the local markdown source directory}"
mkdir -p "$HOME/.cache/termcanvas"
VISUAL_ROOT="$(mktemp -d "$HOME/.cache/termcanvas/visual.XXXXXXXX")"
export TMPDIR="$VISUAL_ROOT" TMP="$VISUAL_ROOT" TEMP="$VISUAL_ROOT" CANGJIE_SDK_ROOT
BUNDLE="$VISUAL_ROOT/bundle"
RUN="$VISUAL_ROOT/run"
python3 scripts/visual_matrix_build.py \
  --source "$PWD" --markdown "$MARKDOWN_SOURCE" \
  --work "$BUNDLE" --sdk "$CANGJIE_SDK_ROOT"
SOURCE_SHA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_snapshot_sha256"])' "$BUNDLE/build-record.json")"
```

The bundle contains `source.tar`, `source/`, `target/release/bin/main`, and
`build-record.json`. The record is unsigned local consistency evidence. It does
not prove a Git revision, third-party source authenticity, or the identity of
all dynamic libraries.

## Capture and resume

Capture one case using the scripts and launcher from the bundle. The SDK wrapper
sets the runtime environment used by the renderer. The source SHA below is the
snapshot digest from the build record, not a commit ID.

```sh
python3 "$BUNDLE/source/scripts/native_sdk.py" --run "$PWD" -- \
  python3 "$BUNDLE/source/scripts/visual_matrix_runner.py" \
  --launcher "$BUNDLE/source/examples/visual_matrix/launch.py" \
  --renderer "$BUNDLE/target/release/bin/main" \
  --source-archive "$BUNDLE/source.tar" \
  --build-record "$BUNDLE/build-record.json" \
  --source-revision "$SOURCE_SHA" --source-kind dirty-worktree \
  --output "$RUN" --subject core.Button --state focused \
  --theme indigo --glyph unicode --color truecolor \
  --terminal 80x24 --widget-size 16x3 --limit 1
```

`$RUN/report.json` reports `partial` until all declared cases are captured.
The run stores source and binary hashes, tool and font information, and a
random nonce. Repeat the same command to resume a run with matching inputs.
Each output directory has its own nonce, so reviews from another run do not
apply even if the images match. Failed or damaged cases require
`--retry-failed`. After an interruption or failure, inspect the local processes
and pass `--ack-interrupted-cleanup` before continuing. The tool cannot guarantee
that detached or uninterruptible descendants have exited.

Version 2 cases record the requested `allocation_cells`, `target_width`, and
`expected_effective_rect`. The renderer reports the rectangle passed to the
drawing API; it is not an independent pixel measurement. A case that cannot
reach its target width is recorded at the smaller size and does not count as
coverage of that target. Legacy version 1 cases retain their IDs but lack
verified geometry.

Color and glyph settings are application overrides in Foot. They do not verify
an actual 16-color or monochrome terminal. The recorded fontconfig candidate
does not prove which font or fallback rendered each glyph.

## Record and check reviews

After a model reviews a captured image and reports a pass, record its judgment
against the case and run. The reviewer label identifies the supplied record;
it does not authenticate a reviewer or prove that the image was observed.

```sh
CASE_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["captures"][0]["case_id"])' "$RUN/evidence.json")"
python3 "$BUNDLE/source/scripts/visual_evidence.py" review-create "$RUN" \
  --case "$CASE_ID" --kind model --reviewer reviewer-label --verdict pass
python3 "$BUNDLE/source/scripts/visual_evidence.py" review-summary "$RUN"
```

Use `--verdict fail --finding 'description'` to record a finding. To import a
report in the tool's review format, run `review-import "$RUN" "$REVIEW_REPORT"`
with the same `visual_evidence.py` command. See `review-import --help` for the
arguments. The JSON object has a nonempty `reviews` list. Each entry contains
`case_id`, `kind`, `image_sha256`, `source_sha`, `reviewer`, `verdict`,
`findings`, and `run_identity_sha256`. Imported reports must match the current
image, source, and run.

The runner retains current review records when it resumes and excludes stale
ones. `report.json` contains a snapshot from the last capture run; use
`review-summary` for current counts. The summary is not a visual audit and
never marks the run ready for delivery. The declared-scope audit requires a
model review for every case. High-risk cases also require an independent review
with a different reviewer label. Labels alone do not prove independence.

Expand and check the complete declared matrix with:

```sh
python3 "$BUNDLE/source/scripts/visual_evidence.py" expand \
  "$BUNDLE/source/scripts/visual_inventory.json" "$VISUAL_ROOT/matrix.json"
python3 "$BUNDLE/source/scripts/visual_evidence.py" check \
  "$BUNDLE/source/scripts/visual_inventory.json" "$VISUAL_ROOT/matrix.json" \
  "$RUN/evidence.json" "$RUN" --declared-scope --require-local-build-record
```

The check fails for the one-case example because the remaining captures and
reviews are missing. A successful declared-scope check does not establish
project-wide or cross-platform coverage.

## Run fixture probes

Run the color probe from the bundle against the renderer built from that same
bundle. It checks emitted ANSI bytes through a PTY.

```sh
export TERMCANVAS_MATRIX_TEST_BINARY="$BUNDLE/target/release/bin/main"
python3 "$BUNDLE/source/scripts/native_sdk.py" --run "$PWD" -- \
  python3 "$BUNDLE/source/examples/visual_matrix/test_color_output.py"
```

`scripts/visual_inventory_smoke.py <renderer>` is a separate working-tree
helper. It exercises declared states at zero and representative sizes and
checks frame completion, not image quality. Before comparing its results with
a bundle, verify that the working-tree fixture and inventory match that bundle.
The helper is not included in the controlled build inputs. Neither probe
verifies the terminal's actual display capabilities.
