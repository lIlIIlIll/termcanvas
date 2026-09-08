package core

import std.unittest.*
import std.unittest.testmacro.*

private func auditInputBytes(text: String): Array<Byte> { unsafe { text.rawData() } }

private func auditInputCode(code: KeyCode): String {
    match (code) {
        case KeyCode.Char(r) => "char:${UInt32(r)}"
        case KeyCode.CtrlC => "ctrl-c"
        case KeyCode.Esc => "esc"
        case KeyCode.Tab => "tab"
        case KeyCode.BackTab => "backtab"
        case KeyCode.Enter => "enter"
        case KeyCode.Backspace => "backspace"
        case KeyCode.Delete => "delete"
        case KeyCode.Insert => "insert"
        case KeyCode.Up => "up"
        case KeyCode.Down => "down"
        case KeyCode.Left => "left"
        case KeyCode.Right => "right"
        case KeyCode.Home => "home"
        case KeyCode.End => "end"
        case KeyCode.PageUp => "pageup"
        case KeyCode.PageDown => "pagedown"
        case KeyCode.F(n) => "f:${n}"
    }
}

private func auditInputKey(key: KeyEvent): String {
    let m = key.modifiers
    let protocol = match (key.protocol) {
        case KeyProtocol.Basic => "basic"
        case KeyProtocol.Kitty => "kitty"
        case KeyProtocol.ModifyOtherKeys => "modify"
    }
    let text = match (key.text) { case Some(value) => value; case None => "<none>" }
    "${auditInputCode(key.code)}:${m.shift}:${m.alt}:${m.ctrl}:${m.superKey}:${m.hyper}:${m.meta}:${m.capsLock}:${m.numLock}:${protocol}:${key.nativeRepeat}:${text}"
}

private func auditInputEvents(events: Array<Event>): String {
    var out = ""
    for (event in events) {
        out += match (event) {
            case Event.KeyDown(key) => "down:${auditInputKey(key)};"
            case Event.KeyRepeat(key) => "repeat:${auditInputKey(key)};"
            case Event.KeyUp(key) => "up:${auditInputKey(key)};"
            case Event.Paste(text) => "paste:${text};"
            case Event.FocusIn => "focus-in;"
            case Event.FocusOut => "focus-out;"
            case Event.Unknown(bytes) =>
                var value = "unknown:"
                for (byte in bytes) { value += "${byte}," }
                value + ";"
            case Event.Mouse(mouse) =>
                let kind = match (mouse.kind) {
                    case MouseKind.Down => "down"
                    case MouseKind.Up => "up"
                    case MouseKind.Drag => "drag"
                    case MouseKind.Move => "move"
                    case MouseKind.Scroll => "scroll"
                }
                let button = match (mouse.button) {
                    case MouseButton.Left => "left"
                    case MouseButton.Middle => "middle"
                    case MouseButton.Right => "right"
                    case MouseButton.WheelUp => "wheel-up"
                    case MouseButton.WheelDown => "wheel-down"
                    case MouseButton.None => "none"
                }
                "mouse:${kind}:${button}:${mouse.x}:${mouse.y}:${mouse.modifiers.shift}:${mouse.modifiers.alt}:${mouse.modifiers.ctrl};"
            case _ => "other;"
        }
    }
    out
}

private func auditInputBuffersEqual(left: Buffer, right: Buffer): Bool {
    if (left.area != right.area) { return false }
    for (y in left.area.y..left.area.bottom) {
        for (x in left.area.x..left.area.right) {
            if (left.getCell(x, y) != right.getCell(x, y)) { return false }
        }
    }
    true
}

private func auditInputCompletion(request: TextCompletionRequest): TextCompletionResult {
    TextCompletionResult(request.requestId, request.revision, request.prefixStart, request.prefixEnd,
        [TextCompletionItem("COMPLETED")])
}

