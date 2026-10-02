package markdown_studio

import std.env.*
import std.fs.*

// Application-level I/O boundary. The session owns flush/close, conflict
// validation and cleanup; a writer must never modify the target before commit.
interface StudioFileWriter {
    public func write(file: File, text: String): Unit
    public func commit(temporary: Path, target: Path, overwrite: Bool): Unit
}

class NativeStudioFileWriter <: StudioFileWriter {
    public func write(file: File, text: String): Unit { file.write(text.toArray()) }
    public func commit(temporary: Path, target: Path, overwrite: Bool): Unit {
        rename(temporary, to: target, overwrite: overwrite)
    }
}

// The file session stores the last loaded/saved text for exact conflict
// detection; it is not editor undo history. A save is explicit O(document)
// work. The editor itself retains its PieceTableTextModel across saves.
class StudioFileSession {
    let path: Path
    private var baseline: ?String
    private let writer: StudioFileWriter

    init(rawPath: String, writer: StudioFileWriter) {
        if (rawPath.isEmpty() || rawPath.contains("\u{0}")) {
            throw IllegalArgumentException("file path must be nonempty and contain no NUL")
        }
        let input = Path(rawPath)
        let absolute = if (input.isAbsolute()) { input.normalize() } else { getWorkingDirectory().join(input).normalize() }
        // Resolve the existing parent once so a cwd change cannot redirect a
        // later save. Missing files are allowed, missing directories are not.
        path = canonicalize(absolute.parent).join(absolute.fileName)
        this.writer = writer
        baseline = studioReadDocument(path)
    }

    func loadedText(): String {
        match (baseline) { case Some(text) => text; case None => "" }
    }

    func save(text: String): Unit {
        validateUnchanged()
        let temporary = File.createTemp(path.parent)
        var temporaryPath: ?Path = None
        var closed = false
        var committed = false
        try {
            let name = temporary.info.path
            temporaryPath = Some(name)
            writer.write(temporary, text)
            temporary.flush()
            if (temporary.length != text.size) {
                throw IllegalStateException("temporary file write was incomplete")
            }
            temporary.close()
            closed = true
            // Recheck after the potentially slow write, immediately before
            // replacement. A mismatch never overwrites the external version.
            validateUnchanged()
            writer.commit(name, path, baseline.isSome())
            committed = true
            // No fallible filesystem work follows commit: reporting a failed
            // save after a successful replacement would mislead the editor.
            baseline = Some(text)
        } finally {
            if (!closed) { try { temporary.close() } catch (_: Exception) {} }
            if (!committed) {
                if (let Some(name) <- temporaryPath) {
                    try { _ = removeIfExists(name) } catch (_: Exception) {}
                }
            }
        }
    }

    private func validateUnchanged(): Unit {
        let current = studioReadDocument(path)
        let matches = match ((baseline, current)) {
            case (None, None) => true
            case (Some(old), Some(now)) => old == now
            case _ => false
        }
        if (!matches) { throw IllegalStateException("file changed on disk; original preserved; reopen before saving") }
        if (current.isSome()) {
            let info = FileInfo(path)
            if (info.isReadOnly() || !info.canWrite()) {
                throw IllegalStateException("file is read-only; original preserved")
            }
        }
    }
}

// std.fs FileInfo properties are live queries, so capture scalar metadata
// before reading and compare afterward. Existing nonregular files and links
// must never be treated as an empty new document.
func studioReadDocument(path: Path): ?String {
    if (!exists(path)) {
        // Some platforms' exists follows links. A dangling link must still
        // be rejected instead of becoming a new empty document.
        let dangling = try { FileInfo(path).isSymbolicLink() } catch (_: FSException) { false }
        if (dangling) { throw IllegalArgumentException("document must not be a symbolic link") }
        return None
    }
    let info = FileInfo(path)
    if (info.isSymbolicLink() || !info.isRegular()) {
        throw IllegalArgumentException("document must be a regular file, not a symbolic link or directory")
    }
    let size = info.size
    let modified = info.lastModificationTime
    let created = info.creationTime
    let file = File(path, OpenMode.Read)
    let bytes = try {
        if (file.length != size) { throw IllegalStateException("file changed while opening") }
        let buffer = Array<Byte>(size, repeat: 0)
        let chunk = Array<Byte>(65536, repeat: 0)
        var offset: Int64 = 0
        while (true) {
            let count = file.read(chunk)
            if (count == 0) { break }
            if (count > size - offset) { throw IllegalStateException("file changed while reading") }
            for (index in 0..count) { buffer[offset + index] = chunk[index] }
            offset += count
        }
        if (offset != size) { throw IllegalStateException("file changed while reading") }
        buffer
    } finally { file.close() }
    let after = FileInfo(path)
    if (after.isSymbolicLink() || !after.isRegular() || after.size != size ||
        after.lastModificationTime != modified || after.creationTime != created) {
        throw IllegalStateException("file changed while reading")
    }
    try { Some(String.fromUtf8(bytes)) }
    catch (_: IllegalArgumentException) { throw IllegalArgumentException("document is not valid UTF-8; original preserved") }
}
