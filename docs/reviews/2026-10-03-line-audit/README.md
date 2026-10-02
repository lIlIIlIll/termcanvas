# 2026-10-03 termcanvas 逐行代码检视

审计基线：`main@e30b1c570b7252aa63b8a7844253583725cf22e4`。修复分支：`fix/line-audit-20261003`。

本轮独立检视当前代码，确认并修复 **49 项缺陷**，按模块创建 7 个 issue。没有直接修改 main、合并 PR 或关闭 issue。

| 模块 | 确认项数 | Issue | 详细证据 |
| --- | ---: | --- | --- |
| 运行时与输入 | 5 | [#6](https://github.com/lIlIIlIll/termcanvas/issues/6) | [runtime.md](runtime.md) |
| 文本与编辑器 | 6 | [#7](https://github.com/lIlIIlIll/termcanvas/issues/7) | [text.md](text.md) |
| 渲染与布局 | 6 | [#8](https://github.com/lIlIIlIll/termcanvas/issues/8) | [render.md](render.md) |
| 组件 | 12 | [#9](https://github.com/lIlIIlIll/termcanvas/issues/9) | [widgets.md](widgets.md) |
| 扩展包 | 10 | [#10](https://github.com/lIlIIlIll/termcanvas/issues/10) | [extensions.md](extensions.md) |
| 示例与长运行证明 | 6 | [#11](https://github.com/lIlIIlIll/termcanvas/issues/11) | [examples.md](examples.md) |
| SDK 与验证脚本 | 4 | [#12](https://github.com/lIlIIlIll/termcanvas/issues/12) | [tooling.md](tooling.md) |

优先风险包括覆盖率输出目录误删、SDK tar 解包越界、未知版本存档覆盖、PTY 分块 UTF-8 崩溃及 BTM Unicode 截断异常。其余涉及全量重绘丢失、缓存异常后的旧结果、CatchUp 无界追赶、补全误提交/复活、数值溢出和区域外绘制。每项的实际触发条件、基线位置及对应回归均在模块报告中。

## 范围和方法

- [coverage.csv](coverage.csv) 列出 130 个基线源文件/脚本/测试，共 56,192 行；其中 91 个生产源码和运行脚本共 36,659 行逐行静态检查。
- Unicode 17 生成表另以生成器与既有字素夹具校验。测试源码做相关契约复核，所有当前测试进入完整闸门；不把“执行测试”冒充“每行测试代码均人工证明”。
- 历史审计档案、第三方 Markdown 依赖源码、二进制媒体、外部消费者仓库不属于本轮逐行范围。固定 Markdown v0.9.0 作为集成依赖参与测试。
- 新增 55 个 Cangjie 回归和 14 个 Python 测试。缺陷回归先在对应旧实现运行失败，再修复；部分新增用例为正向安全对照，并非声称全部新增测试都在基线失败。
- [evidence/](evidence/) 保存失败输出摘录；移除了编译警告前导、ANSI 控制符和行尾空白。manifest 保留原始日志 SHA256。源码和测试是复现依据，日志摘录辅助核对实际观测。
- 对核心渲染、扩展终端字素、组件缩放和脚本安全修复做独立交叉复核。一个覆盖率输出目录与构建目录重叠的新增边界回归在交叉复核时发现并修正。
- 无公开类型/签名/默认值变更，稳定及实验 API 契约文本完全不变。API index/inventory 仅重新生成源码位置和排除测试计数。

## 验证

工具链与 CI 完全一致：Cangjie/cjpm **1.1.3**，Linux x86_64；SDK 归档 SHA256 见 tooling.md。

| 检查 | 结果 |
| --- | --- |
| core 全量 | 700/700 PASS |
| 五个扩展包 | 100/100 PASS |
| 十个有测试的示例包 | 55/55 PASS |
| Python 脚本测试 | 44/44 PASS |
| API 生成与分类 | 2379 个公开声明，0 未分类；stable/experimental 契约不变 |
| Unicode 17 数据 | 生成比较与现有字素测试 PASS |
| 全部 17 示例构建、smoke、脚本化工作流与 pressure | PASS；`release gate ok`，退出 0 |
| 覆盖率 | PASS，退出 0；44 个生产包文件：行 11730/12750（92.00%）、分支 16377/20324（80.58%）；门槛 90%/80% |

完整闸门输出摘要见 [validation-release.txt](validation-release.txt)，覆盖率输出摘要及原始日志 SHA256 见 [validation-coverage.txt](validation-coverage.txt)。

实际命令：

```sh
export CANGJIE_SDK_ROOT=/path/to/cangjie-1.1.3
export CJ_TUI_CANONICAL_TARGET_ROOT=/tmp/termcanvas-validation-target
scripts/cangjie_cmd.sh . scripts/ci_gate.sh
scripts/coverage.sh /tmp/termcanvas-coverage-output
python3 -m unittest discover -s scripts -p 'test_*.py'
scripts/generate_api_contract.sh --check
git diff --check
```

未降低覆盖率门槛、修改性能基线或禁用测试。既有断言只在明确修复的行为上同步：示例快捷键路由，以及 CatchUp 的精确到期时刻。

## 未验收边界和排除项

- macOS/Windows 原生终端执行没有环境，本轮仅静态检查；Linux 结果不能代替两平台实测。macOS raw-mode 阻塞读取候选记录在 runtime.md，未将其计入 49 个已修复问题。
- 外部 omp-cj 长运行/PTY harness 不在本仓库。本轮验证证明脚本对缺失/失败证据返回失败，不宣称完成外部消费者性能或真实显示延迟验收。
- Flex shrink 仅保留参数、Input 光标可返回右边缘均有当前文档/测试反证，未按缺陷修改。其他未晋升观察见模块报告。
- 逐行检视和回归能够提供明确覆盖与反例，不是“仓库不存在其他缺陷”的证明。
