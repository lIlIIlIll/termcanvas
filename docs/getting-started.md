# Getting Started

Termcanvas 0.0.1 builds terminal applications in Cangjie. The application owns its
state, `update(Event)` returns commands and redraw requests, and `render(Frame)`
draws the current state. Start with a source checkout and the pinned Cangjie SDK
listed in [Versioning and Compatibility](versioning.md).

Linux and macOS builds also need a C compiler (`cc`, GCC or Clang) and `ar`
(binutils or Xcode Command Line Tools). The normal `cjpm build`/`test` command
automatically builds the small POSIX process-launch library through the core
package's build hook, including when core is a path dependency of an external
application. Windows builds do not require a C compiler. Do not use
`--skip-script` on a clean checkout: the native archive must exist before linking.

## Create an independent application

Your application does not need to live inside this repository. From the
termcanvas checkout, generate a new directory:

```sh
python3 scripts/new_example.py my_console --output /path/to/my_console \
  --library-root /path/to/termcanvas
```

The generator copies the basic application and an executable regression test.
It writes path dependencies for `core` and `cjtui_testing` relative to the new
application. Use `--dependency-path absolute` if the library checkout has a
fixed installation path. On Windows, dependencies on another drive use an
absolute path automatically. Paths containing spaces and quotes are encoded as
valid TOML strings. An existing destination is always preserved.

For a repository example, the shorter form remains available:

```sh
python3 scripts/new_example.py my_console
# Linux/macOS compatibility wrapper:
scripts/new_example.sh my_console
```

This creates `examples/my_console`. `--library-root` selects the source checkout
whose packages are used; it is not a registry download or a bundled library copy.
Keep the generated dependency paths valid when moving either directory.

## Build, test, and run

Set `CANGJIE_SDK_ROOT` to your installed SDK. The native wrapper sets compiler,
package manager, and runtime library paths on Linux, macOS, and Windows:

```sh
export CANGJIE_SDK_ROOT=/path/to/cangjie
python3 /path/to/termcanvas/scripts/native_sdk.py --run /path/to/my_console -- cjpm build
python3 /path/to/termcanvas/scripts/native_sdk.py --run /path/to/my_console -- cjpm test
python3 /path/to/termcanvas/scripts/native_sdk.py --run /path/to/my_console -- cjpm run
```

In PowerShell use `$env:CANGJIE_SDK_ROOT = "C:\path\to\cangjie"` and `python`
instead of `python3` if that is the installed interpreter command. The paths
passed to `--run` may be absolute or relative.

The sample displays a count. Press `+` to increment it and `q` or Ctrl-C to exit.
Its `--headless-smoke` mode also supports noninteractive startup verification:

```sh
python3 /path/to/termcanvas/scripts/native_sdk.py --run /path/to/my_console -- cjpm run -- --headless-smoke
```

You can run the unchanged template directly by using
`templates/basic_app` as the working directory.

## Understand the application

The generated `DemoApp` separates state and effects:

```cangjie
class DemoApp {
    var count: Int64 = 0

    func update(event: Event): UpdateResult {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.Char(r'+') =>
                    UpdateResult.withCommand(Command.Message("inc"))
                case KeyCode.Char(r'q') | KeyCode.CtrlC => UpdateResult.exit()
                case _ => UpdateResult.unchanged()
            }
            case Event.Message("inc") => count++; UpdateResult.next()
            case Event.Resize(_) => UpdateResult.next()
            case _ => UpdateResult.unchanged()
        }
    }

    func render(frame: Frame): Unit {
        frame.renderWidget(Paragraph("count: ${count}"), frame.area)
    }
}
```

Start the interactive loop with
`App().runWithCommands({ frame => app.render(frame) }, { event => app.update(event) })`.
Keep persistent selection, editor and application state on the application;
constructing a widget each frame does not create a second event loop.

## Verify behavior

The generated `main_test.cj` imports the supported `cjtui_testing` package:

```cangjie
let app = DemoApp()
let report = TestScenario().key(KeyEvent(KeyCode.Char(r'+')))
    .resize(32, 8).tick().run(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
@Expect(report.passed)
@Expect(app.count, 1)
@Expect(report.lastSnapshot().contains("count: 1"))
```

This drives the real update/command/render path and captures frames. You do not
need repository-only `HeadlessScript`, `AppTestRunner`, or fake runtime types.
See [Downstream Testing](downstream-testing.md) for the public contract and
native-terminal verification boundaries.

## Next steps

- [Examples](examples.md): choose among forms, file/data browsers, Markdown,
  monitoring, assistant interfaces, games and media demonstrations.
- [App Runtime](app-runtime.md): command ordering, timers and redraws.
- [Widgets](widgets.md), [Layout](layout.md), and [Events](events.md): compose the UI.
- [API Overview](api.md): check the compatibility tier of advanced APIs.
- `python3 scripts/test_downstream_app.py`: independently generate, build, test,
  and run a clean application outside the repository; used by native CI.
