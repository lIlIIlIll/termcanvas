package cjtui_api_example

import core.*

main(): Int64 {
    let buffer = Buffer(Rect(0, 0, 60, 20))
    MetricCard("RUNNING", "2", detail: "Active").render(Rect(0, 0, 15, 3), buffer)
    Meter("Progress", 50).render(Rect(16, 0, 30, 1), buffer)
    let legendItem = LegendItem("Done", symbol: "+")
    Legend([legendItem]).render(Rect(0, 4, 20, 1), buffer)
    TimeSeriesChart([1, 2, 3]).render(Rect(0, 5, 3, 3), buffer)
    HeaderBar("Tasks", left: "Local", right: "Ready").render(Rect(0, 8, 30, 1), buffer)
    FooterBar(left: "Help", right: "Quit").render(Rect(0, 9, 30, 1), buffer)
    EmptyState(title: "Empty").render(Rect(0, 10, 20, 2), buffer)
    ErrorBox("Failed").render(Rect(20, 10, 20, 4), buffer)
    LoadingOverlay(label: "Loading").render(Rect(0, 12, 18, 1), buffer)
    Skeleton(rows: 1).render(Rect(0, 13, 10, 1), buffer)
    InlineAlert("Warning").render(Rect(0, 14, 20, 1), buffer)
    Badge("OK").render(Rect(0, 15, 10, 1), buffer)
    if (buffer.getCell(0, 0).symbol != "R" || buffer.getCell(0, 1).symbol != "2" ||
        legendItem.label != "Done" || legendItem.symbol != "+" || buffer.getCell(0, 4).symbol != "+" ||
        buffer.getCell(0, 15).symbol != "[") { throw IllegalStateException("dashboard rendering failed") }
    return 0
}
