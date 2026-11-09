package cjtui_api_example

import core.*

main(): Int64 {
    let store = TextDecorationStore(revision: 1)
    let update = TextDecorationUpdate(1, 2, 5, [TextDecoration(2, 5, Style(fg: Color.Red))])
    if (update.revision != 1 || update.start != 2 || update.end != 5 || update.spans.size != 1 ||
        !store.apply(update) || store.cachedRanges() != 1) {
        throw IllegalStateException("decoration update failed")
    }
    let provider: TextDecorationProvider = store
    if (provider.revision() != 1 || provider.query(0, 10).size != 1 || store.queryCount() != 1) {
        throw IllegalStateException("decoration query failed")
    }
    let edit = TextEditDelta(0, 0, 2, 1, 2)
    if (edit.start != 0 || edit.end != 0 || edit.insertedBytes != 2 ||
        edit.beforeRevision != 1 || edit.afterRevision != 2) { throw IllegalStateException("incorrect edit") }
    provider.onEdit(edit)
    let shifted = store.query(0, 10)
    if (store.revision() != 2 || shifted.size != 1 || shifted[0].start != 4 || shifted[0].end != 7 ||
        store.apply(update)) { throw IllegalStateException("incorrect decoration revision") }
    store.reset(3)
    if (store.cachedRanges() != 0 || store.invalidatedRanges() != 1 || store.revision() != 3) {
        throw IllegalStateException("decoration reset failed")
    }
    return 0
}
