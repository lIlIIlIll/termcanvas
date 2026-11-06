package core

import std.unittest.*
import std.unittest.testmacro.*

private class WidthMismatchCompositeProbe <: Widget {
    private let source: Surface
    init(source: Surface) { this.source = source }
    public func render(area: Rect, buffer: Buffer): Unit {
        Canvas(buffer, area).composite(source)
    }
}

@Test
class BlitWidthPolicyTest {
    @TestCase
    func mismatchedPoliciesFailAtomicallyForBothCopyMethods(): Unit {
        let narrow = TextWidthOptions()
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        for (sourceWide in [false, true]) {
            for (unchecked in [false, true]) {
                let source = Buffer(Rect(0, 0, 5, 1))
                source.setTextWidthOptions(if (sourceWide) { wide } else { narrow })
                source.setString(0, 0, "·X")
                let target = Buffer(source.area)
                target.setTextWidthOptions(if (sourceWide) { narrow } else { wide })
                target.fill(target.area, Cell("#", style: Style(bg: Color.Blue)))
                let before = target.copy()
                if (unchecked) {
                    @ExpectThrows[IllegalArgumentException](target.blitFromUnchecked(source, source.area, 0, 0))
                } else {
                    @ExpectThrows[IllegalArgumentException](target.blitFrom(source, source.area, 0, 0))
                }
                for (x in 0..5) { @Expect(target.getCell(x, 0), before.getCell(x, 0)) }
                // An empty clipped source remains a no-op even with different policies.
                target.blitFrom(source, Rect(0, 0, 0, 1), 0, 0)
            }
        }
    }

    @TestCase
    func surfaceCompositeRejectsMismatchAndScopedStateRecovers(): Unit {
        let area = Rect(0, 0, 5, 1)
        let target = Buffer(area)
        target.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        target.fill(area, Cell("#", style: Style(bg: Color.Blue)))
        let source = Surface(area)
        source.bufferView().setString(0, 0, "·X")
        let wrapped = StyledWidget(WidthMismatchCompositeProbe(source), override: StyleOverride(bg: Color.Reset))
        @ExpectThrows[IllegalArgumentException](wrapped.render(area, target))
        for (x in 0..5) { @Expect(target.getCell(x, 0), Cell("#", style: Style(bg: Color.Blue))) }
        target.setString(4, 0, "!", style: Style(bg: Color.Green))
        @Expect(target.getCell(4, 0), Cell("!", style: Style(bg: Color.Green)))
        let matching = Canvas(target, area).createSurface(area)
        matching.bufferView().setString(0, 0, "·X")
        Canvas(target, area).composite(matching)
        @Expect(target.getCell(2, 0).symbol, "X")
    }

    @TestCase
    func samePolicyKeepsWideClippingAndOverlappingCopies(): Unit {
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        let source = Buffer(Rect(0, 0, 5, 1))
        source.setTextWidthOptions(wide)
        source.setString(0, 0, "·X", style: Style(fg: Color.Red))
        let target = Buffer(source.area)
        target.setTextWidthOptions(wide)
        target.fill(target.area, Cell("#"))
        target.blitFrom(source, Rect(1, 0, 2, 1), 0, 0)
        @Expect(target.getCell(0, 0), Cell(" ", style: Style(fg: Color.Red)))
        @Expect(target.getCell(1, 0).symbol, "X")
        source.blitFrom(source, Rect(0, 0, 3, 1), 1, 0)
        @Expect(source.getCell(1, 0).symbol, "·")
        @Expect(source.getCell(3, 0).symbol, "X")
    }

    @TestCase
    func policyChangeCannotHideStaleCellsAndRedrawRestoresCopying(): Unit {
        let narrow = TextWidthOptions()
        let wide = TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide)
        for (startWide in [false, true]) {
            let source = Buffer(Rect(0, 0, 6, 1))
            source.setTextWidthOptions(if (startWide) { wide } else { narrow })
            source.setString(0, 0, "·X")
            source.setTextWidthOptions(if (startWide) { narrow } else { wide })
            let target = Buffer(source.area)
            target.setTextWidthOptions(if (startWide) { narrow } else { wide })
            target.fill(target.area, Cell("#"))
            @ExpectThrows[IllegalArgumentException](target.blitFrom(source, source.area, 0, 0))
            @Expect(target.getCell(0, 0).symbol, "#")
            let copy = source.copy()
            @ExpectThrows[IllegalArgumentException](target.blitFromUnchecked(copy, copy.area, 0, 0))
            @ExpectThrows[IllegalArgumentException](source.resize(source.area))
            source.clear()
            source.setString(0, 0, "·X")
            target.blitFrom(source, source.area, 0, 0)
            @Expect(target.getCell(if (startWide) { 1 } else { 2 }, 0).symbol, "X")
        }
    }

    @TestCase
    func togglingBackToOriginalPolicyDoesNotInvalidateValidCells(): Unit {
        let source = Buffer(Rect(0, 0, 4, 1))
        source.setString(0, 0, "·X")
        source.setTextWidthOptions(TextWidthOptions(ambiguousWidth: AmbiguousWidth.Wide))
        source.setTextWidthOptions(TextWidthOptions())
        let target = Buffer(source.area)
        target.blitFrom(source, source.area, 0, 0)
        @Expect(target.getCell(0, 0).symbol, "·")
        @Expect(target.getCell(1, 0).symbol, "X")
    }
}
