package termcanvas_architecture_proof_step0

import core.*
import std.collection.*
import std.convert.*
import std.env.*
import std.time.*

class ProofTranscriptSource <: VirtualTranscriptSource {
    private let documents = ArrayList<String>()
    private let revisions = ArrayList<Int64>()

    init(count: Int64) {
        let normalized = max(1, count)
        for (index in 0..normalized) {
            documents.add(if (index == normalized - 1) {
                "tail"
            } else {
                "history ${index}: deterministic transcript text for wrapping"
            })
            revisions.add(0)
        }
    }

    public func size(): Int64 { documents.size }
    public func itemId(index: Int64): String { "proof-${index}" }
    public func revision(index: Int64): Int64 { revisions[index] }
    public func document(index: Int64, _: Int64, _: String): Document {
        Document.plain(documents[index])
    }

    func replaceTail(value: String): Unit {
        let index = documents.size - 1
        documents[index] = value
        revisions[index]++
    }

    func appendItem(): Unit {
        documents.add("new transcript item ${documents.size + 1}")
        revisions.add(0)
    }
}

func envText(name: String, fallback: String): String {
    match (getVariable(name)) {
        case Some(value) => value
        case None => fallback
    }
}

func envInt(name: String, fallback: Int64): Int64 {
    try {
        Int64.parse(envText(name, fallback.toString()))
    } catch (_: Exception) {
        fallback
    }
}

func metricDelta(after: Int64, before: Int64): Int64 { max(0, after - before) }

func repeatText(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..max(0, count)) { out.append(value) }
    out.toString()
}

func mutateWorkload(
    workload: String,
    sample: Int64,
    source: ProofTranscriptSource,
    view: VirtualTranscriptView,
    baseWidth: Int64,
    baseHeight: Int64
): Rect {
    if (workload == "scroll_line") {
        _ = view.handle(KeyEvent(KeyCode.Up))
    } else if (workload == "scroll_page") {
        _ = view.handle(KeyEvent(KeyCode.PageUp))
    } else if (workload == "scroll_continuous") {
        _ = view.handle(KeyEvent(if (sample % 2 == 0) { KeyCode.Up } else { KeyCode.Down }))
    } else if (workload == "stream_a_no_wrap") {
        source.replaceTail("short token ${sample}")
    } else if (workload == "stream_b_wrap_cross") {
        source.replaceTail(repeatText("w", max(1, baseWidth - 1)) + "X${sample}")
    } else if (workload == "stream_c_complete_line") {
        source.replaceTail("first line\ncomplete line ${sample}")
    } else if (workload == "stream_d_new_item") {
        source.appendItem()
    }
    if (workload == "resize_small_width_oscillation") {
        return Rect(0, 0, baseWidth - (sample % 2), baseHeight)
    }
    if (workload == "resize_large_width_jump" || workload == "resize_width_height") {
        return if (sample % 2 == 0) { Rect(0, 0, 60, 18) } else { Rect(0, 0, 120, 36) }
    }
    if (workload == "resize_huge_width_extremes" || workload == "resize_manual_width_extremes") {
        return if (sample % 2 == 0) { Rect(0, 0, 20, baseHeight) } else { Rect(0, 0, 160, baseHeight) }
    }
    if (workload == "resize_continuous_width") {
        return Rect(0, 0, 60 + sample % 61, baseHeight)
    }
    if (workload == "resize_height_only") {
        return Rect(0, 0, baseWidth, if (sample % 2 == 0) { 18 } else { 36 })
    }
    Rect(0, 0, baseWidth, baseHeight)
}

