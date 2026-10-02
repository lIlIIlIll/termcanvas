package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class FlexLayoutCapabilityTest {
    @TestCase
    func shrinkUsesScaledBasisAndRespectsZeroWeight(): Unit {
        let equal = FlexLayout(Direction.Horizontal, [FlexItem(basis: 4), FlexItem(basis: 4)]).split(Rect(0, 0, 6, 1))
        @Expect(equal[0].width, 3); @Expect(equal[1].width, 3)
        let protected = FlexLayout(Direction.Horizontal, [FlexItem(basis: 4), FlexItem(basis: 4, shrink: 0)]).resolve(Rect(0, 0, 6, 1))
        @Expect(protected.constraintsSatisfied)
        @Expect(protected.rects[0].width, 2); @Expect(protected.rects[1].width, 4)
        let weighted = FlexLayout(Direction.Vertical, [FlexItem(basis: 6), FlexItem(basis: 6, shrink: 2)], gap: 1).split(Rect(2, 3, 1, 10))
        @Expect(weighted[0].height, 5); @Expect(weighted[1].height, 4); @Expect(weighted[1].y, 9)
    }

    @TestCase
    func saturationRedistributesGrowthAndShrink(): Unit {
        let grow = FlexLayout(Direction.Horizontal, [FlexItem(basis: 2, maxSize: 3), FlexItem(basis: 2)]).split(Rect(0, 0, 10, 1))
        @Expect(grow[0].width, 3); @Expect(grow[1].width, 7)
        let shrink = FlexLayout(Direction.Horizontal, [FlexItem(basis: 8, minSize: 7), FlexItem(basis: 8)]).split(Rect(0, 0, 10, 1))
        @Expect(shrink[0].width, 7); @Expect(shrink[1].width, 3)
        let hint = FlexItem.fromSizeHint(SizeHint(minWidth: 2, preferredWidth: 5, maxWidth: 8), Direction.Horizontal)
        @Expect(hint.minSize, 2); @Expect(hint.basis, 5); @Expect(hint.maxSize, 8)
    }

    @TestCase
    func infeasibleMinimaAndGapsDegradeWithinBounds(): Unit {
        let layout = FlexLayout(Direction.Horizontal, [FlexItem(basis: 8, minSize: 4), FlexItem(basis: 8, minSize: 4)], gap: 1)
        let result = layout.resolve(Rect(5, 2, 4, 1))
        @Expect(!result.constraintsSatisfied)
        @Expect(result.rects[0].width, 1); @Expect(result.rects[1].width, 2)
        @Expect(result.rects[1].right, 9)
        let gaps = FlexLayout(Direction.Horizontal, [FlexItem(), FlexItem(), FlexItem()], gap: Int64.Max).resolve(Rect(0, 0, 3, 1))
        @Expect(gaps.effectiveGap, 1)
        for (rect in gaps.rects) { @Expect(rect.x >= 0 && rect.right <= 3) }
        let frozen = FlexLayout(Direction.Horizontal, [FlexItem(basis: 4, shrink: 0), FlexItem(basis: 4, shrink: 0)]).resolve(Rect(0, 0, 3, 1))
        @Expect(!frozen.constraintsSatisfied)
        @Expect(frozen.rects[1].right, 3)
    }

    @TestCase
    func extremeWeightsAndCoordinatesDoNotOverflow(): Unit {
        let layout = FlexLayout(Direction.Horizontal, [
            FlexItem(basis: Int64.Max, grow: Int64.Max, shrink: Int64.Max),
            FlexItem(basis: Int64.Max, grow: Int64.Max, shrink: Int64.Max)
        ])
        let tiny = layout.split(Rect(Int64.Max - 3, 0, Int64.Max, 1))
        @Expect(tiny[0].width + tiny[1].width, 3)
        @Expect(tiny[1].right, Int64.Max)
        let large = layout.split(Rect(0, 0, Int64.Max, 1))
        @Expect(large[0].width + large[1].width, Int64.Max)
        let growth = FlexLayout(Direction.Horizontal, [FlexItem(grow: Int64.Max), FlexItem(grow: Int64.Max)]).split(Rect(0, 0, 7, 1))
        @Expect(growth[0].width + growth[1].width, 7)
    }

    @TestCase
    func repeatedResizeIsDeterministicAndRespectsFeasibleBounds(): Unit {
        let layout = FlexLayout(Direction.Horizontal, [
            FlexItem(basis: 8, minSize: 2, maxSize: 20),
            FlexItem(basis: 6, grow: 2, minSize: 1, maxSize: 30),
            FlexItem(basis: 4, minSize: 1, maxSize: 10)
        ], gap: 1)
        for (width in 0..100) {
            let area = Rect(3, 2, width, 2)
            let first = layout.resolve(area)
            _ = layout.split(Rect(0, 0, 1, 1))
            let second = layout.resolve(area)
            for (i in 0..first.rects.size) {
                @Expect(first.rects[i], second.rects[i])
                @Expect(first.rects[i].x >= area.x && first.rects[i].right <= area.right)
                @Expect(first.rects[i].width >= 0)
            }
            if (width >= 6) { @Expect(first.constraintsSatisfied) }
        }
    }
}
