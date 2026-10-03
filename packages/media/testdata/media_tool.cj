package media_tool

@FastNative
foreign func write(fd: Int32, buffer: CPointer<Unit>, size: UIntNative): IntNative

func output(bytes: Array<Byte>): Int64 {
    unsafe {
        let raw = acquireArrayRawData(bytes)
        let written = write(1, CPointer<Unit>(raw.pointer), UIntNative(bytes.size))
        releaseArrayRawData(raw)
        if (Int64(written) != bytes.size) { return 2 }
    }
    0
}

// Emit binary RGBA directly, without a shell or codec. The still-image adapter
// passes media-tool arguments that GNU printf ignores but BSD printf rejects,
// so every platform uses this fixture for the same exact-byte assertions.
main(args: Array<String>): Int64 {
    if (args.size == 0) { return 1 }
    if (args[0] == "x") { return output([120u8]) }
    var source = args[0]
    if (args.size > 3 && args[0] == "-v") { source = args[3] }
    if (source == "partial-frame") { return output([120u8]) }
    var count: Int64 = 0
    var pixel: Array<Byte> = [255, 255, 255, 255]
    if (source == "one-frame") { count = 1 }
    else if (source == "many-frames") { count = 257 }
    else if (source == "selected-frame" || source.startsWith("\\377")) {
        count = 128
        pixel = [255, 0, 0, 255]
        for (arg in args) {
            if (arg.contains("select=eq(n\\,7)")) { pixel = [0, 0, 255, 255] }
        }
    } else { return 1 }
    let bytes = Array<Byte>(count * 4, repeat: 0)
    for (index in 0..bytes.size) { bytes[index] = pixel[index % 4] }
    output(bytes)
}
