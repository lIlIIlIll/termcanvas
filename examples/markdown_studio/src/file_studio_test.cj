package markdown_studio

import core.*
import std.env.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@When[os != "Windows"]
import std.posix.symlink

class FailingStudioWriter <: StudioFileWriter {
    public func write(file: File, text: String): Unit {
        file.write("partial".toArray())
        throw Exception("injected write failure")
    }
    public func commit(temporary: Path, target: Path, overwrite: Bool): Unit {
        throw Exception("must not commit failed writes")
    }
}

class ConflictingStudioWriter <: StudioFileWriter {
    let target: String
    init(target: String) { this.target = target }
    public func write(file: File, text: String): Unit {
        file.write(text.toArray())
        File.writeTo(target, "external edit".toArray())
    }
    public func commit(temporary: Path, target: Path, overwrite: Bool): Unit {
        rename(temporary, to: target, overwrite: overwrite)
    }
}

class FailingStudioCommit <: StudioFileWriter {
    public func write(file: File, text: String): Unit { file.write(text.toArray()) }
    public func commit(temporary: Path, target: Path, overwrite: Bool): Unit {
        @Expect(String.fromUtf8(File.readFrom(temporary)), "local original")
        @Expect(String.fromUtf8(File.readFrom(target)), "original")
        throw Exception("injected rename failure")
    }
}

class FailingStudioClipboard <: Clipboard {
    public func getText(): String { "must not paste this" }
    public func setText(text: String): Unit {}
    public func capabilities(): ClipboardCapabilities { ClipboardCapabilities(false, true, "test-readonly") }
    public func readText(): ClipboardResult {
        ClipboardResult(ClipboardStatus.Unsupported, message: "reader unavailable", backend: "test-readonly")
    }
    public func writeText(text: String): ClipboardResult {
        ClipboardResult(ClipboardStatus.Failed, message: "copy failed", backend: "test-readonly")
    }
}

