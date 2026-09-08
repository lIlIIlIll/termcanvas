# termcanvas 全仓检视结果

本轮完成源码检视、候选问题交叉复核及本地验证，未修改产品源码。

从 100 条原始候选整理出 **92 项**：P0 0 项、P1 8 项、P2 60 项、P3 24 项。

证据分类：已复现 75 项、静态确认 12 项、改进建议 5 项。合并项的“已复现”表示核心行为已有运行证据，不能推定所有子路径、所有平台都运行过；逐项限制和原始复核记录一并保留。

当前工作目录的完整 release gate **PASS**；干净 tracked archive 的架构检查 **FAIL**，因为两个必需 manifest 未被跟踪。仅向该临时副本补入两个 manifest 后，架构检查 **PASS**。这次对照没有运行整个干净副本的 release gate。

## 优先处理

| 编号 | 等级 | 结论 | 证据 |
| --- | --- | --- | --- |
| [TERMCANVAS-001](findings.md#termcanvas-001) | P1 | PTY 未建立子进程组，启动失败与信号转发会命中错误目标 | 已复现 |
| [TERMCANVAS-009](findings.md#termcanvas-009) | P1 | FD 数值复用后 epoll 注册缓存把新 source 当作旧注册 | 已复现 |
| [TERMCANVAS-013](findings.md#termcanvas-013) | P1 | macOS 分支复用 Linux 非阻塞与窗口 ioctl 常量 | 静态确认 |
| [TERMCANVAS-034](findings.md#termcanvas-034) | P1 | ConfirmDialog 显示默认 No，Enter 却返回 true | 已复现 |
| [TERMCANVAS-049](findings.md#termcanvas-049) | P1 | ANSI 解析遇到裸 ESC 或非 CSI 序列时循环不前进 | 已复现 |
| [TERMCANVAS-054](findings.md#termcanvas-054) | P1 | Markdown 任务标记解析对空项和紧邻多字节文本越界 | 已复现 |
| [TERMCANVAS-072](findings.md#termcanvas-072) | P1 | 两个 benchmark manifest 未被跟踪，干净 checkout 的正式 gate 必然失败 | 静态确认 |
| [TERMCANVAS-073](findings.md#termcanvas-073) | P1 | Windows smoke 前置检查失败会删除已有共享 runner 和 staging | 已复现 |

## 交付文件

- [完整问题清单](findings.md)：原因、位置、实测结果、影响、建议和兼容性。
- [验证记录](validation.md)：完整 gate、复现场景、干净副本对照和未执行范围。
- [文件覆盖表](coverage.csv)及[覆盖说明](evidence/coverage/coverage_summary.md)。
- [统一 JSON](evidence/synthesis/unified_findings.json)及[100 条候选去向](evidence/synthesis/rejected_or_merged.json)。
- [源文件基线](evidence/baseline.json)、[编译记录](evidence/compile-results.json)、[运行记录](evidence/run-results.json)。
- [复现说明](reproduction.md)与[复现脚本](reproduce.py)。
- [产物校验清单](artifact-manifest.sha256)与[完整性检查脚本](verify_report.py)。

## 覆盖和边界

基线提交 `ab76bc1b39ed3a9261487beb71b4d1967accc2a2`，tree `169d78a775b7f2035c345625ca543aa214fed19f`，共 443 个跟踪文件。

覆盖账本：`full` 179、`excluded` 254、`generated_verified` 10。`excluded` 是明确排除逐行语义审读的历史结果、profiling 数据和 lock 文件；不等于这些文件都经过全文检查。生成项以一致性检查为证据。历史结果另有结构及来源核对记录。

P1 表示优先处理的核心功能或验证链路问题；P2 是明确的行为、状态或工具契约缺陷；P3 是局部示例问题、边缘行为或尚需明确契约的建议。分级不代表每种影响都已在本机发生。

本轮实际执行限于 Linux 本地；macOS、Windows 使用源码或临时模拟环境核对，未执行对应原生平台、远端 CI、真实终端外观验收及长期性能采样。没有宣称已经找出全部问题。

本目录 evidence 下的分组 review.md/findings.json 是阶段记录，可能仍写 probe_pending 或旧分级；最终以统一清单、各组 runtime_verification.json 和 validation.md 为准。原始 JSON 中的绝对路径记录当时运行位置；对应文件均按原相对结构收录，构建目标和二进制未打包。