@Test
class AuditInputTest {
    @TestCase
    func altUnicodeAndInputFramesAreIndependentOfEverySplit(): Unit {
        let frames = ["中x", "\u{1B}中x", "\u{1B}🙂x", "\u{1B}[1;5A", "\u{1B}[<65;3;4M",
            "\u{1B}[200~a中\n\u{1B}[201~x", "\u{1B}[I\u{1B}[O", "\u{1B}[97;5:2u",
            "\u{1B}[1;5:2A", "\u{1B}[1;5:3A", "\u{1B}[3;1:3~"]
        for (frame in frames) {
            let bytes = auditInputBytes(frame)
            let expected = auditInputEvents(EventParser().push(bytes))
            for (cutPoint in 0..bytes.size + 1) {
                let parser = EventParser()
                let first = auditInputEvents(parser.push(bytes[..cutPoint]))
                @Expect(first + auditInputEvents(parser.push(bytes[cutPoint..])), expected)
            }
            let parser = EventParser()
            var bytewise = ""
            for (byte in bytes) { bytewise += auditInputEvents(parser.push([byte])) }
            @Expect(bytewise, expected)
        }
        let parser = EventParser()
        @Expect(parser.push([0x1B, 0xE4]).size, 0)
        @Expect(parser.flushEsc().size, 0)
        let events = parser.push([0xB8, 0xAD])
        @Assert(events.size, 1)
        match (events[0]) {
            case Event.KeyDown(key) =>
                @Expect(auditInputCode(key.code), "char:20013")
                @Expect(key.modifiers, KeyModifier(alt: true))
            case _ => @Expect(false)
        }
    }

    @TestCase
    func kittySubfieldsPreserveEventTypeModifiersAndAssociatedText(): Unit {
        let events = EventParser().push(auditInputBytes(
            "\u{1B}[97;5:2u\u{1B}[97;5:3u\u{1B}[97:65:97;2;65u\u{1B}[0;;229:769u"))
        @Assert(events.size, 4)
        match (events[0]) {
            case Event.KeyRepeat(key) =>
                @Expect(key.modifiers, KeyModifier(ctrl: true))
                @Expect(key.nativeRepeat)
                @Expect(auditInputCode(key.code), "char:97")
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyUp(key) =>
                @Expect(key.modifiers, KeyModifier(ctrl: true))
                @Expect(!key.nativeRepeat)
            case _ => @Expect(false)
        }
        match (events[2]) {
            case Event.KeyDown(key) =>
                @Expect(key.text, Some("A"))
                @Expect(key.modifiers, KeyModifier(shift: true))
                @Expect(auditInputCode(key.code), "char:97")
            case _ => @Expect(false)
        }
        match (events[3]) {
            case Event.KeyDown(key) => @Expect(key.text, Some("å\u{0301}"))
            case _ => @Expect(false)
        }
    }

    @TestCase
    func kittyFunctionNumbersDoNotAliasEditingKeys(): Unit {
        for (number in 57376..57399) {
            let events = EventParser().push(auditInputBytes("\u{1B}[${number}u"))
            @Assert(events.size, 1)
            match (events[0]) {
                case Event.KeyDown(key) => @Expect(auditInputCode(key.code), "f:${number - 57363}")
                case _ => @Expect(false)
            }
        }
        for (number in [57358, 57359, 57360, 57399]) {
            let events = EventParser().push(auditInputBytes("\u{1B}[${number}u"))
            @Assert(events.size, 1)
            match (events[0]) { case Event.Unknown(_) => (); case _ => @Expect(false) }
        }
    }

