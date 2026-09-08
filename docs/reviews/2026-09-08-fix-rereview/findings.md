# 逐项复核结论

本次不修改产品。以下同时保留新回归、修复遗漏及相邻旧问题；每项来源分类以描述为准。

## RR-TOOL-01 · P1 · 生成 Windows runner 时把赋值放在 param 前，使脚本参数块失效

来源：本次引入。

触发：任一次通过前置检查的 Windows smoke；包装器生成临时 run-tests.ps1 后交给真实 PowerShell 执行。

预期：生成脚本保留最前面的 param(Cases, Out, Cjc)，随后选择本次唯一 staging 目录。

实际：实际 shell 包装器生成的首行是 $env:CJ_TUI_STAGE_NAME = "cj_tui...."，第二行才是 param(。PowerShell 要求脚本 param 为首条非注释语句；该内容不能按预期绑定 Cases/Out/Cjc。

建议：保留模板 param 为首条语句，将 staging 常量放在 param 块之后，或通过显式参数/模板占位符传入；对最终生成文本补 PowerShell 参数解析或本地执行检查。

- [scripts/run_windows_smoke.sh:98](../../../scripts/run_windows_smoke.sh)
- [scripts/windows_repo_smoke.ps1:1](../../../scripts/windows_repo_smoke.ps1)

[原始复核记录](evidence/cjtui-rereview-tooling.json)

## EXT-RR-01 · P2 · TerminalScreen 窄区域复制可留下孤立 WideLead

来源：相邻旧问题。

触发：在 3 列屏幕写入 a中，再把它 render 到宽度 2 的区域；目标缓冲第 2 列之外仍是普通 Z。

预期：目标区域末列不应写入缺少 WideCont 的宽字符头；应跳过该字形或以完整宽字符组写入。

实际：render 逐 cell 复制 x=1 的 WideLead，但因区域结束不复制 x=2 的 WideCont；目标 x=2 保持 Z。

建议：TerminalScreen.render 按完整 cell group 复制；当 WideLead 的 continuation 不在区域内时不要写入该 lead，并加入宽度 1/2 的边界测试。

- [packages/terminal/src/terminal.cj:130](../../../packages/terminal/src/terminal.cj)
- [packages/terminal/src/terminal.cj:135](../../../packages/terminal/src/terminal.cj)
- [packages/core/src/buffer.cj:115](../../../packages/core/src/buffer.cj)

[原始复核记录](evidence/cjtui-rereview-extensions.json)

## RIN-01 · P2 · 宽字符错位覆盖旧宽字符时留下孤立 continuation

来源：相邻旧问题。

触发：Buffer(Rect(0,0,5,1)) 先 setString(1,0,"界")，再 setString(0,0,"中")；通过整个 Buffer clip 的 Canvas.drawText 做相同覆盖也触发。

预期：中占据 x0/x1，旧界在 x2 的 continuation 变为空白，所有 WideCont 都紧随对应 WideLead。

实际：两个公开写入路径均产生 [WideLead,WideCont,WideCont,Normal,Normal]，x2 成孤立 continuation。

建议：让普通文本写入也按完整新格组修复被覆盖的左右旧格组；在修复邻格前保留现有 clip 联合可写检查。补错位 CJK/emoji 覆盖及 blit/Canvas/直接写入对照。

- [packages/core/src/buffer.cj:363](../../../packages/core/src/buffer.cj)
- [packages/core/src/buffer.cj:115](../../../packages/core/src/buffer.cj)
- [packages/core/src/canvas.cj:172](../../../packages/core/src/canvas.cj)

[原始复核记录](evidence/cjtui-rereview-input.json)

## RIN-02 · P2 · 重叠选区删除会跳过较左选区并留下已选文字

来源：原修复不完整。

触发：TextArea("abcdef") 的 carets 选择 [1,4) 和 [3,5)，随后按 Delete 或 Backspace。

预期：删除已选区并集 [1,5)，结果为 af；顺序不能改变哪些已选文字被删掉。

实际：两种删除键都得到 abcf，只删除右边的 [3,5)，左选区中的 bc 被留下。

建议：删除类批量操作先合并相交范围，再执行与映射光标；保留单次 undo 语义，补不同 caret 输入顺序和跨行/Unicode 相交选区。

- [packages/core/src/text_area.cj:290](../../../packages/core/src/text_area.cj)
- [packages/core/src/text_area.cj:946](../../../packages/core/src/text_area.cj)
- [packages/core/src/text_area.cj:988](../../../packages/core/src/text_area.cj)

[原始复核记录](evidence/cjtui-rereview-input.json)

## RIN-03 · P2 · 相邻选区删除合到同一点后重复插入后续文本

来源：相邻旧问题。

触发：TextArea("ab") 设置两个相邻选区 [0,1)/[1,2)，Delete 后再 paste("x")。没有由调用者传入重复位置。

预期：删除后正文为空；合到同一位置的编辑光标应归一化，下一次插入结果为 x。

实际：删除后保留两个 offset=0 的 carets，下一次插入得到 xx。

建议：在编辑后统一归并重合 caret，并为同点零长度 edits 定义一次插入策略；保持主 caret 身份及 undo/redo 可恢复。

- [packages/core/src/text_area.cj:485](../../../packages/core/src/text_area.cj)
- [packages/core/src/text_area.cj:929](../../../packages/core/src/text_area.cj)
- [packages/core/src/text_area.cj:988](../../../packages/core/src/text_area.cj)

[原始复核记录](evidence/cjtui-rereview-input.json)

## RR-RT-01 · P2 · 显式 PTY 关闭先交付退出，再交付尾部输出；同 ID 重启会把旧尾部放到新启动之后

来源：原修复不完整。

触发：子进程已输出 READY，收到 TERM 时输出 TAIL 并正常退出。应用通过 App.processCommands 发 PtyClose；或在相同 ID 上发 PtyStart。对照回调分别继续处理和在 PtyExited 时返回 UpdateResult.exit。

预期：同一实例保留下来的输出应先于该实例最终退出事件交付；新实例的 Started 之后不应再出现无法区分的旧实例尾部。应用收到最终退出事件即可正常结束。

实际：继续处理得到 exited:slot → output:slot:TAIL。在 Exited 上退出时 tail=false，随后 runtime.drain().size=0，TAIL 已从 runtime 移入未交付队列而丢失。同 ID 重启得到 started:slot → output:slot:TAIL。

建议：为显式 close 与同 ID 替换定义一致的输出/终态派发顺序。排入同步生命周期事件之前交付该实例已有尾部，或在 runtime 内集中生成完整有序批次，并避免把旧实例输出交给新实例。保持既有公开事件类型即可完成修正。

- [packages/core/src/pty.cj:669](../../../packages/core/src/pty.cj)
- [packages/core/src/pty.cj:505](../../../packages/core/src/pty.cj)
- [packages/core/src/pty.cj:401](../../../packages/core/src/pty.cj)
- [packages/core/src/app.cj:2297](../../../packages/core/src/app.cj)
- [packages/core/src/app.cj:2351](../../../packages/core/src/app.cj)

[原始复核记录](evidence/cjtui-rereview-runtime.json)

## RR-RT-03 · P2 · 主动探测新增空读重试后，会丢掉探测期间到达的普通按键

来源：本次引入。

触发：KeyboardOptions(mode: Auto, probe: Active, probeBudgetMillis: 5)，parser 与 probe 共享一个输入来源：第一次 readAvailable 返回空，第二次返回普通 'a'。默认真实终端的两个 StdinInputSource 同样读取一个终端输入流。

预期：查询回复用于能力探测，普通键字节保留给 EventParser；等待终端回复不应改变普通键的交付。

实际：相同探针在基线 active=false/true 均收到 1 个 KeyDown；最终版 active=false 收到 1 个，active=true 收到 0 个。应用在两个 Tick 后结束，普通键没有交付。

建议：探测解析只消费完整查询回复，并把非回复字节以及未完成普通输入保存在可重放缓冲中，由普通输入路径按原顺序接收。回归覆盖首次空读、随后普通字符、回复与普通字符混合及分段到达。

- [packages/core/src/terminal.cj:634](../../../packages/core/src/terminal.cj)
- [packages/core/src/terminal.cj:826](../../../packages/core/src/terminal.cj)
- [packages/core/src/app.cj:1642](../../../packages/core/src/app.cj)

[原始复核记录](evidence/cjtui-rereview-runtime.json)

## RR-TOOL-02 · P2 · 注释中的合法 Unicode 分行符使 API 提取新增索引越界

来源：本次引入。

触发：待扫描 Cangjie 文件包含 /* doc\u2028continued */，随后有正常 public func 声明；\u2028 指实际 U+2028 字符。

预期：注释不产生声明，提取正常 public func，且源位置与原文一致。

实际：extract 抛 IndexError: list index out of range。相同注释已通过固定 20260817 SDK 的 cjc 编译。

建议：使原文、遮罩、行深度和偏移采用同一物理换行规则；加入 U+2028/U+2029 等注释或字符串输入，验证不产生假声明且不越界。

- [scripts/api_contract.py:359](../../../scripts/api_contract.py)
- [scripts/api_contract.py:226](../../../scripts/api_contract.py)

[原始复核记录](evidence/cjtui-rereview-tooling.json)

## RR-TOOL-03 · P2 · 显式 SDK 版本请求仍按子串筛选清单和 DevRepo 结果

来源：原修复不完整。

触发：清单同时包含 1.1.0-alpha.20260817040003 和 1.1.0-alpha.20260817040003.1；公开 CLI 显式请求前者。

预期：显式版本只选择完全相同的版本；默认 channel 查找仍可使用版本前缀。

实际：公开 CLI 退出 0，却返回 1.1.0-alpha.20260817040003.1。显式 URL 分支会拒绝同类不相等版本，清单/DevRepo 分支契约不一致。

建议：requested_version 非空时执行精确相等筛选，仅未指定版本时使用 channel 前缀；清单和 DevRepo 共用同一筛选逻辑并补显式 URL、清单、远端响应模拟的相同边界测试。

- [scripts/resolve_nightly_sdk.py:114](../../../scripts/resolve_nightly_sdk.py)
- [scripts/resolve_nightly_sdk.py:143](../../../scripts/resolve_nightly_sdk.py)
- [.github/workflows/ci.yml:18](../../../.github/workflows/ci.yml)

[原始复核记录](evidence/cjtui-rereview-tooling.json)

## RW-01 · P2 · 图表未超量程的大数值仍在高度换算中溢出

来源：相邻旧问题。

触发：TimeSeriesChart([4611686018427387904], maxValue: Int64.Max).render(Rect(0,0,1,4), buffer)。

预期：数值处于量程内，按比例绘制约两格高度并正常返回。

实际：抛出 OverflowException: mul；value=2、maxValue=4 的同尺寸对照正常显示两格。

建议：用不会溢出的比例换算，补低于/等于/高于量程及大整数对照；保留当前零值显示一格的既有选择。

- [packages/core/src/dashboard_widgets.cj:119](../../../packages/core/src/dashboard_widgets.cj)

[原始复核记录](evidence/cjtui-rereview-widgets.json)

## RW-02 · P2 · 直接 Widget.render 仍可通过宽字符配对修复改动传入区域外单元

来源：原修复不完整。

触发：Buffer(0,0,5,3) 先在(0,0)写界；在 Rect(1,0,1,3) 直接调用 List、Table、VirtualTable、ColorPicker、Block.render。

预期：区域外(0,0)保持；若不能在该区域内修复旧宽字，应保留整个旧宽字。

实际：五种直接 render 均把区域外(0,0)修改。相同组件经 Canvas(buffer,area).render(widget,area) 绘制时区域外保持。

建议：直接 Widget.render 也应在有效外框/正文区域内完成配对修复；复用已有范围机制，并补左右边缘及完整区域对照。

- [packages/core/src/widgets.cj:165](../../../packages/core/src/widgets.cj)
- [packages/core/src/widgets.cj:340](../../../packages/core/src/widgets.cj)
- [packages/core/src/widgets.cj:519](../../../packages/core/src/widgets.cj)
- [packages/core/src/data_widgets.cj:405](../../../packages/core/src/data_widgets.cj)
- [packages/core/src/form_widgets.cj:324](../../../packages/core/src/form_widgets.cj)
- [packages/core/src/buffer.cj:115](../../../packages/core/src/buffer.cj)

[原始复核记录](evidence/cjtui-rereview-widgets.json)

## RW-03 · P2 · 普通 DocumentHighlight 会再次拆开单个字素并丢掉组合符

来源：相邻旧问题。

触发：DocumentView(Document.plain("A\u{0301}B"), wrap: Character, highlights:[DocumentHighlight("A")])，宽1或宽3。

预期：高亮可改变样式，但组合符仍保留在 A 的字素中；有无高亮应保持相同文本。

实际：无高亮首格 symbol 为 A+组合重音；有高亮首格只有 A，宽1/宽3均丢失重音。

建议：在高亮匹配或最终排版阶段保持跨样式边界的字素完整性；补同一纯文本高亮前后的字形对照，并保留来源与样式信息。

- [packages/core/src/document.cj:678](../../../packages/core/src/document.cj)
- [packages/core/src/document.cj:780](../../../packages/core/src/document.cj)
- [packages/core/src/document.cj:838](../../../packages/core/src/document.cj)

[原始复核记录](evidence/cjtui-rereview-widgets.json)

## RW-04 · P2 · CommandPalette 尚未采用已经解析出的关联文本

来源：原修复不完整。

触发：EventParser 解析 ESC[97;2;65u 后，把同一 KeyDown 分别传给 CommandPalette、Input 和 TextArea。

预期：三种文本输入目标均使用关联文本 A；code 仍用于导航/快捷键分派。

实际：palette.query 为 a，Input.value 和 TextArea.value 为 A。

建议：对齐 Input/TextArea 的 Char 文本选择规则，并补 parser 到真实 CommandPalette 的关联文本回归。

- [packages/core/src/command_widgets.cj:164](../../../packages/core/src/command_widgets.cj)

[原始复核记录](evidence/cjtui-rereview-widgets.json)

## EXT-RR-02 · P3 · side-by-side 总宽度为 1 时写到传入区域之外

来源：相邻旧问题。

触发：对实际更宽的 Buffer 传入 Rect(0,0,1,4)，用 sideBySide=true 渲染仅新增行，并在目标 x=1,y=2 预置红色 Z。

预期：组件只能修改 Rect 覆盖的 x=0。

实际：leftWidth 和 rightWidth 都被 max(1,...) 设为 1，Add 分支从 area.x+leftWidth 即 x=1 写入，覆盖相邻单元。

建议：side-by-side 模式在总宽度小于 2 时回退单栏或给一侧零宽，并加入独立大 Buffer/小 area 的边界测试。

- [packages/diff/src/diff.cj:210](../../../packages/diff/src/diff.cj)
- [packages/diff/src/diff.cj:211](../../../packages/diff/src/diff.cj)
- [packages/diff/src/diff.cj:219](../../../packages/diff/src/diff.cj)

[原始复核记录](evidence/cjtui-rereview-extensions.json)

## EXT-RR-03 · P3 · 装箱容量已满且库存非空时状态仍显示 shipping box is empty

来源：新增限制的提示遗漏。

触发：有效存档令 shipping 某项为 1000000 且对应 inventory 大于 0，然后在装箱点执行动作。

预期：库存保留，并提示装箱容量已满或没有可转移空间。

实际：count=min(inventory, MAX_SAVE_COUNT-shipping)=0，moved 保持 0，统一进入 empty 文案；库存实际非空。

建议：区分总库存为零和装箱空间为零，并为已满 shipping 加非空 inventory 的状态用例。

- [examples/game_demo/src/main.cj:415](../../../examples/game_demo/src/main.cj)
- [examples/game_demo/src/main.cj:418](../../../examples/game_demo/src/main.cj)
- [examples/game_demo/src/main.cj:423](../../../examples/game_demo/src/main.cj)

[原始复核记录](evidence/cjtui-rereview-extensions.json)

## RIN-04 · P3 · 折叠隐藏的额外 caret 仍返回折叠头可见坐标

来源：原修复不完整。

触发：正文 0\n1\n2\n3，primary offset0、extra offset3，DocumentViewState.setFolded(0,3,true)，2 行视口 render 后查询 cursorPositions。

预期：依照修复记录的不可见额外 caret 不返回位置策略，隐藏在折叠范围内的 extra 应省略；primary 视口不变。

实际：未折叠坐标是 (0,0)/(1,1)；折叠后仍返回两个坐标 (0,0)/(1,0)，把隐藏 caret 投射到折叠头。scroll 均保持 0。

建议：为 extra caret 先检查真实可见行成员关系或折叠隐藏状态；primary 如需保持折叠头回落可单独保留。

- [packages/core/src/text_area.cj:438](../../../packages/core/src/text_area.cj)
- [packages/core/src/text_area.cj:1172](../../../packages/core/src/text_area.cj)
- [docs/reviews/2026-09-08-fixes/evidence/input-results.json:484](../../../docs/reviews/2026-09-08-fixes/evidence/input-results.json)

[原始复核记录](evidence/cjtui-rereview-input.json)

## RR-REPORT-01 · P3 · CJTUI-047 汇总误述采样器修复方式

来源：配套说明问题。

实际：前后台分别持有独立 ProcFsSampler，completionLock 仅保护完成结果槽。

建议：将完整事务锁更正为采样器实例分离；保留没有长期并发测量的限制。

- [错误汇总位置](../2026-09-08-fixes/status.json)

## RR-RT-02 · P3 · Headless 等待步骤发出正确 Tick，但帧指标仍使用旧时间差

来源：相邻旧问题。

触发：AppTestRunner.run(HeadlessScript().waitMillis(7), ..., tickDeltaMillis: 7)，读取最后一帧指标；以仅 tick() 的同配置执行作对照。

预期：等待步骤产生 Tick.deltaMillis=7 时，对应帧的 tickDeltaMillis 应同为 7，fps 应使用这次时间差计算。

实际：wait=false 得到 event-delta=7、metric-delta=7、fps=142；wait=true 得到 event-delta=7、metric-delta=0、fps=0。前面已有其他 Tick 时指标会沿用那一次值。

建议：WaitMillis 分支在 capture 之前同步 lastTickDelta，并为独立 wait 和不同时间差的 tick→wait 组合断言帧指标。

- [packages/core/src/app.cj:1243](../../../packages/core/src/app.cj)
- [packages/core/src/app.cj:269](../../../packages/core/src/app.cj)

[原始复核记录](evidence/cjtui-rereview-runtime.json)

## RR-RT-04 · P3 · App 启动能力事件仍使用探测前的 driver 能力

来源：相邻旧问题。

触发：自定义 TerminalDriver 的 capabilities.keyUp=false，Active probe 收到库可识别的 ESC[?1u；比较直接 TerminalProbe 结果与应用启动 Event.Capabilities。

预期：应用启动能力事件应包含已经完成的主动探测结果，使消费者能据此选择键盘能力。

实际：基线和最终版均为 probe-keyup=true，app-capabilities-keyup=false。

建议：App 构造启动能力事件时采用已完成的 Session 探测结果，并在无结果时回退 driver。补探测成功与禁用/超时对照。

- [packages/core/src/terminal.cj:826](../../../packages/core/src/terminal.cj)
- [packages/core/src/app.cj:1683](../../../packages/core/src/app.cj)

[原始复核记录](evidence/cjtui-rereview-runtime.json)

## RR-TOOL-04 · P3 · 示例 smoke 的旧工作流说明没有随组件组合重定位更新

来源：配套说明问题。

触发：用户按 testing/regression-matrix 判断 packages/example_smoke 对哪些实际应用提供工作流覆盖。

预期：文档明确该包运行四个 core 组件组合；真实 taskpad 等应用由各示例包的 *_test.cj 验证。

实际：文档仍描述 main example workflows，并具体声称 taskpad、data browser、ops dashboard、terminal lab、markdown studio 和 assistant console 的 HeadlessScript 工作流。当前 main 只调用 Composer/Palette/Request/Table 四个组合。

建议：改写两处旧说明，并把四个组件组合、真实示例测试、少数 CLI headless smoke 的运行入口分别说清楚。

- [docs/testing.md:82](../../../docs/testing.md)
- [docs/regression-matrix.md:34](../../../docs/regression-matrix.md)
- [packages/example_smoke/src/main.cj:172](../../../packages/example_smoke/src/main.cj)

[原始复核记录](evidence/cjtui-rereview-tooling.json)

## RW-05 · P3 · VirtualTranscriptView 的左 padding 大于可用宽度时仍把正文画到区域外

来源：相邻旧问题。

触发：setCardTheme(TranscriptCardTheme(fillBackground:true, contentPadding:Spacing(left:6)))；正文x，区域Rect(1,0,4,3)，物理Buffer宽12。

预期：有效正文宽度为零时省略正文，区域外保持。

实际：正文 x 出现在 x=7，超过区域 right=5；padding.left=1 的对照位于区域内。

建议：区分用于测量的最低宽度与可绘制内容区域；正文区域为空时不写入，并验证左/右 padding 耗尽区域的场景。

- [packages/core/src/virtual_transcript.cj:875](../../../packages/core/src/virtual_transcript.cj)
- [packages/core/src/virtual_transcript.cj:1092](../../../packages/core/src/virtual_transcript.cj)

[原始复核记录](evidence/cjtui-rereview-widgets.json)

