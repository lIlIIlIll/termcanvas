# 文本、文档与编辑器代码审计

基线：`e30b1c5`。本报告基于当前源文件、公开 API、现有测试和新增回归独立得出；历史审计报告不作为问题确认依据。

## 覆盖范围

| 文件 | 基线行数 | 检查内容 |
| --- | ---: | --- |
| `packages/core/src/text.cj` | 863 | 字宽、字素分割、换行、截断、UTF-8 边界、样式编码及数值解析辅助逻辑 |
| `packages/core/src/text_buffer.cj` | 456 | 全部读写、范围/位置换算、搜索、撤销重做与单词移动逻辑 |
| `packages/core/src/text_area.cj` | 1910 | 全部编辑/选择/多光标/补全/缓存/折叠/绘制路径及 Markdown 编辑策略 |
| `packages/core/src/vim_editor.cj` | 324 | Normal/Insert 状态、重复按键、撤销组、只读模式、补全与行删除 |
| `packages/core/src/document.cj` | 963 | 文档主题、布局缓存、来源映射、折叠、样式分割、高亮与换行 |
| `packages/core/src/unicode_data.cj` | 2088 | 生成函数与属性选择；通过生成器逐行比较完整 Unicode 17 数据输出 |

手写文件共 4516 行，生成表共 2088 行。关联读取了 `content_widgets.cj` 的 Markdown 编辑辅助函数，以及 `lib_test.cj`、`vim_editor_test.cj`、`boundary_extreme_test.cj`、`audit_input_test.cj`、`expanded_contract_test.cj` 的相关契约。Unicode 生成检查命令 `python3 scripts/generate_unicode_tables.py --check` 已通过。

## 已确认问题

所有新增回归位于 `packages/core/src/audit_20261003_text_test.cj`。以下位置均为基线位置。

| 编号 | 位置 | 触发与实际影响 | 修复与回归 |
| --- | --- | --- | --- |
| TEXT-01 | `text_buffer.cj:435–443` | `nextWordOffset` 先前进一个字素后才判断空白。在 `"one two"` 的空格处（偏移 3）执行右移一个词：`TextArea` 跳到 7，Vim `w` 归一化到 6，均跳过目标词首 4。 | 从当前已归一化边界开始扫描当前词与后续空白。`wordRightFromWhitespaceStopsAtNextWord` 同时覆盖 TextBuffer、Ctrl+Right 和 Vim `w`，并检查词内、词首行为。 |
| TEXT-02 | `text_area.cj:1581–1592` | 在 Markdown 编辑模式输入 `9223372036854775807. item` 并按 Enter，`number + 1` 抛 `OverflowException: add`。更长数字也会在累积时溢出，普通文档内容因此可以中断输入处理。 | 改为十进制字符串进位，保留原有去除前导零行为，不扩充资源限额。`orderedListContinuationDoesNotOverflow` 覆盖 Int64.Max、30 位全 9 数字、前导零及撤销。 |
| TEXT-03 | `document.cj:739–753` | 公共 `RichSpan.sourceRange` 含超大十进制来源偏移时，调用 `DocumentView.sourceOffsetForRenderedLine` 即在布局/折叠检查中抛 `OverflowException: mul`。没有启用折叠也会触发。 | 累积前检查 Int64 上界，非法偏移返回 `None`。`overflowingDocumentSourceOffsetsAreIgnored` 覆盖布局查询、来源查找、Int64.Max 及超界结束偏移。 |
| TEXT-04 | `text_area.cj:613–622,647–652,1297–1299` | 待完成请求上调用 `cancelCompletion()` 没有效果；已显示菜单按 Esc 也保留请求身份。同一请求的延迟/重复结果会重新打开菜单。另外，发起新请求时旧菜单仍可显示和被接受。 | 取消时同时失效请求身份与 revision；新请求先关闭旧结果；Esc 复用取消路径；结果同时核对请求与当前 revision。对应 `canceledPendingCompletionCannotReopen`、`escapeDismissalRejectsRepeatedCompletionResults`、`startingCompletionHidesPreviousResults`。 |
| TEXT-05 | `text_buffer.cj:91–110,162–183,238–268` | 插入空串、删除空范围、文首 Backspace、文末 Delete、等值替换都创建没有文本变化的撤销记录；多数路径还清空重做。实际先插入 `d`、撤销，再做无效编辑，会失去原本可重做的 `abcd`。 | 在记录历史前检测无效编辑；等值 replaceAll 仍返回匹配次数。`noOpTextBufferEditsPreserveRedo` 覆盖上述六条路径，检查不存在虚假 undo 且原 redo 保留。 |
| TEXT-06 | `text_area.cj:1787–1889` | `MarkdownEditorBehavior` 在只读 TextArea 上仍运行自动括号与插入命令。底层 paste 拒绝文本写入后，辅助逻辑继续增加 cursor/更改 selection。`"abc"` 文末输入 `[` 得 cursor 4，再插入 frontmatter 得 cursor 29；后续 `cursorPosition()` 抛 `IndexOutOfBoundsException`。 | 所有 Markdown 编辑命令入口尊重 readOnly；按键入口仍将只读导航交给 TextArea。`markdownReadonlyCommandsKeepCursorAndSelectionValid` 检查输入、frontmatter、加粗、坐标及左移。 |