    @TestCase
    func kittyFunctionalKeysKeepRepeatAndReleaseTypes(): Unit {
        let events = EventParser().push(auditInputBytes("\u{1B}[1;5:2A\u{1B}[1;5:3A\u{1B}[3;1:3~"))
        @Assert(events.size, 3)
        match (events[0]) {
            case Event.KeyRepeat(key) =>
                @Expect(auditInputCode(key.code), "up")
                @Expect(key.modifiers, KeyModifier(ctrl: true))
                @Expect(key.nativeRepeat)
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyUp(key) =>
                @Expect(auditInputCode(key.code), "up")
                @Expect(!key.nativeRepeat)
            case _ => @Expect(false)
        }
        match (events[2]) {
            case Event.KeyUp(key) => @Expect(auditInputCode(key.code), "delete")
            case _ => @Expect(false)
        }
    }

    @TestCase
    func textAreaInsertsAssociatedTextAsOneHistoryOperation(): Unit {
        for ((frame, expected) in [("\u{1B}[97;2;65u", "A"), ("\u{1B}[0;;229:769u", "å\u{0301}")]) {
            let events = EventParser().push(auditInputBytes(frame))
            @Assert(events.size, 1)
            let editor = TextArea()
            match (events[0]) {
                case Event.KeyDown(key) => @Expect(editor.handle(key))
                case _ => @Expect(false)
            }
            @Expect(editor.value, expected)
            @Expect(editor.cursor, expected.size)
            @Expect(editor.undo())
            @Expect(editor.value, "")
        }
    }

    @TestCase
    func invalidNumericFramesAreConsumedAndTheParserContinues(): Unit {
        for (frame in ["\u{1B}[999999999999999999999A", "\u{1B}[1114112u", "\u{1B}[55296u",
            "\u{1B}[97;1;55296u", "\u{1B}[27;2;1114112~", "\u{1B}[<999999999999999999999;1;1M"]) {
            let bytes = auditInputBytes(frame + "q")
            let expected = auditInputEvents(EventParser().push(bytes))
            for (cutPoint in 0..bytes.size + 1) {
                let parser = EventParser()
                let first = auditInputEvents(parser.push(bytes[..cutPoint]))
                @Expect(first + auditInputEvents(parser.push(bytes[cutPoint..])), expected)
            }
            let parser = EventParser()
            let events = parser.push(bytes)
            @Assert(events.size, 2)
            match (events[0]) {
                case Event.Unknown(data) => @Expect(data.size, frame.size)
                case _ => @Expect(false)
            }
            match (events[1]) {
                case Event.KeyDown(key) => @Expect(auditInputCode(key.code), "char:113")
                case _ => @Expect(false)
            }
            @Expect(auditInputEvents(parser.push(auditInputBytes("r"))),
                auditInputEvents(EventParser().push(auditInputBytes("r"))))
        }
    }

