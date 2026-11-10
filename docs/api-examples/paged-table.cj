package cjtui_api_example

import core.*

class ExampleSource <: TableDataSource {
    public func load(request: TablePageRequest): TablePage {
        TablePage([TableDataRow("a", ["Alpha"]), TableDataRow("b", ["Beta"])], 2)
    }
}

main(): Int64 {
    let model = PagedTableModel(pageSize: 2, maxPages: 2)
    let requests = model.requestViewport(0, 2)
    if (requests.size != 1 || !model.isPending(requests[0]) || model.hasTotal()) { throw IllegalStateException("page request failed") }
    let page = ExampleSource().load(requests[0])
    if (!model.accept(requests[0], page) || model.cachedRowCount() != 2 || model.totalRows() != 2) { throw IllegalStateException("page acceptance failed") }
    model.selectIndex(0)
    model.toggle("a")
    if (model.selectedId() != Some("a") || !model.isSelected("a")) { throw IllegalStateException("page selection failed") }
    _ = model.setQuery(TableQuery(filter: "Beta"))
    if (model.accept(requests[0], page) || model.hasTotal() || model.selectedId() != Some("a")) { throw IllegalStateException("stale page accepted") }
    return 0
}
