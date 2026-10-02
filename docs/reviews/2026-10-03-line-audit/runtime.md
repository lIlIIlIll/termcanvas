# Runtime、输入与终端检视

基线：`e30b1c5`。以下结论来自本轮逐行读取、现行契约与新增失败回归；没有沿用旧审计报告的缺陷判定。

## 覆盖

| 文件 | 基线行数 | 检视范围 |
| --- | ---: | --- |
| `packages/core/src/app.cj` | 3019 | 全文件：命令队列、更新顺序、帧合并、timer/tick、async、headless、waiter、FocusManager |
| `packages/core/src/runtime_foundation.cj` | 806 | 全文件：owner/operation、runtime queue、frame scheduler、ExternalPort 与平台 wake source |
| `packages/core/src/pty.cj` | 943 | 全文件：fork/exec、fd 所有权、startup error、读写队列、signal、close/reap、fake runtime |
| `packages/core/src/terminal.cj` | 2114 | 全文件：front/back 与局部帧、session/probe、ANSI backend、终端恢复、三平台驱动 |
| `packages/core/src/event.cj` | 994 | 全文件：输入状态、增量 UTF-8、CSI/SS3、Kitty、paste、mouse |
| `packages/core/src/keymap.cj` | 138 | 全文件：binding 匹配和帮助标签 |
| **合计** | **8014** | Linux 执行验证；macOS/Windows 仅静态阅读 |

同时核对 `docs/events.md`、`docs/app-runtime.md`、`docs/limitations.md`、ADR-005，以及 `runtime_foundation_test.cj`、`audit_runtime_test.cj`、`audit_input_test.cj` 中对应的 ownership、timer、async、PTY、键盘协议测试。`pty.cj` 和 `keymap.cj` 未产生本轮已复现的新增缺陷；这不是无缺陷保证。

## 已复现并修复的问题

### RUNTIME-01 · P2 · 合并帧丢失全量失效请求

- 基线位置：`app.cj:1848-1856`、`2256-2260`、`2398-2401`。
- 触发：同一次绘制前，一个更新返回 `UpdateResult.dirty(left)`，另一个修改区域外状态并返回默认 `UpdateResult.next()`；两种顺序都出错。
- 影响：`pendingDirty` 非空使整帧被限制为局部刷新，全量更新区域仍显示旧状态；按键批处理和后台帧合并都能触发。
- 失败证据：`fullInvalidationSurvivesPartialUpdatesInEitherOrder` 中左侧成功变为 `A`，右侧第 7 列仍为 `b`，应为 `B`。
- 修复：内部 lifecycle 保存持续到 present 的全量失效标记。全量请求优先于后续局部请求；绘制后清除；reset、suspend 和 resize 重新请求全量。稳定 API 不变。

### RUNTIME-02 · P2 · 错误 owner 的 completion 提前结算其他 owner 的 operation

- 基线位置：`runtime_foundation.cj:176-185`。
- 触发：owner A 启动 operation；先到达携带 owner B 和该 operation ID 的 completion，再到达 A 的合法 completion。
- 影响：第一个 completion 虽被标为 Orphan，却执行 `record.settle()`；合法结果随后被误判 Duplicate，无法应用。
- 失败证据：`unrelatedOwnerCannotConsumeAnotherOperationsCompletion` 的合法 completion 断言失败。
- 修复：owner 不匹配时只拒绝和计数；只有匹配的 owner 已过期才按孤儿 operation 结算。合法 completion 仍只允许一次 Applied。

### RUNTIME-03 · P2 · 应用光标模式的 SS3 方向键变成 Escape 和文字

- 基线位置：`event.cj:572-578`。
- 触发：输入 `ESC O A/B/C/D/H/F`，分别表示 Up/Down/Right/Left/Home/End。
- 影响：只识别 SS3 F1–F4；方向和 Home/End 被拆成 Esc、`O`、字母，可能关闭弹层或插入垃圾字符。
- 失败证据：输入 `ESC O A x` 应为两个事件，实际得到四个。
- 修复：添加六个标准 SS3 光标键映射。回归遍历每个字节切分位置，并校验后续 `x` 不丢失。
- 协议依据：[XTerm Control Sequences，Cursor keys](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) 中 DECCKM normal/application 表。

### RUNTIME-04 · P2 · Kitty Shift+Tab 向前移动焦点

- 基线位置：`app.cj:2979-2988`。
- 触发：`EventParser` 解析 `CSI 9;2u` 得到 `KeyCode.Tab` 和 Shift modifier；FocusManager 只把 BackTab 视为向后。
- 影响：中间项按 Shift+Tab 跳到下一项；与 Basic 协议方向相反。
- 失败证据：焦点 `two` 应变为 `one`，实际变为 `three`。
- 修复：Tab 分支检查 Shift；回归同时验证普通 Tab 与传统 BackTab 未回退。

### RUNTIME-05 · P2 · CatchUp 预算不限制追赶，丢帧计数也不正确

- 基线位置：`app.cj:505-539`。
- 现行契约：`docs/app-runtime.md` 要求 bounded catch-up count。
- 触发：5 ms 重复定时器停顿到 103 ms；固定时钟继续 drain。`CatchUp(0/1/2)` 都连续发出 20 次，而应分别最多发出当前一次加 0/1/2 次追赶。
- 影响：延迟越大，立即处理的积压事件越多，预算形同虚设；`droppedFrames` 把追赶数量重复累计为丢弃数量。
- 失败证据：预算 0/1/2 时实际次数均 20；累计 dropped 为 0/19/37，应为 19/18/17；预算 100 可完成全部 20 次却累计报告 190 个 dropped，应为 0。
- 修复：先计算真正跳过的旧时槽 `max(0, missed - max(0, n))`，推进下一个 deadline 时跳过它们，保留原定时相位。tick 与 timer 使用同一语义；tick 按纳秒计算，支持显式的亚毫秒周期。
- 回归：覆盖预算 0/1/2/100、下一 deadline 仍为 105 ms、真实 dropped 总数、亚毫秒 tick；现有测试将宽松的 `< now` 改为精确的预期 deadline，没有放宽断言。

## 验证

- SDK：仓库固定的 Cangjie STS 1.1.3，Linux x86_64。
- 新增测试类：`Audit20261003RuntimeTest`，文件 `packages/core/src/audit_20261003_runtime_test.cj`，共 5 个 TestCase。
- 首次红灯：`core-before.log` 中前四项全部失败；增量红灯：`core-added-before.log` 中 CatchUp 回归失败，前四项仍失败。
- 修复后全量 core：`core-after.log` 记录 **698/698 PASS**，包括本轮全部 5 个 runtime 回归；无失败、错误或跳过。其余仓库 gate 见本轮统一验收记录。

## 未完成的平台验证

macOS `MacOSTerminalMode.enterRawMode()` 在 `cfmakeraw()` 后没有像 Linux 分支一样设置非阻塞式 `VMIN=0/VTIME=0`。若 Darwin 默认 raw 参数保留阻塞读取，`EventParser.readEvents()` 的多次 drain 或 active probe 可能等待额外输入。当前没有 macOS 执行环境，因此仅记录为待验证边界，没有提交未经平台验收的修改。Windows 的控制台输入与信号恢复同样未在本轮运行验证。

集成说明：上述 698/698 是首轮集成快照；追加组件极端边界回归后，最终 release gate 的 core 为 700/700。详见总报告。
