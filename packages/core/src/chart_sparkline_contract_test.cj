package core

import std.unittest.*
import std.unittest.testmacro.*

func chartSparklineContractFill(buffer: Buffer, symbol: String): Unit {
    for (y in buffer.area.y..buffer.area.bottom) {
        for (x in buffer.area.x..buffer.area.right) {
            buffer.setString(x, y, symbol)
        }
    }
}

func chartSparklineContractRow(buffer: Buffer, y: Int64): String {
    var text = ""
    for (x in buffer.area.x..buffer.area.right) {
        text += buffer.getCell(x, y).symbol
    }
    text
}

func chartSparklineContractBarHeight(buffer: Buffer, x: Int64, area: Rect): Int64 {
    var height: Int64 = 0
    for (y in area.y..area.bottom) {
        if (buffer.getCell(x, y).symbol == "#") { height++ }
    }
    height
}

func chartSparklineContractOutsideChanges(buffer: Buffer, area: Rect): Int64 {
    var changed: Int64 = 0
    for (y in buffer.area.y..buffer.area.bottom) {
        for (x in buffer.area.x..buffer.area.right) {
            if ((x < area.x || x >= area.right || y < area.y || y >= area.bottom) &&
                buffer.getCell(x, y).symbol != ".") {
                changed++
            }
        }
    }
    changed
}

func progressBarContractFilled(buffer: Buffer, area: Rect): Int64 {
    var filled: Int64 = 0
    for (x in area.x..area.right) {
        if (buffer.getCell(x, area.y).symbol == "#") { filled++ }
    }
    filled
}

@Test
class ChartSparklineT017T018Test {
    @TestCase
    func chartT017FixedScaleSaturatesAndAutoScaleKeepsMinimumBars(): Unit {
        let area = Rect(2, 2, 3, 4)
        let fixed = Buffer(Rect(0, 0, 10, 8))
        chartSparklineContractFill(fixed, ".")
        Chart([2, 4], maxValue: 4).render(area, fixed)
        @Expect(chartSparklineContractBarHeight(fixed, 2, area), 2)
        @Expect(chartSparklineContractBarHeight(fixed, 3, area), 4)
        @Expect(fixed.getCell(2, 2).symbol, ".")
        @Expect(fixed.getCell(4, 2).symbol, ".")
        @Expect(chartSparklineContractOutsideChanges(fixed, area), 0)

        let saturated = Buffer(Rect(0, 0, 10, 8))
        chartSparklineContractFill(saturated, ".")
        Chart([2, 8], maxValue: 4).render(area, saturated)
        @Expect(chartSparklineContractBarHeight(saturated, 2, area), 2)
        @Expect(chartSparklineContractBarHeight(saturated, 3, area), 4)

        let defaultAuto = Buffer(Rect(0, 0, 10, 8))
        chartSparklineContractFill(defaultAuto, ".")
        Chart([2, 4]).render(area, defaultAuto)
        @Expect(chartSparklineContractBarHeight(defaultAuto, 2, area), 2)
        @Expect(chartSparklineContractBarHeight(defaultAuto, 3, area), 4)

        let automatic = Buffer(Rect(0, 0, 10, 8))
        chartSparklineContractFill(automatic, ".")
        let autoArea = Rect(2, 2, 3, 4)
        Chart([-10, 0, 3], maxValue: -1).render(autoArea, automatic)
        @Expect(chartSparklineContractBarHeight(automatic, 2, autoArea), 1)
        @Expect(chartSparklineContractBarHeight(automatic, 3, autoArea), 1)
        @Expect(chartSparklineContractBarHeight(automatic, 4, autoArea), 4)
        @Expect(automatic.getCell(2, 2).symbol, ".")
        @Expect(automatic.getCell(3, 2).symbol, ".")

        let large = Buffer(Rect(0, 0, 10, 8))
        chartSparklineContractFill(large, ".")
        let largeArea = Rect(2, 2, 3, 4)
        Chart([Int64.Max, Int64.Max / 2, Int64.Min], maxValue: Int64.Max).render(largeArea, large)
        @Expect(chartSparklineContractBarHeight(large, 2, largeArea), 4)
        @Expect(chartSparklineContractBarHeight(large, 3, largeArea), 1)
        @Expect(chartSparklineContractBarHeight(large, 4, largeArea), 1)

        let empty = Buffer(Rect(0, 0, 4, 4))
        chartSparklineContractFill(empty, ".")
        let before = empty.copy()
        Chart([]).render(empty.area, empty)
        @Expect(empty.diff(before).size, 0)
    }

    @TestCase
    func sparklineT018DrawsLevelsInBlockInnerRowAndKeepsEmptyBlock(): Unit {
        let area = Rect(2, 1, 10, 4)
        let block = Block(title: "Trend")
        let buffer = Buffer(Rect(0, 0, 16, 7))
        chartSparklineContractFill(buffer, ".")
        Sparkline([1, 3, 2], maxValue: 3, block: Some(block)).render(area, buffer)
        let inner = block.inner(area)
        @Assert(chartSparklineContractRow(buffer, area.y).contains("Trend"))
        @Expect(buffer.getCell(inner.x, inner.y).symbol, ".")
        @Expect(buffer.getCell(inner.x + 1, inner.y).symbol, "#")
        @Expect(buffer.getCell(inner.x + 2, inner.y).symbol, "-")
        @Expect(buffer.getCell(inner.x + 3, inner.y).symbol, ".")
        @Expect(buffer.getCell(inner.x, inner.y + 1).symbol, ".")
        @Expect(chartSparklineContractOutsideChanges(buffer, area), 0)

        let emptyBlock = Block(title: "Empty")
        let emptyBuffer = Buffer(Rect(0, 0, 16, 7))
        chartSparklineContractFill(emptyBuffer, ".")
        Sparkline([], block: Some(emptyBlock)).render(area, emptyBuffer)
        let emptyInner = emptyBlock.inner(area)
        @Assert(chartSparklineContractRow(emptyBuffer, area.y).contains("Empty"))
        for (x in emptyInner.x..emptyInner.right) {
            @Expect(emptyBuffer.getCell(x, emptyInner.y).symbol, ".")
        }
        @Expect(chartSparklineContractOutsideChanges(emptyBuffer, area), 0)

        let legacy = Buffer(Rect(0, 0, 5, 1))
        Sparkline([0, 1, 2, 3, 4], maxValue: 4).render(legacy.area, legacy)
        @Expect(chartSparklineContractRow(legacy, 0), " .-=#")
    }
}

@Test
class ProgressBarT020Test {
    @TestCase
    func percentageProgressClampsAndScalesBoundaryValues(): Unit {
        let area = Rect(0, 0, 20, 1)
        let values: Array<Int64> = [-1, 0, 5000, 10000, Int64.Max]
        let expected: Array<Int64> = [0, 0, 10, 20, 20]
        for (i in 0..values.size) {
            let buffer = Buffer(area)
            ProgressBar(values[i], total: 10000).render(area, buffer)
            @Expect(progressBarContractFilled(buffer, area), expected[i])
        }

        let zeroValue = Buffer(area)
        ProgressBar(0, total: 0).render(area, zeroValue)
        @Expect(progressBarContractFilled(zeroValue, area), 0)

        let zeroTotal = Buffer(area)
        ProgressBar(1, total: 0).render(area, zeroTotal)
        @Expect(progressBarContractFilled(zeroTotal, area), 20)

        let negativeTotal = Buffer(area)
        ProgressBar(1, total: -5).render(area, negativeTotal)
        @Expect(progressBarContractFilled(negativeTotal, area), 20)
    }
}
