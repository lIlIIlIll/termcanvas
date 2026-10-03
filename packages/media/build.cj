import std.process.*

@When[os == "Windows"]
func buildMediaFixture(): Int64 {
    launch("cjc.exe", ["testdata/media_tool.cj", "-o", "testdata/media_tool.exe"]).wait()
}

@When[os != "Windows"]
func buildMediaFixture(): Int64 {
    launch("cjc", ["testdata/media_tool.cj", "-o", "testdata/media_tool"]).wait()
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "pre-test" => buildMediaFixture()
        case _ => 0
    }
}
