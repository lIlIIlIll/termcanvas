# 第二轮修复与独立复核

二次检视的 **21 项均已处理并完成主 Agent 复核**。状态按公共行为测试、本地工具 fixture、文档核对区分，不把它们统一称为原生平台实测。

最终完整流程 **PASS**：7 个包共 **715** 个不同测试，10 个真实示例包共 **23** 个测试，17 个示例构建；Python fixture 共 **25** 个。压力阶段重复执行的 core 测试不重复计数。运行期间及交付核验时，记录的输入文件未发生变化。

主 Agent 逐文件审读修复差异，并将原反例重新链接到最终完整流程的库运行。另以相同独立程序进行修前、修后对照：882 组多选区编辑、撤销和再次输入，2520 组宽字符覆盖，1575 组直接控件区域及裁剪恢复检查全部通过。这些是诊断组合，未混入 cjpm 测试数量。

再次复核发现 DiffView 的单列修复仍可能改动区域外旧宽字，已交回原组补修。最终覆盖左右边界、标题、hunk 与正文，保留反例和修后证据。没有将首版修复的局部通过直接当作完成。

公开声明仍为 2449 项，除行号外的声明及分类元数据无变化；未执行旧二进制矩阵。原有 macOS 专项与长期采样限制仍然保留。Windows 生成脚本已修正参数块位置，并通过本地生成与文件恢复 fixture；本机没有 PowerShell，也未启动 Windows VM。

## 证据

- [逐项复核](fixes.md)、[机器可读状态](status.json)和[完整验证记录](validation.json)。
- [完整流程日志](evidence/logs/release-gate.log)与[输入哈希](evidence/gate-inputs.json)。
- [主 Agent 源码复核](evidence/root/source-review.json)与[原反例断言回放](evidence/replay-findings.json)。
- [编辑与宽字组合](evidence/combinations-final.json)、[控件区域组合](evidence/widget-regions-final.json)。
- [DiffView 补修前](evidence/extension-followup-before.json)与[补修后](evidence/extension-followup-final.json)。
- [公共声明比较](evidence/api-comparison.json)与[采样说明更正](errata.md)。

各组早期记录中的等待集成或生成物陈旧描述保留为当时事实，最终状态以本页和完整流程为准。中途曾修正测试构造表达式、一个不符合 Rune 契约的预期及测试 fixture 的公开入口使用，相关日志保留；没有把这些编译或预期错误归因于产品。

原三份检视及修复报告保持冻结。本轮修改未提交或推送。随附文本、源码与脚本证据，省略构建目标和可执行文件；日志中的 `/tmp` 路径保留原始来源。