## 实际运行结果

环境为 Linux x86_64、Cangjie SDK 1.1.3。首次编译发现两处测试宏的 `None` 类型推导歧义；显式声明 `?Int64` 后再执行基线测试，以下结果均来自成功编译后的实际运行。

| 回归 | 修复前 | 修复后 |
| --- | --- | --- |
| `wordRightFromWhitespaceStopsAtNextWord` | FAILED；Ctrl+Right 实际 7、Vim 实际 6，期望 4 | PASSED |
| `orderedListContinuationDoesNotOverflow` | ERROR；`OverflowException: add` | PASSED |
| `overflowingDocumentSourceOffsetsAreIgnored` | ERROR；`OverflowException: mul` | PASSED |
| `canceledPendingCompletionCannotReopen` | FAILED；结果被接受且菜单重新显示 | PASSED |
| `escapeDismissalRejectsRepeatedCompletionResults` | FAILED；重复结果被接受且菜单重新显示 | PASSED |
| `startingCompletionHidesPreviousResults` | FAILED；旧菜单仍显示 | PASSED |
| `noOpTextBufferEditsPreserveRedo` | FAILED；虚假 undo 且 redo 后仍为 `abc` | PASSED |
| `markdownReadonlyCommandsKeepCursorAndSelectionValid` | ERROR；游标错误后 `IndexOutOfBoundsException` | PASSED |

基线日志由主审计保留为 `core-before.log`；本模块 8 个 case 中 5 个断言失败、3 个异常。修复后 `core-after.log` 中 8 个新增 case 全部通过，完整 core 测试 698/698 通过（包括现有 Unicode 17 字素边界夹具和 Vim 测试）。实现只修改 `text_buffer.cj`、`text_area.cj`、`document.cj`，公开 API 签名不变。

## 验证边界

- 本模块新增回归是确定性的内存级行为验证，不代表所有真实终端的字宽实现相同；现有 Unicode 字宽选项与心形变体宽度契约保持不变。
- 补全失效覆盖显式取消、Esc 和新请求切换；调用方应为不同请求提供不同 ID。本次未改造整个异步请求协议。
- 未将 TextArea 任意外部写入非法 cursor、跨 RichSpan 的字素切分或大文件算法复杂度作为本轮已修复问题；这些边界没有加入确认清单。
- 生成表通过现有 Unicode 17 夹具与生成脚本验证，不声称外部 Unicode 数据源本身经过重新认证。

集成说明：上述 698/698 是首轮集成快照；追加组件极端边界回归后，最终 release gate 的 core 为 700/700。详见总报告。
