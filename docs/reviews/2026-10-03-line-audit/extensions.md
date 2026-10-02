# 扩展包逐行复核（2026-10-03）

审计基线：`e30b1c5`。下列定位均为该基线行号；结论依据本次阅读与新增失败回归，不采用旧审计报告。共确认并修复 10 个独立问题，新增 12 个回归用例。

## 覆盖范围

| 完整阅读的生产文件 | 基线行数 | 检视重点 |
| --- | ---: | --- |
| `packages/terminal/src/terminal.cj` | 417 | ANSI增量状态、SGR、光标与擦除、宽字、滚动、搜索、转录裁剪 |
| `packages/diff/src/diff.cj` | 363 | 文件与hunk状态、行号、路径、双栏/窄区绘制 |
| `packages/media/src/media.cj` | 738 | 外部工具参数/退出/限额、RGBA转换、取帧、各字符模式与绘制 |
| `packages/game/src/game.cj` | 870 | 实体/组件、输入、物理积分/碰撞、动画、地图与精灵 |
| `packages/markdown_adapter/src/markdown.cj` | 437 | AST转换、嵌套样式、列表、表格、提纲、源位置 |
| `packages/markdown_adapter/src/code_highlight.cj` | 780 | 各语言词法状态、UTF-8推进、配置覆盖、源码映射与装饰 |
| `packages/markdown_adapter/src/syntax_config.cj` | 328 | 配置语法、参数/资源边界、别名、颜色、分隔符 |
| `packages/example_smoke/src/main.cj` | 185 | 四组无头工作流、失败汇总与退出码 |

生产代码覆盖共 4,118 行。并阅读各扩展的既有 `*_test.cj`、包声明、`docs/extensions.md`、`docs/limitations.md`，针对绘制问题交叉检查 core 的 Buffer/Canvas/字素接口。`code_highlight.cj`、`syntax_config.cj`、`example_smoke/src/main.cj` 未确认需要修改的问题。

## 确认问题与修复

### EXT-001 · P2 · ED/EL忽略模式，ED错误移动光标

- 位置：`packages/terminal/src/terminal.cj:249–263`。
- 触发：`CSI 1 K`、`CSI 2 K`、`CSI 0 J`、`CSI 1 J` 或任意 ED 后继续输出。
- 原因/风险：EL一律从光标擦到行尾，ED一律清空屏幕并回到(0,0)，破坏常见增量刷新输出。
- 修复：实现0/1/2模式对应范围，保留光标，擦除使用当前样式，并清除待换行状态。
- 回归：`eraseLineHonorsAllModesAndKeepsCursor`、`eraseDisplayHonorsModesWithoutHomingCursor`；基线失败，修复通过。

### EXT-002 · P2 · CUP单参数被错误当作回到左上角

- 位置：`packages/terminal/src/terminal.cj:266–275`。
- 触发：`CSI 3 H`、`CSI 4 ; H`。
- 原因/风险：参数少于2个时丢弃已提供的行号，后续文本写错行。
- 修复：行、列独立应用默认值1，零值也取1。
- 回归：`cursorPositionDefaultsEachMissingParameterIndependently`；基线失败，修复通过。

### EXT-003 · P2 · 终端逐标量绘制丢组合符并拆开ZWJ表情

- 位置：`packages/terminal/src/terminal.cj:163–172`。
- 触发：完整或分片feed `e\u{301}👩‍💻x`，或满行后补组合符。
- 原因/风险：每个标量独立传入Buffer，零宽标量被丢弃，ZWJ表情中每个图形分别推进，后续位置错误；仅替换为单次feed内分词仍无法修复分片情况。
- 修复：跟踪最后绘制字素位置，使用core字素边界判断合并后续标量；只有新字素触发延迟换行。光标操作、换行和擦除作废续接位置；字素增长超出右边界时整体移到下一行。
- 回归：`graphemeClustersSurviveBothWholeAndFragmentedFeeds`；新增时13/14通过、该用例失败；修复后14/14通过。独立复核后补充RI旗帜从1格增长到2格时整体换行、CR后组合符不续接旧位置两条断言。

### EXT-004 · P2 · 媒体视图写入会修改区域外宽字

- 位置：`packages/media/src/media.cj:327–331,679`。
- 触发：`中`横跨视图左边界，在区域内的续格上绘制ASCII帧。
- 原因/风险：直接调用Buffer会触发宽字修复，把区域外前导格清空；彩色与单色路径都受影响。
- 修复：通过绑定目标区域的Canvas绘制。
- 回归：`animationPreservesWideGlyphsAcrossRenderBoundary`；基线两个路径均失败，修复通过。

### EXT-005 · P2 · 媒体缩放将Rune数量当显示宽度

- 位置：`packages/media/src/media.cj:656–683,705–716`。
- 触发：`AsciiFrame(["中x"])`在3格区域内放大2倍；或放大组合字`e\u{301}`。
- 原因/风险：单色路径越过目标右边界；彩色路径每次只推进1格，覆盖刚写入的宽字；组合符与基字分别放大。
- 修复：按完整字素缩放和计宽，裁剪使用`graphemePrefix`，彩色推进使用字素宽度。
- 回归：`animationClipsAndZoomsWholeGraphemesByDisplayWidth`；基线失败，修复通过。

### EXT-006 · P2 · RGBA公开入口先乘后校验导致溢出异常

