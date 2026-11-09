package cjtui_api_example

import core.*

main(): Int64 {
    let snapshot = VirtualTranscriptMetrics(2, 10, 3, 8, cacheLookups: 5, cacheHits: 4,
        cacheMisses: 1, layoutCalls: 1, rowsPainted: 3, fallbackFullViewportPaints: 1)
    if (snapshot.materialized != 2 || snapshot.cacheEntries != 10 || snapshot.measuredEntries != 3 ||
        snapshot.cachedRows != 8 || snapshot.cacheLookups != 5 || snapshot.cacheHits != 4 ||
        snapshot.cacheMisses != 1 || snapshot.layoutCalls != 1 || snapshot.rowsPainted != 3 ||
        snapshot.fallbackFullViewportPaints != 1) { throw IllegalStateException("transcript metrics failed") }
    return 0
}