    @TestCase
    func invalidUtf8PasteIsRejectedWithoutLosingFollowingInput(): Unit {
        let bytes: Array<Byte> = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E, 0xFF,
            0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E, b'q']
        let expected = auditInputEvents(EventParser().push(bytes))
        for (cutPoint in 0..bytes.size + 1) {
            let parser = EventParser()
            let first = auditInputEvents(parser.push(bytes[..cutPoint]))
            @Expect(first + auditInputEvents(parser.push(bytes[cutPoint..])), expected)
        }
        let parser = EventParser()
        let events = parser.push(bytes)
        @Assert(events.size, 2)
        match (events[0]) {
            case Event.Unknown(data) => @Expect(data.size, 13)
            case _ => @Expect(false)
        }
        match (events[1]) {
            case Event.KeyDown(key) => @Expect(auditInputCode(key.code), "char:113")
            case _ => @Expect(false)
        }
        let valid = parser.push(auditInputBytes("\u{1B}[200~中e\u{0301}\u{1B}[201~"))
        @Assert(valid.size, 1)
        match (valid[0]) {
            case Event.Paste(text) => @Expect(displayWidth(text), 3)
            case _ => @Expect(false)
        }
    }

    @TestCase
    func negativeWideTextMatchesThePhysicalCanvasClip(): Unit {
        let area = Rect(0, 0, 4, 1)
        let actual = Buffer(area)
        Canvas(actual, Rect(-1, 0, 5, 1)).drawText(-1, 0, "界a", Style.default())
        let expected = Buffer(area)
        Canvas(expected, area).drawText(-1, 0, "界a", Style.default())
        @Expect(auditInputBuffersEqual(actual, expected))
        @Expect(actual.getCell(0, 0), Cell())
        @Expect(actual.getCell(1, 0), Cell("a"))
        let direct = Buffer(area)
        direct.setString(-1, 0, "界a")
        @Expect(auditInputBuffersEqual(direct, expected))
    }

    @TestCase
    func blitsRepairSourceAndDestinationWideBoundaries(): Unit {
        let source = Buffer(Rect(0, 0, 3, 1))
        source.setString(0, 0, "界x")
        for (unchecked in [false, true]) {
            let cropped = Buffer(source.area)
            if (unchecked) { cropped.blitFromUnchecked(source, Rect(0, 0, 1, 1), 0, 0) }
            else { cropped.blitFrom(source, Rect(0, 0, 1, 1), 0, 0) }
            @Expect(cropped.getCell(0, 0), Cell())
            let ascii = Buffer(Rect(0, 0, 1, 1))
            ascii.setString(0, 0, "a")
            let overwritten = source.copy()
            if (unchecked) { overwritten.blitFromUnchecked(ascii, ascii.area, 1, 0) }
            else { overwritten.blitFrom(ascii, ascii.area, 1, 0) }
            @Expect(overwritten.getCell(0, 0), Cell())
            @Expect(overwritten.getCell(1, 0), Cell("a"))
            @Expect(overwritten.getCell(2, 0), Cell("x"))
            let complete = Buffer(source.area)
            complete.blitFrom(source, source.area, 0, 0)
            @Expect(auditInputBuffersEqual(complete, source))
        }
        let overlap = Buffer(Rect(0, 0, 5, 1))
        overlap.setString(0, 0, "abcde")
        overlap.blitFrom(overlap, Rect(0, 0, 4, 1), 1, 0)
        @Expect(overlap.getCell(4, 0), Cell("d"))
    }

    @TestCase
    func resizeBlanksOnlyTheWideGlyphCutByTheIntersection(): Unit {
        let source = Buffer(Rect(0, 0, 3, 1))
        source.setString(0, 0, "界x")
        @Expect(source.resize(Rect(0, 0, 1, 1)).getCell(0, 0), Cell())
        let left = source.resize(Rect(1, 0, 2, 1))
        @Expect(left.getCell(1, 0), Cell())
        @Expect(left.getCell(2, 0), Cell("x"))
        let expanded = source.resize(Rect(-1, -1, 6, 3))
        @Expect(expanded.getCell(0, 0), source.getCell(0, 0))
        @Expect(expanded.getCell(1, 0), source.getCell(1, 0))
        @Expect(expanded.getCell(-1, -1), Cell())
    }

    @TestCase
    func canvasLinesStayInsideBothClipDimensions(): Unit {
        let buffer = Buffer(Rect(0, 0, 4, 3))
        let canvas = Canvas(buffer, Rect(0, 0, 1, 1))
        canvas.vline(2, 0, 1, "v", Style.default())
        canvas.hline(0, 2, 1, "h", Style.default())
        canvas.vline(0, 0, 1, "界", Style.default())
        @Expect(auditInputBuffersEqual(buffer, Buffer(buffer.area)))
        canvas.vline(0, 0, 1, "v", Style.default())
        @Expect(buffer.getCell(0, 0), Cell("v"))
    }

    @TestCase
    func canvasPreservesWideGlyphsCrossingItsClip(): Unit {
        for (operation in ["hline", "vline", "text", "fill"]) {
            for (edge in [0, 1]) {
                let buffer = Buffer(Rect(0, 0, 4, 1))
                buffer.setString(0, 0, "界")
                let expected = buffer.copy()
                let canvas = Canvas(buffer, Rect(edge, 0, 1, 1))
                match (operation) {
                    case "hline" => canvas.hline(edge, 0, 1, "x", Style.default())
                    case "vline" => canvas.vline(edge, 0, 1, "x", Style.default())
                    case "text" => canvas.drawText(edge, 0, "x", Style.default())
                    case _ => canvas.fillRect(edge, 0, 1, 1, Style.default())
                }
                @Expect(auditInputBuffersEqual(buffer, expected))
                Canvas(buffer, buffer.area).drawText(edge, 0, "x", Style.default())
                @Expect(buffer.getCell(edge, 0), Cell("x"))
                @Expect(buffer.getCell(1 - edge, 0), Cell())
            }
        }
    }

    @TestCase
    func ellipsisNeverExceedsItsDisplayWidthBudget(): Unit {
        for (width in 0..7) {
            @Expect(displayWidth(cut("abcdef", width)) <= width)
            @Expect(displayWidth(cut("界界界", width)) <= width)
        }
        @Expect(cut("abcdef", 1), ".")
        @Expect(cut("abcdef", 2), "..")
        @Expect(cut("abcdef", 4), "a...")
        @Expect(cut("界", 2), "界")
    }

    @TestCase
    func multiSelectionReplacementLeavesCaretsAfterInsertedText(): Unit {
        let editor = TextArea(value: "one\ntwo")
        editor.setCarets([TextAreaCaret(0, anchor: Some(3)), TextAreaCaret(4, anchor: Some(7))])
        editor.paste("x")
        @Expect(editor.carets()[0].offset, 1)
        @Expect(editor.carets()[1].offset, 3)
        _ = editor.handle(KeyEvent(KeyCode.Char(r'y')))
        @Expect(editor.value, "xy\nxy")
        @Expect(editor.undo())
        @Expect(editor.value, "x\nx")
        @Expect(editor.redo())
        @Expect(editor.value, "xy\nxy")
        let unicode = TextArea(value: "中\n文")
        unicode.setCarets([TextAreaCaret(0, anchor: Some(3)), TextAreaCaret(4, anchor: Some(7))])
        unicode.paste("🙂")
        _ = unicode.handle(KeyEvent(KeyCode.Char(r'好')))
        @Expect(unicode.value, "🙂好\n🙂好")
        @Expect(unicode.carets()[0].offset, 7)
        @Expect(unicode.carets()[1].offset, 15)
    }

    @TestCase
    func bothDeletionKeysApplyToEverySelectedCaret(): Unit {
        for (key in [KeyCode.Backspace, KeyCode.Delete]) {
            let editor = TextArea(value: "one\ntwo")
            editor.setCarets([TextAreaCaret(0, anchor: Some(3)), TextAreaCaret(4, anchor: Some(7))])
            @Expect(editor.handle(KeyEvent(key)))
            @Expect(editor.value, "\n")
            @Expect(editor.carets()[0].offset, 0)
            @Expect(editor.carets()[1].offset, 1)
            editor.paste("x")
            @Expect(editor.value, "x\nx")
        }
    }

    @TestCase
    func selectionTextAndHighlightUseTheExplicitRange(): Unit {
        let editor = TextArea(value: "abcdef", cursor: 0)
        editor.select(2, 4)
        @Expect(editor.selectedText(), "cd")
        @Assert(editor.selectedTexts().size, 1)
        @Expect(editor.selectedTexts()[0], "cd")
        let buffer = Buffer(Rect(0, 0, 6, 1))
        editor.render(buffer.area, buffer)
        let selected = Style(fg: Color.Black, bg: Color.White)
        for (x in 0..6) {
            @Expect(buffer.getCell(x, 0).style == selected, x == 2 || x == 3)
        }
    }

    @TestCase
    func directValueChangesInvalidateRevisionRenderingAndCompletion(): Unit {
        let editor = TextArea(value: "abc", cursor: 3)
        let area = Rect(0, 0, 6, 2)
        editor.render(area, Buffer(area))
        let old = editor.beginCompletion("old")
        editor.value = "axc"
        @Expect(editor.editRevision() > old.revision)
        @Expect(!editor.handleCompletionEvent(Event.TextCompletion("old", auditInputCompletion(old))))
        let actual = Buffer(area)
        let expected = Buffer(area)
        editor.render(area, actual)
        TextArea(value: editor.value).render(area, expected)
        @Expect(auditInputBuffersEqual(actual, expected))
        let rebuilds = editor.lineCacheRebuildCount()
        editor.render(area, Buffer(area))
        @Expect(editor.lineCacheRebuildCount(), rebuilds)
        editor.value = "q"
        let next = editor.beginCompletion("next")
        @Expect(next.value, "q")
        @Expect(next.cursor, 1)
        @Expect(next.revision > old.revision)
    }

    @TestCase
    func foldMutationsRefreshVisibleLinesWithoutChangingWidth(): Unit {
        let state = DocumentViewState()
        let editor = TextArea(value: "one\ntwo\nthree", foldState: Some(state))
        let area = Rect(0, 0, 16, 4)
        editor.render(area, Buffer(area))
        for (fold in [true, false, true]) {
            if (fold) { state.setFolded(0, 7, true) } else { state.clearFolds() }
            let actual = Buffer(area)
            let expected = Buffer(area)
            editor.render(area, actual)
            TextArea(value: editor.value, foldState: Some(state)).render(area, expected)
            @Expect(auditInputBuffersEqual(actual, expected))
        }
    }

    @TestCase
    func undoRedoAndEmptyListEditsRejectEarlierCompletionResults(): Unit {
        let editor = TextArea(value: "a", cursor: 1)
        editor.paste("b")
        let beforeUndo = editor.beginCompletion("undo")
        @Expect(editor.undo())
        @Expect(editor.editRevision() > beforeUndo.revision)
        @Expect(!editor.handleCompletionEvent(Event.TextCompletion("undo", auditInputCompletion(beforeUndo))))
        let beforeRedo = editor.beginCompletion("redo")
        @Expect(editor.redo())
        @Expect(editor.editRevision() > beforeRedo.revision)
        @Expect(!editor.handleCompletionEvent(Event.TextCompletion("redo", auditInputCompletion(beforeRedo))))
        editor.value = "xy"
        let beforeDirectUndo = editor.editRevision()
        @Expect(editor.undo())
        @Expect(editor.editRevision() > beforeDirectUndo)
        let markdown = TextArea(value: "- ", cursor: 2, markdownEditing: true)
        let before = markdown.editRevision()
        @Expect(markdown.handle(KeyEvent(KeyCode.Enter)))
        @Expect(markdown.value, "")
        @Expect(markdown.editRevision() > before)
    }

    @TestCase
    func readonlyInputRejectsUndoRedoAndCompletionAcceptance(): Unit {
        let editor = TextArea(value: "a", cursor: 1)
        editor.paste("b")
        editor.readOnly = true
        @Expect(!editor.handle(KeyEvent(KeyCode.Char(r'z'), modifiers: KeyModifier(ctrl: true))))
        @Expect(editor.value, "ab")
        editor.readOnly = false
        @Expect(editor.undo())
        editor.readOnly = true
        @Expect(!editor.handle(KeyEvent(KeyCode.Char(r'y'), modifiers: KeyModifier(ctrl: true))))
        @Expect(editor.value, "a")
        for (key in [KeyCode.Enter, KeyCode.Tab]) {
            let completed = TextArea(value: "pri", cursor: 3, readOnly: true)
            let request = completed.beginCompletion("readonly")
            @Expect(completed.handleCompletionEvent(Event.TextCompletion("readonly", auditInputCompletion(request))))
            @Expect(!completed.handle(KeyEvent(key)))
            @Expect(completed.value, "pri")
        }
    }

    @TestCase
    func generatedDirtyRectsMatchFullRenderingAcrossViewportMoves(): Unit {
        let area = Rect(0, 0, 8, 2)
        let editor = TextArea(value: "0\n1\n2\n3", cursor: 2)
        let backend = TestBackend(area: area)
        let terminal = Terminal(backend, renderMode: RenderMode.Diff)
        _ = terminal.draw { frame => frame.renderWidget(editor, frame.area) }
        for (key in [KeyCode.Down, KeyCode.Down, KeyCode.Up, KeyCode.Home]) {
            let dirty = editor.handleWithDirty(KeyEvent(key), area)
            _ = terminal.draw({ frame => frame.renderWidget(editor, frame.area) }, dirtyRects: dirty)
            let fullBackend = TestBackend(area: area)
            let full = Terminal(fullBackend, renderMode: RenderMode.Full)
            let expected = TextArea(value: editor.value, cursor: editor.cursor, scroll: editor.scroll)
            _ = full.draw { frame => frame.renderWidget(expected, frame.area) }
            @Expect(backend.snapshot(), fullBackend.snapshot())
        }
    }

    @TestCase
    func shortDocumentsRenderTheirOpenCompletionMenu(): Unit {
        let editor = TextArea(value: "pri", cursor: 3)
        let request = editor.beginCompletion("popup")
        @Expect(editor.handleCompletionEvent(Event.TextCompletion("popup", auditInputCompletion(request))))
        let area = Rect(0, 0, 20, 5)
        let integrated = Buffer(area)
        let overlay = Buffer(area)
        editor.render(area, integrated)
        editor.renderCompletionOverlay(area, overlay)
        @Expect(integrated.getCell(3, 1).symbol, ">")
        for (x in area.x..area.right) { @Expect(integrated.getCell(x, 1), overlay.getCell(x, 1)) }
        @Expect(editor.handle(KeyEvent(KeyCode.Enter)))
        @Expect(editor.value, "COMPLETED")
    }

    @TestCase
    func completionCoordinatesApplyBorderAndGutterOnlyOnce(): Unit {
        let editor = TextArea(value: "pri", cursor: 3, block: Some(Block()), lineNumbers: true)
        let request = editor.beginCompletion("decorated")
        @Expect(editor.handleCompletionEvent(Event.TextCompletion("decorated", auditInputCompletion(request))))
        let area = Rect(0, 0, 20, 5)
        let integrated = Buffer(area)
        let overlay = Buffer(area)
        editor.render(area, integrated)
        editor.renderCompletionOverlay(area, overlay)
        let position = editor.cursorPosition(area)
        @Expect(position.x, 7)
        @Expect(position.y, 1)
        @Expect(integrated.getCell(position.x, position.y + 1).symbol, ">")
        for (x in 1..area.right - 1) {
            @Expect(integrated.getCell(x, position.y + 1), overlay.getCell(x, position.y + 1))
        }
    }

    @TestCase
    func cursorPositionsShareThePrimaryViewportAndOmitOffscreenCarets(): Unit {
        let editor = TextArea(value: "0\n1\n2\n3")
        editor.setCarets([TextAreaCaret(0), TextAreaCaret(2), TextAreaCaret(6)])
        let area = Rect(0, 0, 6, 2)
        editor.render(area, Buffer(area))
        let positions = editor.cursorPositions(area)
        @Expect(editor.scroll, 0)
        @Expect(editor.cursor, 0)
        @Assert(positions.size, 2)
        @Expect(positions[0].x, 0)
        @Expect(positions[0].y, 0)
        @Expect(positions[1].x, 0)
        @Expect(positions[1].y, 1)
        @Expect(editor.cursorPositions(area).size, 2)
        @Expect(editor.scroll, 0)
    }
}
