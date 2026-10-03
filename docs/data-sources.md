# Scalable tables and lazy trees

`VirtualTable(columns, model)` consumes an application-owned `PagedTableModel`.
The model stores a bounded page cache and query/selection state. It does not
start threads, schedule work, or mutate a source. `render` reads cached rows only.

## Paged table update flow

1. Keep a `PagedTableModel(pageSize: 128, maxPages: 8)` in application state.
2. Implement `TableDataSource.load(request)` to apply `request.query` and return
   exactly the requested slice plus its total count. Each `TableDataRow` has a
   stable, nonempty ID; IDs identify records, not their current sorted indexes.
3. From the App update callback call `model.requestViewport(table.offset, rows)`.
   Dispatch the returned requests through the existing `Command.AsyncTask` path.
4. Publish worker results through an application-owned synchronized mailbox or
   the existing external-port integration. In update, call `accept(request,page)`
   or `fail(request,message)`. Worker threads must not mutate the model.
5. Use `requestViewport(..., retry: true)` to retry errors. Call `invalidate()`
   after a source revision, or `setQuery(TableQuery(...))` for a new query.

The request captures an immutable query, query revision, page offset/limit, and
unique request ID. Responses from a prior query, a replaced request, or a page
that has left the requested viewport are ignored. Invalid page lengths and
empty/duplicate IDs within a page become a visible error. Source implementations
must provide unique IDs across the dataset and consistent ordering/counts for a
source revision. A page reporting a changed total is rejected with an error; call
`invalidate()` when that revision changes.

The model retains at most `maxPages` pages and at most `maxPages` in-flight page
requests. Cache eviction does not discard selected record IDs. Focus is tracked
by record ID and acquires its new visible index when that record's page arrives.
`selectedIds()` returns multiselection IDs; `selectedId()` returns focused ID.
Select unloaded rows by index only when the application wants focus to follow
that position upon arrival. `selectId` preserves record identity through sorting.

A viewport spanning more than `maxPages` pages requests its first `maxPages`
pages; increase cache capacity/page size to cover the largest intended viewport.
Providers must not build a million-entry array to serve a 20-row viewport. The
core test `millionRowsUseOnlyRequestedViewportPagesWithExternalQuery` exercises
an offset of 900,000, external sort/filter, and bounded cache eviction.

The table's mouse overload takes the same outer `Rect` used for rendering:
header click toggles external sort, body click focuses a row/column, Ctrl-click
toggles ID multiselection, and wheel scrolls. Call `requestViewport` after input
so newly exposed pages can be loaded.

## Synchronous provider migration

`VirtualTable(columns, rowCount, rowAt, ...)` remains supported. Its row cache now
has a `cacheCapacity` parameter (default 1,024 rows). Unsorted/unfiltered drawing
still fetches only viewport rows. Existing local sort/filter intentionally scans
the supplied dataset and constructs visible indexes; use `PagedTableModel` for
large or remote sources. The legacy `selectedRowIndices`/`SelectionModel` APIs
are positional; use the paged model's ID selection APIs on the new path.

For the paged path, keep query/selection canonical in the model. Use the widget's
`sortBy`/`setFilter` methods or mutate the model from update, then dispatch its
new page requests. Do not combine the paged model with legacy external
`SortState`/`FilterState`/`SelectionModel` bindings. No source fetch is triggered
by rendering, and changing public table fields alone does not replace a model
query.

## Lazy tree source

Implement `TreeDataSource` with:

- `rootCount()` for root sibling count;
- `nodeAt(path)` for one indexed node, whose metadata includes `childCount`;
- `pathForId(id)` for efficient stable ID lookup.

A path is an array of zero-based child indexes from the root. `LazyTreeModel`
retains only explicitly expanded branches. It counts collapsed sibling runs
arithmetically and skips entire expanded subtrees when resolving visible rows.
`Tree(model)` reads just the viewport's node records; expanding a parent does
not enumerate all children. A million-child regression asserts exactly ten
provider reads for a ten-row viewport near the end of the tree.

`selectById` preserves selection through expansion/collapse and viewport shifts.
When an ancestor collapses, the selected ID is retained while `selectedIndex()`
returns `None`; re-expanding it restores the visible index. `refresh()` discards
indexed expansion state after a source revision and retains selected ID. The
application can expand desired IDs again using the source's new paths.

The eager `TreeNode` constructor and `Tree([roots])` remain supported. Eager
`findById`, `expandAll` and mutable node handles are intended for that stored tree.
`expandAll()` on a lazy tree throws explicitly: enumerating an arbitrary external
tree would defeat its loading contract. Use `model.setExpanded(id,true)` instead.
For lazy metadata lookup use `model.findById(id)`; the eager widget lookup cannot
return mutable `TreeNode` handles for an external source. Visible counts saturate
at `Int64.Max`; IDs beyond the representable visible index range cannot be selected.

Mouse clicks on a branch marker toggle expansion; label clicks select its stable
ID. Keyboard arrows, Home/End and PageUp/PageDown operate without enumerating
all sibling nodes.

## Runnable integration

`examples/data_browser` uses a deterministic indexed million-row provider and a
million-child lazy tree. `/` toggles a provider-side `ready` filter, `s` reverses
sort, `e` demonstrates provider failure, and `r` retries. Paging uses real App
async commands and a bounded mutex-protected result mailbox. Update alone applies
completed pages; changing query/viewport cancels obsolete tasks and prevents
stale publications. The provider is synthetic and requires no database service.
