package core

/** 可信提供者对 Nerd Font 字形覆盖情况的判断。Unknown 不证明字体缺失。 */
public enum GlyphCapability {
    | Unknown
    | VerifiedSupported
    | Unsupported
}

/**
 * 应用提供的可信字体能力来源。只有确知终端实际使用的字体覆盖所需字形时，
 * 才可返回 VerifiedSupported。不得读取终端输入；实现应在 budgetMillis 内返回。
 */
public interface GlyphCapabilityProvider {
    func probe(budgetMillis: Int64): GlyphCapability
}

/** 没有通用可靠探测协议时的保守提供者，不读取终端输入。 */
public class UnknownGlyphCapabilityProvider <: GlyphCapabilityProvider {
    public init() {}
    public func probe(_: Int64): GlyphCapability { GlyphCapability.Unknown }
}

/**
 * 应用级图标协商状态。将实例附加到 App 后自动后台探测；在 render 中使用
 * applyTo(theme) 应用结果。所有方法只能从应用事件循环线程调用。
 * 超时和异常采用 Unicode；provider 若不遵守期限，不会阻塞 UI，但其返回前
 * 不会并发启动新的探测。显式覆盖总是优先于探测结果。
 * 未使用的会话应调用 close 释放资源；附加后 App 在退出时关闭会话。
 */
public class GlyphCapabilitySession {
    private let provider: GlyphCapabilityProvider
    private let timeoutMillis: Int64
    private let clock: RuntimeClock
    private let runtime = AsyncRuntime(maxPendingTasks: 1)
    private var generation: Int64 = 0
    private var inflightGeneration: Int64 = -1
    private var startedAt: Int64 = 0
    private var inflight = false
    private var requested = true
    private var active = false
    private var closed = false
    private var attached = false
    private var capability: GlyphCapability = GlyphCapability.Unknown
    private var overrideValue: ?IconSet = None
    private var reportedIcon: Int64 = 0
    private var reportedCapability: Int64 = 0

    /** 配置可信提供者和最长等待毫秒数；非正时长按一毫秒处理。 */
    public init(provider!: GlyphCapabilityProvider = UnknownGlyphCapabilityProvider(), timeoutMillis!: Int64 = 150, clock!: RuntimeClock = MonotonicRuntimeClock()) {
        this.provider = provider
        this.timeoutMillis = max(1, timeoutMillis)
        this.clock = clock
    }

    /** 当前图标集；未经可靠确认时采用 Unicode。 */
    public func iconSet(): IconSet {
        match (overrideValue) {
            case Some(value) => value
            case None => match (capability) {
                case GlyphCapability.VerifiedSupported => IconSet.NerdFont
                case _ => IconSet.Unicode
            }
        }
    }

    /** 最近一次有效探测结果；超时、失败和显式切换后为 Unknown。 */
    public func detected(): GlyphCapability { capability }

    /** 复制主题并将图标集设为当前协商结果。 */
    public func applyTo(theme: Theme): Theme { theme.withIconSet(iconSet()) }

    /** 设置或清除显式图标集。清除覆盖后重新开始协商；关闭后无效果。 */
    public func setOverride(value: ?IconSet): Unit {
        if (closed) { return }
        overrideValue = value
        invalidate()
        requested = value.isNone()
    }

    /** 请求后台重新探测；已有显式覆盖时保留覆盖，不启动探测；关闭后无效果。 */
    public func requestProbe(): Unit {
        if (closed) { return }
        invalidate()
        requested = overrideValue.isNone()
    }

    private func invalidate(): Unit {
        generation = if (generation == Int64.Max) { 0 } else { generation + 1 }
        capability = GlyphCapability.Unknown
        active = false
    }

    // Only App owns and polls this runtime, so task IDs cannot collide with
    // application AsyncTask IDs and a provider never reads terminal input.
    func tryAttach(): Bool {
        if (closed || attached) { return false }
        attached = true
        true
    }

    func poll(): Bool {
        if (closed) { return false }
        for (event in runtime.drain()) {
            match (event) {
                case Event.AsyncCompleted(_, Event.DataReady(kind, completedGeneration)) =>
                    inflight = false
                    if (active && completedGeneration == generation && completedGeneration == inflightGeneration && elapsed() < timeoutMillis) {
                        capability = match (kind) {
                            case "supported" => GlyphCapability.VerifiedSupported
                            case "unsupported" => GlyphCapability.Unsupported
                            case _ => GlyphCapability.Unknown
                        }
                        active = false
                    }
                case Event.AsyncFailed(_, _) | Event.AsyncCancelled(_) =>
                    inflight = false
                    if (active && inflightGeneration == generation) {
                        capability = GlyphCapability.Unknown
                        active = false
                    }
                case _ => ()
            }
        }
        if (active && elapsed() >= timeoutMillis) {
            capability = GlyphCapability.Unknown
            active = false
        }
        if (requested && !inflight && overrideValue.isNone()) {
            requested = false
            inflight = true
            active = true
            startedAt = clock.nowMillis()
            inflightGeneration = generation
            let taskGeneration = generation
            let source = provider
            let budget = timeoutMillis
            let started = runtime.start("glyph-capability", { =>
                let kind = match (source.probe(budget)) {
                    case GlyphCapability.VerifiedSupported => "supported"
                    case GlyphCapability.Unsupported => "unsupported"
                    case GlyphCapability.Unknown => "unknown"
                }
                Event.DataReady(kind, taskGeneration)
            })
            match (started) {
                case Event.AsyncFailed(_, _) => inflight = false; active = false
                case _ => ()
            }
        }
        let current = iconCode(iconSet())
        let currentCapability = capabilityCode(capability)
        let changed = current != reportedIcon || currentCapability != reportedCapability
        reportedIcon = current
        reportedCapability = currentCapability
        changed
    }

    func nextTimeoutMillis(): ?Int64 {
        if (closed) { return None }
        if (iconCode(iconSet()) != reportedIcon || capabilityCode(capability) != reportedCapability || (requested && !inflight)) { return Some(0) }
        if (active) { return Some(max(0, timeoutMillis - elapsed())) }
        None
    }

    func eventSource(): EventSource { runtime.eventSource() }

    /** 释放会话资源，可重复调用。关闭后不能重新附加或探测；附加后也可提前关闭，
     * App 运行和退出时将安全地跳过或再次关闭它。已探测结果清除，显式图标覆盖保留。
     */
    public func close(): Unit {
        if (closed) { return }
        closed = true
        invalidate()
        requested = false
        runtime.cancelAll()
    }

    private func elapsed(): Int64 { max(0, clock.nowMillis() - startedAt) }
    private func iconCode(value: IconSet): Int64 {
        match (value) { case IconSet.Unicode => 0; case IconSet.NerdFont => 1; case IconSet.Ascii => 2 }
    }
    private func capabilityCode(value: GlyphCapability): Int64 {
        match (value) { case GlyphCapability.Unknown => 0; case GlyphCapability.VerifiedSupported => 1; case GlyphCapability.Unsupported => 2 }
    }
}
