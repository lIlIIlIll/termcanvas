package cjtui_api_example

import core.*

main(): Int64 {
    let kinds = [BorderKind.Auto, BorderKind.Ascii, BorderKind.Unicode, BorderKind.Rounded,
        BorderKind.Double, BorderKind.Dashed, BorderKind.NoBorder]
    let alignments = [TitleAlign.Left, TitleAlign.Center, TitleAlign.Right]
    let states = [BoxState.Normal, BoxState.Focused, BoxState.Active, BoxState.Error, BoxState.Disabled]
    let border = BorderSet(horizontal: "-", vertical: "|", topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+")
    let sets = [BorderSet.ascii(), BorderSet.unicode(), BorderSet.rounded(), BorderSet.doubleLine(), BorderSet.dashed()]
    if (kinds.size != 7 || alignments.size != 3 || states.size != 5 || sets.size != 5 ||
        border.horizontal != "-" || border.vertical != "|" || border.topLeft != "+" || border.topRight != "+" ||
        border.bottomLeft != "+" || border.bottomRight != "+") { throw IllegalStateException("incorrect borders") }
    let style = Style(fg: Color.Cyan)
    let options = BlockOptions(title: "Build", borderKind: BorderKind.Unicode, border: border,
        titleAlign: TitleAlign.Center, padding: Spacing.zero(), margin: Spacing.zero(),
        backgroundStyle: style, borderStyle: style, contentStyle: style, titleStyle: style,
        state: BoxState.Focused, asciiFallback: false, theme: Theme.graphite())
    if (options.title != "Build" || options.border.horizontal != "-" || options.padding.left != 0 ||
        options.margin.left != 0 || options.backgroundStyle != style || options.borderStyle != style ||
        options.contentStyle != style || options.titleStyle != style || options.asciiFallback || options.theme.isNone()) {
        throw IllegalStateException("incorrect block options")
    }
    match ((options.borderKind, options.titleAlign, options.state)) {
        case (BorderKind.Unicode, TitleAlign.Center, BoxState.Focused) => ()
        case _ => throw IllegalStateException("incorrect block state")
    }
    let area = Rect(0, 0, 20, 5)
    let block = Block(options)
    let buffer = Buffer(area)
    if (block.inner(area) != Rect(1, 1, 18, 3) || block.inner(area, theme: Theme.light()) != Rect(1, 1, 18, 3) ||
        block.renderInner(area, buffer) != Rect(1, 1, 18, 3)) { throw IllegalStateException("incorrect block interior") }
    block.render(area, buffer)
    let panel = Panel(block: Block(title: "Panel", style: style), child: Paragraph("content"))
    _ = panel.renderInner(area, buffer)
    Panel(options, child: Paragraph("text", wrap: WrapMode.Word, align: TextAlign.Center)).render(area, buffer)
    if (buffer.getCell(0, 0).symbol != "+") { throw IllegalStateException("panel border failed") }
    return 0
}