main(): Int64 {
    let workload = envText("STEP0_WORKLOAD", "scroll_line")
    let history = max(1, envInt("STEP0_HISTORY", 100))
    let iterations = max(1, envInt("STEP0_ITERATIONS", 120))
    let warmup = max(0, envInt("STEP0_WARMUP", 10))
    let baseWidth = max(10, envInt("STEP0_WIDTH", 100))
    let baseHeight = max(4, envInt("STEP0_HEIGHT", 28))
    let metricsMode = envText("STEP0_METRICS", "on")
    let metricsEnabled = metricsMode == "on"
    let buildId = envText("STEP0_BUILD_ID", "unknown")
    let source = ProofTranscriptSource(history)
    let state = VirtualTranscriptState(followBottom: true)
    let setupStart = MonoTime.now()
    let view = VirtualTranscriptView(
        source,
        state: state,
        instrumentationEnabled: metricsEnabled
    )
    var area = Rect(0, 0, baseWidth, baseHeight)
    let backend = TestBackend(area: area, captureSnapshots: false)
    let terminal = Terminal(backend, instrumentationEnabled: metricsEnabled)
    _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
    if (workload == "resize_manual_width_extremes") {
        _ = view.handle(KeyEvent(KeyCode.PageUp))
        _ = terminal.draw { frame => frame.renderWidget(view, frame.area) }
    }
    let setupNanos = (MonoTime.now() - setupStart).toNanoseconds()
    println("{\"kind\":\"setup\",\"benchmark\":\"${workload}\",\"history_count\":${history},\"setup_nanos\":${setupNanos}}")

    var order: Int64 = -warmup
    while (order < iterations) {
        let sample = max(0, order)
        let updateStart = MonoTime.now()
        let nextArea = mutateWorkload(workload, sample, source, view, baseWidth, baseHeight)
        let updateNanos = (MonoTime.now() - updateStart).toNanoseconds()
        if (nextArea != area) {
            area = nextArea
            backend.setSize(area)
        }
        let before = view.instrumentationMetrics()
        let totalStart = MonoTime.now()
        let render = terminal.draw { frame => frame.renderWidget(view, frame.area) }
        let operationNanos = (MonoTime.now() - totalStart).toNanoseconds()
        let after = view.instrumentationMetrics()
        if (order >= 0) {
            println(
                "{\"kind\":\"sample\",\"benchmark\":\"${workload}\",\"sample_id\":${order + 1}," +
                "\"sample_order\":${order + 1},\"build_identifier\":\"${buildId}\",\"history_count\":${history}," +
                "\"terminal_width\":${area.width},\"terminal_height\":${area.height},\"metrics_mode\":\"${metricsMode}\"," +
                "\"stage_timings\":{\"dispatch_nanos\":0,\"update_nanos\":${updateNanos},\"layout_nanos\":-1," +
                "\"render_nanos\":${render.renderNanos},\"diff_nanos\":${render.diffNanos},\"write_nanos\":${render.writeNanos}," +
                "\"total_nanos\":${operationNanos}},\"counters\":{" +
                "\"events_processed\":1,\"region_visits\":-1,\"layout_calls\":" + metricDelta(after.layoutCalls, before.layoutCalls).toString() + "," +
                "\"cache_hits\":" + metricDelta(after.cacheHits, before.cacheHits).toString() + ",\"cache_misses\":" + metricDelta(after.cacheMisses, before.cacheMisses).toString() + "," +
                "\"cache_evictions\":-1,\"document_requests\":" + metricDelta(after.documentRequests, before.documentRequests).toString() + "," +
                "\"documents_materialized\":" + metricDelta(after.documentsMaterialized, before.documentsMaterialized).toString() + "," +
                "\"wrap_input_bytes\":" + metricDelta(after.wrapInputBytes, before.wrapInputBytes).toString() + "," +
                "\"metadata_touches\":" + metricDelta(after.metadataTouches, before.metadataTouches).toString() + "," +
                "\"height_index_reset_entries\":" + metricDelta(after.heightIndexResetEntries, before.heightIndexResetEntries).toString() + "," +
                "\"height_index_update_calls\":" + metricDelta(after.heightIndexUpdateCalls, before.heightIndexUpdateCalls).toString() + "," +
                "\"height_index_nodes_touched\":" + metricDelta(after.heightIndexNodesTouched, before.heightIndexNodesTouched).toString() + "," +
                "\"height_index_grow_operations\":" + metricDelta(after.heightIndexGrowOperations, before.heightIndexGrowOperations).toString() + "," +
                "\"measurement_generation_bumps\":" + metricDelta(after.measurementGenerationBumps, before.measurementGenerationBumps).toString() + "," +
                "\"stale_entries_encountered\":" + metricDelta(after.staleEntriesEncountered, before.staleEntriesEncountered).toString() + "," +
                "\"entries_remeasured\":" + metricDelta(after.entriesRemeasured, before.entriesRemeasured).toString() + "," +
                "\"estimate_corrections\":" + metricDelta(after.estimateCorrections, before.estimateCorrections).toString() + "," +
                "\"anchor_corrections\":" + metricDelta(after.anchorCorrections, before.anchorCorrections).toString() + "," +
                "\"height_metadata_entries\":" + after.heightMetadataEntries.toString() + "," +
                "\"height_index_nodes\":" + after.heightIndexNodes.toString() + "," +
                "\"buffer_cell_attempts\":${render.bufferCellAttempts},\"buffer_cell_writes\":${render.bufferCellWrites}," +
                "\"diff_cells\":${render.diffCells},\"diff_spans\":${render.diffSpans},\"ansi_bytes\":${render.ansiBytes}}}"
            )
        }
        order++
    }
    0
}
