# 渲染、布局和基础状态逐行检视

基线：`e30b1c5`。所有结论均来自当前源码及本次新增回归；未把旧检视报告当作问题依据。

## 覆盖范围

| 文件 | 基线行数 | 检视内容 | 结果 |
| --- | ---: | --- | --- |
| `packages/core/src/buffer.cj` | 591 | 宽字修复、物理/Canvas/dirty 裁剪、ASCII/Unicode 写入、复制/resize/blit、media 记录 | RENDER-004 |
| `packages/core/src/canvas.cj` | 256 | 平移、viewport、fill/text 裁剪、线/框、widget bridge、surface composition | 未新增确认问题 |
| `packages/core/src/geometry.cj` | 359 | Rect/Spacing、Layout 约束与舍入、Grid/FlexLayout、LayoutCache | RENDER-001、RENDER-002 |
| `packages/core/src/dirty_rects.cj` | 124 | add/union、覆盖/交集查询、复制、cellCount | RENDER-005 |
| `packages/core/src/style.cj` | 143 | Color/Modifier/Style patch、Theme 与辅助序列化 | 未新增确认问题 |
| `packages/core/src/media.cj` | 227 | 媒体值、差分、帧相等性、fallback、Base64 | 未新增确认问题 |
| `packages/core/src/virtual_transcript.cj` | 1331 | Fenwick 高度索引、缓存身份、append-only 尾部重排、anchor、局部脏区、卡片绘制 | RENDER-003 |
| `packages/core/src/widget_base.cj` | 110 | Widget 协议、主题选择、宽度/索引辅助函数 | 未新增确认问题 |
| `packages/core/src/widgets.cj` | 842 | Block/Panel/Paragraph/List/Table/Input/Scrollbar/FileDialog 与对应状态 | RENDER-006 |
| `packages/core/src/navigation.cj` | 175 | Tabs/StatusBar/Viewport、滚动和区域绘制 | RENDER-006 |
| `packages/core/src/state_models.cj` | 201 | Selection/Scroll/Sort/Filter 状态、状态变更及边界 | 未新增确认问题 |
| `packages/core/src/lib.cj` | 1 | package 声明 | 无运行逻辑 |

合计 4,360 行生产代码。另核对 `docs/api.md`、`docs/layout.md`、`docs/widgets.md` 和 Canvas、边界、输入、布局、virtual transcript 相关现有回归。表内“未新增确认问题”表示本轮未形成可证实缺陷，不代表形式化证明。

## 确认问题与修复

### RENDER-001：Min 的舍入余数会扩大固定/封顶区块（P2）

- 基线位置：`geometry.cj:173,215–229`。
- 触发：宽度 5，约束 `[Min(0), Min(0), Length(2)]`，实际分配 `[1,1,3]`。高度 3，约束 `[Min(0), Min(0), Max(0)]`，实际最后一块高度为 1。
- 影响：固定尺寸或最大值被违反；边栏、状态区和隐藏区域的布局错误。
- 原因：`normalizeSizes` 把余数追加到数组末项，而不是接收剩余空间的 Min 项。
- 修复：记录最后一个 Min 的索引，仅向该项分配余数。
- 回归：`minRoundingRemainderDoesNotEnlargeFixedOrMaximumChunks`，同时覆盖横向 Length 和纵向 Max。

### RENDER-002：LayoutCache 的异常路径污染缓存键（P2）

- 基线位置：`geometry.cj:338–345`。
- 触发：先成功缓存区域 A；请求区域 B 时 `compute` 抛异常；再次请求 B。
- 实际：第二次 B 请求直接命中 A 的旧结果，计算函数不再调用。
- 原因：先写入新 `area`，后调用 `compute`，旧 `valid` 仍然为 true。
- 修复：先完成计算，再一起提交缓存键和值；失败保留原来的有效缓存。
- 回归：`layoutCacheRetriesAfterComputeFailure`。

### RENDER-003：Transcript 新版本构建失败后永久复用旧行（P2）

- 基线位置：`virtual_transcript.cj:1054–1079,1157–1178`。
- 触发：revision 0 渲染 `old`，升至 revision 1，`source.document` 暂时抛异常；下一次渲染重试。
- 实际：仍显示 `old`，provider 调用数停在 2；期望调用第 3 次并显示 `new`。
- 原因：在 provider 调用前改写 revision/id 等缓存身份，却保留旧 `measured=true`。
- 修复：在更新身份和调用 provider 前将条目标记为未测量，成功完成后恢复为有效条目。失败后的重试进行完整布局。
- 回归：`transcriptRetriesFailedRevisionMaterialization`。

