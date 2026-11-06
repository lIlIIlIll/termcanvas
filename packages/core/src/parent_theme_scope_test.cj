package core

import std.unittest.*
import std.unittest.testmacro.*

// Represents a container that forwards its explicit theme while painting a child.
private class ParentThemeProbe <: Widget {
    private let parent: ?Theme
    private let at: Int64
    private let after: Int64
    private let child: ?Widget
    private let own: ?Theme
    private let fail: Bool
    private let catchChild: Bool

    init(parent: ?Theme, at: Int64, after!: Int64 = -1, child!: ?Widget = None,
        own!: ?Theme = None, fail!: Bool = false, catchChild!: Bool = false) {
        this.parent = parent
        this.at = at
        this.after = after
        this.child = child
        this.own = own
        this.fail = fail
        this.catchChild = catchChild
    }

    public func render(area: Rect, buffer: Buffer): Unit {
        buffer.withParentTheme(parent) { =>
            let effective = buffer.resolveTheme(own).getOrThrow()
            buffer.setString(at, area.y, "x", style: effective.normal)
            if (let Some(next) <- child) {
                if (catchChild) {
                    try { next.render(area, buffer) } catch (_: Exception) { () }
                } else {
                    next.render(area, buffer)
                }
            }
            if (after >= 0) {
                buffer.setString(after, area.y, "y", style: buffer.resolveTheme(Option<Theme>.None).getOrThrow().normal)
            }
            if (fail) { throw Exception("expected") }
        }
    }
}

@Test
class ParentThemeScopeTest {
    @TestCase
    func nestedExplicitThemesBeatAncestorsAndDoNotLeakToSiblings(): Unit {
        let app = Theme(normal: Style(fg: Color.Green))
        let outer = Theme(normal: Style(fg: Color.Red))
        let inner = Theme(normal: Style(fg: Color.Blue))
        let explicitChild = Theme(normal: Style(fg: Color.Yellow))
        let buffer = Buffer(Rect(0, 0, 7, 1))
        buffer.setTheme(app)
        let leaf = ParentThemeProbe(inner, 2, child: ParentThemeProbe(Option<Theme>.None, 3, own: explicitChild))
        let noOverride = ParentThemeProbe(Option<Theme>.None, 1, child: leaf)
        ParentThemeProbe(outer, 0, after: 4, child: noOverride).render(buffer.area, buffer)
        ParentThemeProbe(Option<Theme>.None, 5).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, outer.normal)
        @Expect(buffer.getCell(1, 0).style, outer.normal)
        @Expect(buffer.getCell(2, 0).style, inner.normal)
        @Expect(buffer.getCell(3, 0).style, explicitChild.normal)
        @Expect(buffer.getCell(4, 0).style, outer.normal)
        @Expect(buffer.getCell(5, 0).style, app.normal)
        @Expect(buffer.theme().getOrThrow().normal, app.normal)
    }

    @TestCase
    func exceptionalNestedAndOuterScopesRestoreThemes(): Unit {
        let app = Theme(normal: Style(fg: Color.Green))
        let outer = Theme(normal: Style(fg: Color.Red))
        let inner = Theme(normal: Style(fg: Color.Blue))
        let buffer = Buffer(Rect(0, 0, 5, 1))
        buffer.setTheme(app)
        let failing = ParentThemeProbe(inner, 1, fail: true)
        ParentThemeProbe(outer, 0, after: 2, child: failing, catchChild: true).render(buffer.area, buffer)
        @Expect(buffer.getCell(1, 0).style, inner.normal)
        @Expect(buffer.getCell(2, 0).style, outer.normal)
        @ExpectThrows[Exception](ParentThemeProbe(outer, 3, fail: true).render(buffer.area, buffer))
        ParentThemeProbe(Option<Theme>.None, 4).render(buffer.area, buffer)
        @Expect(buffer.getCell(4, 0).style, app.normal)
    }

    @TestCase
    func explicitThemesStayUnadaptedWhileApplicationThemeAdapts(): Unit {
        let app = Theme(normal: Style(fg: Color.Rgb(123, 22, 177)))
        let outer = Theme(normal: Style(fg: Color.Rgb(200, 30, 140)))
        let buffer = Buffer(Rect(0, 0, 3, 1))
        buffer.setCapabilities(TerminalCapabilities(trueColor: false, colorLevel: 16))
        buffer.setTheme(app)
        ParentThemeProbe(outer, 0).render(buffer.area, buffer)
        ParentThemeProbe(Option<Theme>.None, 1).render(buffer.area, buffer)
        @Expect(buffer.getCell(0, 0).style, outer.normal)
        @Expect(buffer.getCell(1, 0).style, app.adapted(buffer.capabilities()).normal)
        @Expect(buffer.theme().getOrThrow().normal, app.normal)
    }

    @TestCase
    func absentApplicationThemeReturnsToNoneAfterScope(): Unit {
        let local = Theme(normal: Style(fg: Color.Red))
        let buffer = Buffer(Rect(0, 0, 1, 1))
        ParentThemeProbe(local, 0).render(buffer.area, buffer)
        let resolved = buffer.resolveTheme(Option<Theme>.None)
        @Expect(resolved.isNone())
        @Expect(buffer.theme().isNone())
    }
}