@Test
class MarkdownStudioFileRegressionTest {
    @TestCase
    func positionalPathLoadsRealUtf8AndSaveCommitsCurrentEditor(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/note.md"
        try {
            File.writeTo(path, "# 真实文件\n".toArray())
            var pathAccepted = false
            try {
                let (useVim, _, _, _) = studioOptions(["--vim", path])
                pathAccepted = useVim
            } catch (_: IllegalArgumentException) {}
            @Expect(pathAccepted)
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard())
            @Expect(app.editor.value, "# 真实文件\n")
            @Expect(!app.isDirty())
            app.editor.setCarets([TextAreaCaret(app.editor.value.size)])
            _ = app.update(Event.Paste("saved body\n"))
            @Expect(app.isDirty())
            _ = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r's'), modifiers: KeyModifier(ctrl: true))))
            @Expect(String.fromUtf8(File.readFrom(path)), "# 真实文件\nsaved body\n")
            @Expect(!app.isDirty())
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func missingPathCreatesAnEmptyDocumentAndRefusesAConcurrentCreator(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/new.md"
        try {
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard())
            @Expect(app.editor.value, "")
            _ = app.update(Event.Paste("local"))
            File.writeTo(path, "external".toArray())
            @Expect(!app.saveFile())
            @Expect(String.fromUtf8(File.readFrom(path)), "external")
            @Expect(app.isDirty())
            @Expect(app.status.contains("changed"))
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func writeFailureKeepsOriginalAndDirtyEditor(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/safe.md"
        try {
            File.writeTo(path, "original".toArray())
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard(), writer: FailingStudioWriter())
            app.editor.setCarets([TextAreaCaret(0)])
            _ = app.update(Event.Paste("local "))
            @Expect(!app.saveFile())
            @Expect(String.fromUtf8(File.readFrom(path)), "original")
            @Expect(app.editor.value, "local original")
            @Expect(app.isDirty())
            @Expect(app.status.contains("injected write failure"))
            @Expect(Directory.readFrom(directory).size, 1)
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func externalEditDuringTemporaryWriteIsDetectedBeforeRename(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/race.md"
        try {
            File.writeTo(path, "original".toArray())
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard(), writer: ConflictingStudioWriter(path))
            _ = app.update(Event.Paste("local"))
            @Expect(!app.saveFile())
            @Expect(String.fromUtf8(File.readFrom(path)), "external edit")
            @Expect(app.isDirty())
            @Expect(app.status.contains("changed"))
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func dirtyFileRequiresExplicitDiscardToQuit(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/unsaved.md"
        try {
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard())
            _ = app.update(Event.Paste("unsaved"))
            let interrupted = app.update(Event.KeyDown(KeyEvent(KeyCode.CtrlC)))
            match (interrupted.flow) { case ControlFlow.Continue => (); case _ => @Expect(false) }
            @Expect(app.status.contains("unsaved"))
            let first = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'), modifiers: KeyModifier(ctrl: true))))
            match (first.flow) { case ControlFlow.Continue => (); case _ => @Expect(false) }
            let second = app.update(Event.KeyDown(KeyEvent(KeyCode.Char(r'q'), modifiers: KeyModifier(ctrl: true))))
            match (second.flow) { case ControlFlow.Exit => (); case _ => @Expect(false) }
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func clipboardFailureNeverCutsOrPastesAndBackendIsVisible(): Unit {
        let app = MarkdownStudio(clipboard: FailingStudioClipboard())
        app.editor.setValue("keep this")
        app.editor.setCarets([TextAreaCaret(4, anchor: Some(0))])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(6))))
        @Expect(app.editor.value, "keep this")
        @Expect(app.status.contains("test-readonly"))
        @Expect(app.status.contains("copy failed"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(7))))
        @Expect(app.editor.value, "keep this")
        @Expect(app.status.contains("reader unavailable"))
    }

    @TestCase
    func successfulClipboardCopyAndPasteUseTheInjectedBackend(): Unit {
        let clipboard = MemoryClipboard()
        let app = MarkdownStudio(clipboard: clipboard)
        app.editor.setValue("copy this")
        app.editor.setCarets([TextAreaCaret(4, anchor: Some(0))])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        @Expect(clipboard.getText(), "copy")
        app.editor.setCarets([TextAreaCaret(9)])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(7))))
        @Expect(app.editor.value, "copy thiscopy")
        @Expect(app.status.contains("memory"))
    }

    @TestCase
    func creationAndExplicitOptionDelimiterAreSupported(): Unit {
        let (_, _, parsedPath, useOsc52) = studioOptions(["--osc52", "--", "-draft.md"])
        @Expect(parsedPath, Some("-draft.md"))
        @Expect(useOsc52)
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/new.md"
        try {
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard())
            _ = app.update(Event.Paste("# new\n"))
            @Expect(app.saveFile())
            @Expect(!app.isDirty())
            let reopened = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard())
            @Expect(reopened.editor.value, "# new\n")
        } finally { remove(directory, recursive: true) }
        var duplicateRejected = false
        try { _ = studioOptions(["one.md", "two.md"]) }
        catch (_: IllegalArgumentException) { duplicateRejected = true }
        @Expect(duplicateRejected)
    }

    @TestCase
    func invalidUtf8AndDirectoriesFailOpeningWithoutChangingTheSource(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/binary.md"
        try {
            let bytes: Array<Byte> = [0xFFu8, 0xFEu8]
            File.writeTo(path, bytes)
            for (input in [path, directory.toString()]) {
                var rejected = false
                try { _ = MarkdownStudio(filePath: Some(input), clipboard: MemoryClipboard()) }
                catch (_: IllegalArgumentException) { rejected = true }
                @Expect(rejected)
            }
            @Expect(File.readFrom(path), bytes)
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func renameFailurePreservesOriginalAndRemovesTemporaryFile(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/rename.md"
        try {
            File.writeTo(path, "original".toArray())
            let app = MarkdownStudio(filePath: Some(path), clipboard: MemoryClipboard(), writer: FailingStudioCommit())
            _ = app.update(Event.Paste("local "))
            @Expect(!app.saveFile())
            @Expect(app.isDirty())
            @Expect(app.status.contains("injected rename failure"))
            @Expect(String.fromUtf8(File.readFrom(path)), "original")
            @Expect(Directory.readFrom(directory).size, 1)
        } finally { remove(directory, recursive: true) }
    }

    @TestCase
    func osc52BackendClearlyReportsWriteOnlyAndNeverPastes(): Unit {
        let emitted = Array<String>(1, repeat: "")
        let app = MarkdownStudio(clipboard: Osc52Clipboard({ text => emitted[0] = text }))
        app.editor.setValue("keep")
        app.editor.setCarets([TextAreaCaret(4, anchor: Some(0))])
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(5))))
        @Expect(!emitted[0].isEmpty())
        @Expect(app.status.contains("osc52"))
        _ = app.update(Event.KeyDown(KeyEvent(KeyCode.F(7))))
        @Expect(app.editor.value, "keep")
        @Expect(app.status.contains("not supported"))
        let backend = TestBackend(area: Rect(0, 0, 120, 30))
        _ = Terminal(backend).draw { frame => app.render(frame) }
        @Expect(backend.snapshot().contains("osc52 (no paste)"))
    }
}

@When[os != "Windows"]
@Test
class MarkdownStudioSymbolicLinkRegressionTest {
    @TestCase
    func existingAndDanglingLinksAreNeverReplaced(): Unit {
        let directory = Directory.createTemp(getTempDirectory())
        let path = directory.toString() + "/real.md"
        let link = directory.toString() + "/link.md"
        let dangling = directory.toString() + "/dangling.md"
        try {
            File.writeTo(path, "original".toArray())
            @Expect(symlink(path, link), 0)
            @Expect(symlink(directory.toString() + "/missing.md", dangling), 0)
            for (input in [link, dangling]) {
                var rejected = false
                try { _ = MarkdownStudio(filePath: Some(input), clipboard: MemoryClipboard()) }
                catch (_: IllegalArgumentException) { rejected = true }
                @Expect(rejected)
                @Expect(FileInfo(input).isSymbolicLink())
            }
            @Expect(String.fromUtf8(File.readFrom(path)), "original")
        } finally { remove(directory, recursive: true) }
    }
}
