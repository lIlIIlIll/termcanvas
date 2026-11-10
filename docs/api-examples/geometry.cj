package cjtui_api_example

import core.*

main(): Int64 {
    let area = Rect(2, 3, 20, 10)
    let point = Position(area.x, area.y)
    if (point.x != 2 || point.y != 3 || area.width != 20 || area.height != 10 ||
        area.right != 22 || area.bottom != 13 || !(area == Rect(2, 3, 20, 10))) {
        throw IllegalStateException("incorrect rectangle")
    }
    let spacing = Spacing(left: 1, right: 2, top: 1, bottom: 2)
    if (spacing.left != 1 || spacing.right != 2 || spacing.top != 1 || spacing.bottom != 2 ||
        spacing.inner(area) != Rect(3, 4, 17, 7)) { throw IllegalStateException("incorrect spacing") }
    if (Spacing.zero().inner(area) != area || Spacing.all(1).inner(area) != Rect(3, 4, 18, 8) ||
        Spacing.symmetric(horizontal: 1, vertical: 2).inner(area) != Rect(3, 5, 18, 6)) {
        throw IllegalStateException("incorrect spacing helpers")
    }
    let constraints = [Constraint.Length(3), Constraint.Percent(20), Constraint.Min(2),
        Constraint.Max(4), Constraint.Ratio(1, 10)]
    let layout = Layout(Direction.Horizontal, constraints, flex: Flex.Center, gap: 1, margin: Spacing.all(1))
    if (layout.split(area).size != 5) { throw IllegalStateException("incorrect layout count") }
    let horizontal = Layout.horizontal([Constraint.Length(2), Constraint.Min(1)])
        .withFlex(Flex.Start).withGap(1).withMargin(Spacing.zero())
    let vertical = Layout.vertical([Constraint.Length(2), Constraint.Min(1)]).withFlex(Flex.End)
    let distributed = Layout(Direction.Vertical, [Constraint.Length(2), Constraint.Length(2)], flex: Flex.SpaceBetween)
    if (horizontal.split(area).size != 2 || vertical.split(area).size != 2 || distributed.split(area).size != 2) {
        throw IllegalStateException("incorrect layout helpers")
    }
    return 0
}
