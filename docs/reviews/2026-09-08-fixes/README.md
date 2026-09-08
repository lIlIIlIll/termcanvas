# 检视问题修复结果

原检视的 **92 项结论**均已有修复记录：90 项有本地运行或工具验证，2 项保留专项验证限制。原始 100 条候选均可沿统一编号追溯。

最终完整 release gate **PASS**：7 个包共 **672** 个不同测试，10 个真实示例包共 **20** 个测试，17 个示例构建。压力阶段重复执行的 core 测试不重复计数。

另外，72 个独立诊断场景均正常完成；这表示诊断执行完成，行为结论以日志观察和正式回归断言为准。真实 FFmpeg 双帧公开 API 对照通过，两帧像素不同且逐字节匹配独立提帧结果。

## 修复范围

- PTY 启动、完整写入、信号与退出回收；异步任务终态、FD 复用、定时器、ESC 和会话恢复。
- 输入解析、Unicode、TextArea 选区和历史、缓存失效、补全坐标、裁剪及关联文本消费。
- 控件区域约束、确认对话框、文件路径、日期、虚拟列表和文档布局。
- Markdown、Diff、终端流、游戏状态和媒体解码；真实示例的输入与状态处理。
- SDK/CI 工具约定、文件恢复、API 提取、benchmark 来源记录、文档及必需 manifest。

交叉复核发现的 4 个输入边界、2 个运行时边界，以及实际 FFmpeg 参数差异均已补修，保留初次反例及修后证据。

## 证据

- [逐项修复表](fixes.md)与[机器可读状态](status.json)。
- [最终验证记录](validation.json)、[完整 gate 日志](evidence/logs/release-gate.log)、[输入文件哈希](evidence/gate-inputs.json)。
- [独立诊断运行](evidence/diagnostics/run-results.json)、[真实媒体验证](evidence/media-real-frame.json)。
- [输入交叉复核](evidence/cross-input.json)、[运行时交叉复核原记录](evidence/cross-runtime.json)与[运行时修后观察](evidence/cross-runtime-order-run-after.log)。
- [源码声明差异](evidence/api-declaration-diff.json)与[默认参数兼容性说明](evidence/compatibility-defaults.json)。
- [候选文件导出验证](evidence/candidate-export.json)：两份 manifest 已纳入未忽略文件集合，临时导出的候选源码架构检查通过。这不是新提交或远端 CI 结果。

## 兼容性与保留范围

公开声明仍为 2449 个。两处命令处理函数的默认 AsyncRuntime 表达式有意改变：临时实例随调用结束关闭；跨次异步处理应显式传入同一实例并管理其生命周期。外部省参调用已编译、运行通过；未执行旧二进制兼容矩阵。

PTY 待写队列限制为 4 MiB，关闭有 100 ms 宽限；媒体解码限制为 10 秒、16 MiB、256 帧，并要求 FFmpeg 支持 `-fps_mode passthrough`。超限明确失败。详情见 [limitations](../../limitations.md)。

macOS 分支仅有静态修正证据；采样并发问题已有结构修复和普通流程验证，未做长期并发测量。Windows/macOS 工具使用临时模拟环境验证；未执行原生平台、远端 CI 或长期性能矩阵。

原检视报告保持冻结。各 Agent 的原始记录可能仍写“等待统一 gate”或“等待其他组”，那是局部验证时的状态；本页及 status.json 是最终集成结论。原日志中的 /tmp 绝对路径保留来源信息，随附证据按相同相对路径收录，构建目标和二进制未打包。

首轮完整 gate 在交叉补修期间主动中止，退出 -15，未计为通过；其日志保留。最终 gate 运行期间，记录的输入文件没有变化。所有修改尚未提交或推送。
