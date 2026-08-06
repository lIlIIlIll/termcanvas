package editor

import core

public type Clipboard = core.Clipboard
public type MemoryClipboard = core.MemoryClipboard
public type TextPosition = core.TextPosition
public type TextRange = core.TextRange
public type TextBuffer = core.TextBuffer
public type TextAreaCaret = core.TextAreaCaret
public type TextCompletionRequest = core.TextCompletionRequest
public type TextCompletionItem = core.TextCompletionItem
public type TextCompletionResult = core.TextCompletionResult
public type TextDecoration = core.TextDecoration
public type HighlightSpan = core.HighlightSpan
public type LineHighlight = core.LineHighlight
public type MarkdownHighlightCache = core.MarkdownHighlightCache
public type TextArea = core.TextArea
public type MarkdownEditorBehavior = core.MarkdownEditorBehavior
public type MarkdownTextEditor = core.MarkdownTextEditor
public type EditorBuffer = core.EditorBuffer
public type BufferSet = core.BufferSet
public type SaveDiagnostic = core.SaveDiagnostic
public type SyntaxRule = core.SyntaxRule
public type SyntaxHighlighter = core.SyntaxHighlighter
public type TextDocumentView = core.TextDocumentView
public type TextEditor = core.TextEditor
public type SearchPanel = core.SearchPanel
public type ReplacePanel = core.ReplacePanel
public type SoftWrapView = core.SoftWrapView

public func markdownDecorations(text: String): Array<TextDecoration> {
    core.markdownDecorations(text)
}

public func markdownLineHighlights(text: String): Array<LineHighlight> {
    core.markdownLineHighlights(text)
}
