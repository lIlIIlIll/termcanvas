import std.fs.*
import std.process.*

@When[os != "Windows"]
func buildNativeSpawn(): Int64 {
    launch("/bin/sh", ["native/build.sh"]).wait()
}

@When[os == "Windows"]
func buildNativeSpawn(): Int64 {
    // The POSIX implementation is excluded on Windows. An empty portable ar
    // archive satisfies cjpm's transitive FFI dependency without a C compiler.
    if (!exists("native/build")) { Directory.create("native/build", recursive: true) }
    File.writeTo("native/build/libtermcanvas_posix.a", "!<arch>\n".toArray())
    0
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "pre-build" | "pre-test" | "pre-bench" | "pre-run" => buildNativeSpawn()
        case _ => 0
    }
}
