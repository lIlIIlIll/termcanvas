package core

import std.collection.ArrayList

@FastNative
@When[os == "Windows"]
foreign func PeekConsoleInputW(handle: CPointer<Unit>, records: CPointer<UInt32>, count: UInt32, readCount: CPointer<UInt32>): Int32

@FastNative
@When[os == "Windows"]
foreign func ReadConsoleInputW(handle: CPointer<Unit>, records: CPointer<UInt32>, count: UInt32, readCount: CPointer<UInt32>): Int32

@FastNative
@When[os == "Windows"]
foreign func GetFileType(handle: CPointer<Unit>): UInt32

@FastNative
@When[os == "Windows"]
foreign func PeekNamedPipe(handle: CPointer<Unit>, buffer: CPointer<Unit>, size: UInt32, bytesRead: CPointer<UInt32>, available: CPointer<UInt32>, remaining: CPointer<UInt32>): Int32

@FastNative
@When[os == "Windows"]
foreign func ReadFile(handle: CPointer<Unit>, buffer: CPointer<Unit>, size: UInt32, bytesRead: CPointer<UInt32>, overlapped: CPointer<Unit>): Int32

@FastNative
@When[os == "Windows"]
foreign func GetLastError(): UInt32

// Console input consists of UTF-16 code units. Keep a high surrogate across
// native read boundaries and expose UTF-8 to the common incremental parser.
class ConsoleUtf16Decoder {
    private var high: UInt32 = 0u32

    func push(unit: UInt32): Array<Byte> {
        var text = ""
        if (high != 0u32) {
            if (unit >= 0xDC00u32 && unit <= 0xDFFFu32) {
                let point = 0x10000u32 + ((high - 0xD800u32) << 10) + unit - 0xDC00u32
                high = 0u32
                return Rune(point).toString().toArray()
            }
            text = "\u{FFFD}"
            high = 0u32
        }
        if (unit >= 0xD800u32 && unit <= 0xDBFFu32) { high = unit }
        else if (unit >= 0xDC00u32 && unit <= 0xDFFFu32) { text += "\u{FFFD}" }
        else { text += Rune(unit).toString() }
        text.toArray()
    }
}

@When[os == "Windows"]
class WindowsConsoleInput {
    private let decoder = ConsoleUtf16Decoder()
    private var pending: Array<Byte> = []
    private var pendingIndex: Int64 = 0
    private var repeats: Int64 = 0

    func readAvailable(maxBytes: Int64): Array<Byte> {
        if (maxBytes <= 0) { return [] }
        let input = unsafe { GetStdHandle(STD_INPUT_HANDLE) }
        let kind = unsafe { GetFileType(input) }
        if (kind != 2u32) { return readRedirected(input, kind, maxBytes) }
        let bytes = ArrayList<Byte>()
        // INPUT_RECORD is 20 bytes with four-byte alignment on Win32/Win64.
        let record = Array<UInt32>(5, repeat: 0u32)
        let count = Array<UInt32>(1, repeat: 0u32)
        var inspected: Int64 = 0
        while (bytes.size < maxBytes && inspected < 4096) {
            if (repeats > 0) {
                bytes.add(pending[pendingIndex])
                pendingIndex++
                if (pendingIndex == pending.size) { pendingIndex = 0; repeats-- }
                continue
            }
            var available = false
            unsafe {
                let raw = acquireArrayRawData(record)
                let readCount = acquireArrayRawData(count)
                // A console handle can signal for key-up or resize records.
                // Read those records too; a CRT read after such a signal can
                // block forever waiting for text that does not exist.
                if (PeekConsoleInputW(input, CPointer<UInt32>(raw.pointer), 1u32,
                    CPointer<UInt32>(readCount.pointer)) != 0 && count[0] > 0u32) {
                    available = ReadConsoleInputW(input, CPointer<UInt32>(raw.pointer), 1u32,
                        CPointer<UInt32>(readCount.pointer)) != 0 && count[0] > 0u32
                }
                releaseArrayRawData(readCount)
                releaseArrayRawData(raw)
            }
            if (!available) { break }
            inspected++
            // VT input mode converts navigation/protocol input to character
            // records. Key-up and non-key records carry no stream bytes;
            // resize is observed independently through the terminal driver.
            if ((record[0] & 0xFFFFu32) != 1u32 || record[1] == 0u32) { continue }
            let unit = record[3] >> 16
            if (unit == 0u32) { continue }
            pending = decoder.push(unit)
            pendingIndex = 0
            repeats = if (pending.isEmpty()) { 0 } else { max(Int64(1), Int64(record[2] & 0xFFFFu32)) }
        }
        bytes.toArray()
    }

    private func readRedirected(input: CPointer<Unit>, kind: UInt32, maxBytes: Int64): Array<Byte> {
        if (kind != 1u32 && kind != 3u32) { return [] }
        var capacity = min(maxBytes, Int64(4096))
        let count = Array<UInt32>(1, repeat: 0u32)
        if (kind == 3u32) {
            unsafe {
                let raw = acquireArrayRawData(count)
                let success = PeekNamedPipe(input, CPointer<Unit>(), 0u32, CPointer<UInt32>(),
                    CPointer<UInt32>(raw.pointer), CPointer<UInt32>())
                releaseArrayRawData(raw)
                if (success == 0 || count[0] == 0u32) { return [] }
            }
            capacity = min(capacity, Int64(count[0]))
        }
        let bytes = Array<Byte>(capacity, repeat: 0)
        unsafe {
            let raw = acquireArrayRawData(bytes)
            let readCount = acquireArrayRawData(count)
            let success = ReadFile(input, CPointer<Unit>(raw.pointer), UInt32(capacity),
                CPointer<UInt32>(readCount.pointer), CPointer<Unit>())
            // ERROR_MORE_DATA on a message pipe still delivered this prefix.
            // Capture the thread-local error before any other native call.
            let error = if (success == 0) { GetLastError() } else { 0u32 }
            releaseArrayRawData(readCount)
            releaseArrayRawData(raw)
            if (success == 0 && error != 234u32) { return [] }
        }
        bytes[..Int64(count[0])]
    }
}
