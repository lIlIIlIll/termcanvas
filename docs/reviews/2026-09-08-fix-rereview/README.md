# 修复后二次检视

结论：**PARTIAL，当前修改尚不能整体判定为完整、正确。** 原报告的 92 项都有对应记录，100 个原始编号没有漏映射，但独立组合反例揭示了修复不完整与新增回归。原有测试通过仍然有效，其断言未覆盖这些组合。

本次检查当前 GitButler 差异、修复源码、新增测试和逐项证据。458 个完整流程输入文件的哈希与上次通过时完全一致；因此复用 672 个包测试、20 个真实示例测试、17 个示例构建的结果，没有无变化重跑整套流程。输入、控件、运行时反例额外使用同一最终 core 静态库重编译、执行。

整体方案中的采样器实例分离、输入事件解析与消费分层、真实示例测试纳入流程，以及媒体解码显式预算均有清楚目的。主要不足是边界条件没有统一处理：重叠编辑、宽字覆盖、字素高亮、关闭输出顺序，以及生成脚本与解析工具的输入组合。

## 阅读方式

逐项表区分本次引入、原修复不完整和相邻旧问题。不能将表内所有问题都称为本轮新引入，也不能用通过测试的数量推断未列出的输入均正确。每组原始复核记录保留检查范围和未验证部分。

本次仅新增检视报告与反例证据，没有修改产品源码、原始报告、提交或推送。原生 macOS、原生 Windows、旧二进制兼容矩阵及长期测量仍不在本次运行证据内。

## 汇总说明更正

CJTUI-047 的旧汇总与此前答复误写“完整事务锁”。实际代码在 `examples/btm_clone/src/main.cj:633` 分别创建前台和后台 `ProcFsSampler`，各自持有采样基线；`completionLock` 保护完成结果槽。原 Agent 的证据对此描述正确。需要修正文档表述，不能把这处汇总错误当作代码未分离采样状态。

## 结果与证据

本轮记录 21 项，分级为 P1 1 项、P2 12 项、P3 8 项；其中包含相邻旧问题和文档问题，不能将总数当作新增回归数量。来源分类：原修复不完整 6 项、相邻旧问题 9 项、本次引入 3 项、配套说明问题 2 项、新增限制的提示遗漏 1 项。详见 [逐项结论](findings.md) 和 [机器记录](findings.json)。

- [输入文件与映射核验](evidence/root/validation.json)。
- [最终 core 库独立回放](evidence/root/replay.json)。
- [runtime 完整复核范围与原编号映射](evidence/cjtui-rereview-runtime.json)。
- [input 完整复核范围与原编号映射](evidence/cjtui-rereview-input.json)。
- [widgets 完整复核范围与原编号映射](evidence/cjtui-rereview-widgets.json)。
- [tooling 完整复核范围与原编号映射](evidence/cjtui-rereview-tooling.json)。
- [extensions 完整复核范围与原编号映射](evidence/cjtui-rereview-extensions.json)。

Windows 脚本问题核对了实际生成文本及 [PowerShell 官方参数规则](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_scripts#parameters-in-scripts)，未声称本机运行过 PowerShell。原日志的 `/tmp` 路径保留来源；源码、脚本和文本证据随附，编译库与可执行文件不打包。