### RENDER-004：源区域裁剪会改变 blit 的坐标映射（P2）

- 基线位置：`buffer.cj:440–456`。
- 触发：源 Buffer 位于 `(2,2)`，请求源矩形 `(1,1,3,3)`，目标原点 `(0,0)`。
- 实际：源 `(2,2)` 被放到目标 `(0,0)`，而不是保留源/目标平移关系的 `(1,1)`；顶部/左侧未覆盖位置被错误覆盖。
- 原因：循环以裁剪后的源矩形开始，却仍从未经裁剪补偿的目标原点开始。
- 修复：根据源左/上裁剪量补偿目标起点；保留重叠复制快照、宽字归一化和两种 clip 策略。
- 回归：`blitPreservesRequestedSourceToDestinationTranslation`，覆盖 `blitFrom` 和 `blitFromUnchecked`，同时验证两个坐标轴和未覆盖单元格。

### RENDER-005：DirtyRects 合并后遗留重叠区域（P2）

- 基线位置：`dirty_rects.cj:20–33`。
- 触发：依次加入 `(0,0,1,1)`、`(0,1,2,1)`、`(1,0,1,2)`。
- 实际：返回两个相互包含的矩形，`cellCount()` 为 5；合并区域实际为 2×2、4 格。
- 原因：新增项与后面的矩形合并扩大后，不重新检查前面已经跳过的矩形。
- 修复：每次合并后从列表起点继续检查，直到没有可合并的矩形。
- 回归：`dirtyRectUnionRevisitsEarlierRectangles`，同时验证矩形数量、面积和坐标。

### RENDER-006：基础文字控件会改写自身区域外的宽字单元格（P2）

- 基线位置：`widgets.cj:281–298,739–756`；`navigation.cj:34–46,100–131,163–174`。
- 涉及：Paragraph、Input、Tabs、StatusBar、Viewport。
- 触发：旧宽字符跨越控件左右边界，再将单宽字符/空格写到界内的半个宽字符上。
- 实际：Buffer 为修复旧宽字会同时改写区域外的另一格，破坏邻接控件。List/Table 及 Canvas 已通过物理 clip 避免这类问题。
- 修复：五种控件的绘制都在 `withCanvasClip(area)` 作用域执行；跨边界且不能完整修复的宽字保持原样。
- 回归：`textWidgetsDoNotRepairWideCellsOutsideTheirArea`，逐一覆盖五种控件及左右边界。

## 红绿验证

新增文件：`packages/core/src/audit_20261003_render_test.cj`，类 `Audit20261003RenderTest`，共 6 项测试。

SDK 为项目 CI 指定的 Cangjie 1.1.3。运行命令：

```sh
CANGJIE_SDK_ROOT=/tmp/termcanvas-sdk/cangjie \
CJ_TUI_CANONICAL_TARGET_ROOT=/tmp/termcanvas-core-target \
scripts/cangjie_cmd.sh packages/core cjpm test --no-color --filter 'Audit20261003*'
```

- 修复前：`core-before.log` 中先加入的 5 项全部失败。
- 补充基线：`core-added-before.log` 中本类 6 项全部失败；新增布局案例观测到 `Length(2) → 3`、`Max(0) → 1`。
- 修复后：统一完整 core 测试 **698/698 通过**，包含本类全部 6 项；无跳过或失败。现有 Canvas、宽字覆盖、重叠 blit、布局和 transcript 测试同时通过。

日志由本次检视主报告集中保存。

## 排除项和反证

- **FlexItem.shrink 未参与计算不是本轮确认缺陷**：`docs/layout.md:63–68` 明确规定目前 FlexLayout 仅采用 basis/grow，shrink 保留在公开值结构中。撤销最初针对 shrink 的候选回归，未擅自引入新布局语义。
- **Input 返回内容右边缘的光标位置不是本轮新问题**：现有 `lib_test.cj` 中 `inputKeepsCursorVisibleAndSupportsValueHelpers` 明确要求 3 格输入区域返回 `x=3`，本轮未以未经确认的新契约改写此行为。

集成说明：上述 698/698 是首轮集成快照；追加组件极端边界回归后，最终 release gate 的 core 为 700/700。详见总报告。
