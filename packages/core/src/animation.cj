package core

import std.collection.*

/** 单个组件的动画设置；时长按毫秒计算，帧率限制在 1 至 1000。 */
public struct AnimationConfig {
    /** 循环时长，至少为一毫秒。 */
    public let durationMillis: Int64
    /** 组件期望的最高刷新率；应用的调度器可以进一步限制。 */
    public let framesPerSecond: Int64
    /** 是否为该组件安排动画帧。 */
    public let enabled: Bool

    /** 设置循环时长、期望帧率与动画是否启用。
     * @param durationMillis 循环时长，单位为毫秒
     * @param framesPerSecond 期望的最高帧率
     * @param enabled 是否请求动画帧
     */
    public init(durationMillis!: Int64 = 1000, framesPerSecond!: Int64 = 30, enabled!: Bool = true) {
        this.durationMillis = max(1, durationMillis)
        this.framesPerSecond = min(1000, max(1, framesPerSecond))
        this.enabled = enabled
    }
}

/** 根据经过时间计算的动画采样，不依赖实际绘制次数。调度器的采样按组件和应用的帧率上限量化。 */
public struct AnimationSample {
    /** 采样对应的时间轴毫秒数；经调度器采样时按帧率向下取整。 */
    public let elapsedMillis: Int64
    /** 当前循环内经过的毫秒数。 */
    public let cycleMillis: Int64
    /** 当前组件的循环时长。 */
    public let durationMillis: Int64

    /** 按经过时间和循环时长计算采样。
     * @param elapsedMillis 已经过的毫秒数，负数置零
     * @param durationMillis 循环时长，至少为一毫秒
     */
    public init(elapsedMillis: Int64, durationMillis: Int64) {
        this.elapsedMillis = max(0, elapsedMillis)
        this.durationMillis = max(1, durationMillis)
        this.cycleMillis = this.elapsedMillis % this.durationMillis
    }
}

private class AnimationEntry {
    let scope: String
    let id: String
    let group: ?String
    let started: Int64
    var visible: Bool
    var config: AnimationConfig

    init(scope: String, id: String, group: ?String, started: Int64, visible: Bool, config: AnimationConfig) {
        this.scope = scope
        this.id = id
        this.group = group
        this.started = started
        this.visible = visible
        this.config = config
    }
}

/**
 * 管理应用拥有的动画身份，只能从应用事件循环线程访问。身份在 scope 内唯一；
 * 同组组件只共享起始时间，不共享组件状态或配置。组件移除时调用 remove，
 * 容器移除时调用 removeScope；隐藏组件保留时间轴起点，但不请求动画帧。
 */
public class AnimationScheduler {
    private let clock: RuntimeClock
    private let maxFps: Int64
    private let entries = ArrayList<AnimationEntry>()
    private var lastFrame: ?Int64 = None

    /** 设置时钟与应用最大动画帧率；帧率限制在 1 至 1000。
     * @param clock 提供单调时间的时钟
     * @param maxFramesPerSecond 应用的最高动画帧率
     */
    public init(clock!: RuntimeClock = MonotonicRuntimeClock(), maxFramesPerSecond!: Int64 = 30) {
        this.clock = clock
        this.maxFps = min(1000, max(1, maxFramesPerSecond))
    }

    /** 注册组件；身份为空、重复或组名为空时返回 false，已有状态不变。
     * @param scope 组件所属范围
     * @param id 范围内的组件身份
     * @param config 组件动画设置
     * @param group 可选的共享起始时间组
     * @param visible 是否可见
     * @return 注册成功时为 true
     */
    public func register(scope: String, id: String, config!: AnimationConfig = AnimationConfig(), group!: ?String = None, visible!: Bool = true): Bool {
        if (scope.isEmpty() || id.isEmpty() || indexOf(scope, id) >= 0) { return false }
        let now = clock.nowMillis()
        var origin = now
        match (group) {
            case Some(name) =>
                if (name.isEmpty()) { return false }
                for (entry in entries) {
                    match (entry.group) {
                        case Some(existing) => if (existing == name) { origin = entry.started; break }
                        case None => ()
                    }
                }
            case None => ()
        }
        entries.add(AnimationEntry(scope, id, group, origin, visible, config))
        true
    }

    /** 设置组件可见性；身份不存在时返回 false。
     * @param scope 组件所属范围
     * @param id 组件身份
     * @param visible 新的可见性
     * @return 找到组件时为 true
     */
    public func setVisible(scope: String, id: String, visible: Bool): Bool {
        let index = indexOf(scope, id)
        if (index < 0) { return false }
        entries[index].visible = visible
        true
    }

    /** 更新组件设置而保留时间轴起点；身份不存在时返回 false。
     * @param scope 组件所属范围
     * @param id 组件身份
     * @param config 新的动画设置
     * @return 找到组件时为 true
     */
    public func setConfig(scope: String, id: String, config: AnimationConfig): Bool {
        let index = indexOf(scope, id)
        if (index < 0) { return false }
        entries[index].config = config
        true
    }

    /** 移除一个组件；身份不存在时返回 false。
     * @param scope 组件所属范围
     * @param id 组件身份
     * @return 移除成功时为 true
     */
    public func remove(scope: String, id: String): Bool {
        let index = indexOf(scope, id)
        if (index < 0) { return false }
        entries.remove(at: index)
        true
    }

    /** 移除容器中的所有组件；组的最后一个组件移除后，该组时间轴随之释放。
     * @param scope 待移除组件所属范围
     */
    public func removeScope(scope: String): Unit {
        var index = entries.size
        while (index > 0) {
            index--
            if (entries[index].scope == scope) { entries.remove(at: index) }
        }
    }

    /** 按当前时钟读取组件采样；身份不存在时返回 None。采样值按该组件和应用帧率上限中较小者向下量化。
     * @param scope 组件所属范围
     * @param id 组件身份
     * @return 存在时返回采样，否则返回 None
     */
    public func sample(scope: String, id: String): ?AnimationSample {
        let index = indexOf(scope, id)
        if (index < 0) { return None }
        let entry = entries[index]
        let elapsed = max(0, clock.nowMillis() - entry.started)
        let fps = min(maxFps, entry.config.framesPerSecond)
        let interval = (1000 + fps - 1) / fps
        Some(AnimationSample(elapsed / interval * interval, entry.config.durationMillis))
    }

    /** 距下一动画帧的毫秒数；没有可见且启用的动画时返回 None。
     * @return 距下一帧的毫秒数，或无活动动画时返回 None
     */
    public func nextTimeoutMillis(): ?Int64 {
        var fps: Int64 = 0
        for (entry in entries) {
            if (entry.visible && entry.config.enabled) { fps = max(fps, entry.config.framesPerSecond) }
        }
        if (fps == 0) { return None }
        fps = min(fps, maxFps)
        let interval = (1000 + fps - 1) / fps
        match (lastFrame) {
            case Some(previous) => Some(max(0, interval - max(0, clock.nowMillis() - previous)))
            case None => Some(0)
        }
    }

    /** 记录一帧已呈现；App 将其他事件请求的完整帧也计入刷新间隔，局部帧不计入。 */
    public func framePresented(): Unit { lastFrame = Some(clock.nowMillis()) }

    private func indexOf(scope: String, id: String): Int64 {
        for (index in 0..entries.size) {
            if (entries[index].scope == scope && entries[index].id == id) { return index }
        }
        -1
    }
}