- 位置：`packages/media/src/media.cj:339–344`。
- 触发：`rgbaToAsciiFrame([], Int64.Max, 2, options)`。
- 原因/风险：无效尺寸本应走空帧返回，乘法却先抛`OverflowException: mul`。
- 修复：用`bytes.size / 4 / width`校验height，避免尺寸乘法溢出。
- 回归：`rgbaDimensionsRejectUnrepresentableFrameSizes`；基线ERROR，修复通过；既有有效帧转换仍通过。

### EXT-007 · P2 · 缺省速度组件没有持久化，重力无法累计

- 位置：`packages/game/src/game.cj:428–446`。
- 触发：实体有Transform与Dynamic RigidBody，无Velocity组件，连续执行两个100ms物理步。
- 原因/风险：第一步默认零速度，但`velocities.set`对不存在的项返回false；每步重置速度，位置约0.2而非0.3。
- 修复：使用ComponentStore.insert保存已有或缺省速度。
- 回归：`physicsPersistsImplicitZeroVelocityBeforeTheNextStep`；基线失败，修复后速度2.0并保留组件。

### EXT-008 · P2 · 地图/精灵按Rune寻址，与字素显示宽度不一致

- 位置：`packages/game/src/game.cj:604–612,852–858`。
- 触发：`TileMap(["e\u{301}#"])` 或精灵`👩‍💻x`。
- 原因/风险：TileMap.width为2而symbolAt把组合符另占1格，`#`查找不到且碰撞体会遗漏；精灵把ZWJ表情拆开，后续坐标偏移。
- 修复：查找、透明判定、绘制和坐标推进统一使用core字素。
- 回归：`tileMapUsesTheSameGraphemeColumnsForWidthLookupAndRender`、`spriteRendererKeepsJoinedEmojiAndFollowingColumnsIntact`；基线失败，修复通过。

### EXT-009 · P2 · 统一diff路径包含时间戳元数据

- 位置：`packages/diff/src/diff.cj:293–295`。
- 触发：传统统一diff头`--- a/old name.txt\t2026-10-01 ...`。
- 原因/风险：只去掉a/b前缀，时间戳被误存为oldPath/newPath，展示与文件识别错误。
- 修复：先按Tab分隔路径与元数据，保留路径中的空格，再去前缀。
- 回归：`filePathsExcludeUnifiedDiffTimestampMetadata`；基线失败，修复通过。

### EXT-010 · P2 · Markdown链接覆盖外层强调样式

- 位置：`packages/markdown_adapter/src/markdown.cj:309–313`。
- 触发：`***[link](https://example.com)***`。
- 原因/风险：Link分支直接用theme.link覆盖嵌套Style，丢粗体与斜体。
- 修复：使用现有mergeInlineStyles合并链接颜色与外层modifier。
- 回归：`linksPreserveEnclosingStrongAndEmphasisModifiers`；基线两种modifier均失败，修复通过，URL/链接色仍正确。

## 验证记录

环境：Linux x86_64，仓颉STS 1.1.3，使用仓库的`cangjie_cmd.sh`与SDK检查入口。新增回归均先在对应未修改实现上运行，记录实际失败后再修复；未禁用或放宽任何既有测试。

| 包 | 新增用例 | 修复前结果 | 修复后结果 |
| --- | ---: | --- | --- |
| terminal | 4 | 首批10通过/3失败；字素用例另一次13通过/1失败 | 14通过，0失败/错误/跳过 |
| media | 3 | 13通过/2失败/1 ERROR（OverflowException） | 16通过，0失败/错误/跳过 |
| game | 3 | 12通过/3失败 | 15通过，0失败/错误/跳过 |
| diff | 1 | 10通过/1失败 | 11通过，0失败/错误/跳过 |
| markdown_adapter | 1 | 43通过/1失败 | 44通过，0失败/错误/跳过 |
| example_smoke | 无代码变更 | 阅读现有四组场景 | `component composition smoke scenarios ok: 4`，退出0 |

扩展单测合计100/100通过。原始红/绿运行日志分别保留于本轮执行环境的`/tmp/termcanvas-<package>-audit-{red,green}.log`；终端字素红灯另为`/tmp/termcanvas-terminal-grapheme-audit-red.log`。本文件保留可独立阅读的失败摘要，持久复现入口为提交的五个`audit_20261003_*_test.cj`文件。

```bash
export CANGJIE_SDK_ROOT=/path/to/cangjie-1.1.3
for package in terminal media game diff markdown_adapter; do
  scripts/cangjie_cmd.sh "packages/$package" cjpm test
done
scripts/cangjie_cmd.sh packages/example_smoke cjpm run
```

## API与验证边界

- 无公共类型、函数签名、默认参数、包依赖或导出变更。新增terminal状态及写入函数均为private；media绘制helper仅在包内使用。变化是修正现有接口的输出、边界处理与速度持久化。
- TerminalScreen仍接收有效UTF-8 String；PTY把任意分片字节转换为String的责任在上游。这些用例覆盖跨String调用的字素，不能证明非法UTF-8字节输入安全。
- 媒体既有工具夹具、输出限额与帧验证用例已运行；没有宣称实测本机ImageMagick、真实ffmpeg视频或真实Kitty/Sixel终端展示。
- 物理测试覆盖报告中的离散状态问题；未声称验证任意NaN/Infinity输入、完整物理引擎语义或大规模性能。
- 没有对diff或词法器进行无界随机fuzz；未宣称上述覆盖意味着所有输入均无缺陷。Markdown上游解析器独立于本仓库审计范围。
