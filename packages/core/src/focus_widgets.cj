package core

import std.collection.*

public class ScopedKeyMap {
    public let scope: String
    private let keymap: KeyMap

    public init(scope: String, keymap!: KeyMap = KeyMap()) {
        this.scope = scope
        this.keymap = keymap
    }

    public func add(binding: KeyBinding): Unit {
        keymap.add(binding)
    }

    public func actionFor(key: KeyEvent): ?String {
        keymap.actionFor(key)
    }
}

public class FocusRing {
    private let manager: FocusManager

    public init(manager!: FocusManager = FocusManager()) {
        this.manager = manager
    }

    public func add(id: String, enabled!: Bool = true): FocusRing {
        manager.add(id, enabled: enabled)
        this
    }

    public func focus(id: String): Bool {
        manager.focus(id)
    }

    public func next(): ?String {
        manager.next()
    }

    public func previous(): ?String {
        manager.previous()
    }

    public func current(): ?String {
        manager.current()
    }

    public func managerView(): FocusManager {
        manager
    }
}

public class TabOrder {
    private let ids = ArrayList<String>()

    public init(ids!: Array<String> = []) {
        for (id in ids) {
            this.ids.add(id)
        }
    }

    public func add(id: String): TabOrder {
        ids.add(id)
        this
    }

    public func apply(focus: FocusManager): Unit {
        for (id in ids) {
            focus.add(id)
        }
    }
}

public class FocusableWidget <: Component {
    private let id: String
    private let widget: Widget
    private let scopedKeys: ?ScopedKeyMap
    private let onAction: (String) -> HandleResult
    private let onEvent: (Event) -> HandleResult

    public init(
        id: String,
        widget: Widget,
        scopedKeys!: ?ScopedKeyMap = None,
        onAction!: (String) -> HandleResult = { _ => HandleResult.ignored() },
        onEvent!: (Event) -> HandleResult = { _ => HandleResult.ignored() }
    ) {
        this.id = id
        this.widget = widget
        this.scopedKeys = scopedKeys
        this.onAction = onAction
        this.onEvent = onEvent
    }

    public func render(frame: Frame, area: Rect): Unit {
        frame.renderWidget(widget, area)
    }

    public func handle(event: Event): HandleResult {
        match (event) {
            case Event.KeyDown(key) =>
                match (scopedKeys) {
                    case Some(keys) =>
                        match (keys.actionFor(key)) {
                            case Some(action) => return onAction(action)
                            case None => ()
                        }
                    case None => ()
                }
            case _ => ()
        }
        onEvent(event)
    }

    public func focusId(): ?String {
        Some(id)
    }
}

public class ModalFocusTrap {
    private let focus: FocusManager
    private let ids = ArrayList<String>()
    public var active: Bool

    public init(focus: FocusManager, ids!: Array<String> = [], active!: Bool = true) {
        this.focus = focus
        this.active = active
        for (id in ids) {
            this.ids.add(id)
            focus.add(id)
        }
    }

    public func add(id: String): Unit {
        ids.add(id)
        focus.add(id)
    }

    public func handle(key: KeyEvent): Bool {
        if (!active || ids.size == 0) { return false }
        match (key.code) {
            case KeyCode.Tab =>
                cycle(1)
                true
            case KeyCode.BackTab =>
                cycle(-1)
                true
            case _ => false
        }
    }

    private func cycle(delta: Int64): Unit {
        var index: Int64 = 0
        match (focus.current()) {
            case Some(current) =>
                for (i in 0..ids.size) {
                    if (ids[i] == current) { index = i }
                }
            case None => ()
        }
        let next = (index + delta + ids.size) % ids.size
        _ = focus.focus(ids[next])
    }
}

public class InputCapturePriority {
    public let modalFirst: Bool
    public let focusedFirst: Bool
    public let globalFallback: Bool

    public init(modalFirst!: Bool = true, focusedFirst!: Bool = true, globalFallback!: Bool = true) {
        this.modalFirst = modalFirst
        this.focusedFirst = focusedFirst
        this.globalFallback = globalFallback
    }
}
