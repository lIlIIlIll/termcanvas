# 逐项复核结果

所有条目均已处理。验证方式和各组原始记录见下表；平台限制见总报告。

| 编号 | 问题 | 验证方式 | 记录 |
| --- | --- | --- | --- |
| RR-RT-01 | 显式 PTY 关闭先交付退出，再交付尾部输出；同 ID 重启会把旧尾部放到新启动之后 | 公共行为测试及主审 | [组内证据](evidence/runtime-results.json) |
| RR-RT-02 | Headless 等待步骤发出正确 Tick，但帧指标仍使用旧时间差 | 公共行为测试及主审 | [组内证据](evidence/runtime-results.json) |
| RR-RT-03 | 主动探测新增空读重试后，会丢掉探测期间到达的普通按键 | 公共行为测试及主审 | [组内证据](evidence/runtime-results.json) |
| RR-RT-04 | App 启动能力事件仍使用探测前的 driver 能力 | 公共行为测试及主审 | [组内证据](evidence/runtime-results.json) |
| RIN-01 | 宽字符错位覆盖旧宽字符时留下孤立 continuation | 公共行为测试及主审 | [组内证据](evidence/input-results.json) |
| RIN-02 | 重叠选区删除会跳过较左选区并留下已选文字 | 公共行为测试及主审 | [组内证据](evidence/input-results.json) |
| RIN-03 | 相邻选区删除合到同一点后重复插入后续文本 | 公共行为测试及主审 | [组内证据](evidence/input-results.json) |
| RIN-04 | 折叠隐藏的额外 caret 仍返回折叠头可见坐标 | 公共行为测试及主审 | [组内证据](evidence/input-results.json) |
| RW-01 | 图表未超量程的大数值仍在高度换算中溢出 | 公共行为测试及主审 | [组内证据](evidence/widgets-results.json) |
| RW-02 | 直接 Widget.render 仍可通过宽字符配对修复改动传入区域外单元 | 公共行为测试及主审 | [组内证据](evidence/widgets-results.json) |
| RW-03 | 普通 DocumentHighlight 会再次拆开单个字素并丢掉组合符 | 公共行为测试及主审 | [组内证据](evidence/widgets-results.json) |
| RW-04 | CommandPalette 尚未采用已经解析出的关联文本 | 公共行为测试及主审 | [组内证据](evidence/widgets-results.json) |
| RW-05 | VirtualTranscriptView 的左 padding 大于可用宽度时仍把正文画到区域外 | 公共行为测试及主审 | [组内证据](evidence/widgets-results.json) |
| RR-TOOL-01 | 生成 Windows runner 时把赋值放在 param 前，使脚本参数块失效 | 本地 fixture 及主审 | [组内证据](evidence/tooling-results.json) |
| RR-TOOL-02 | 注释中的合法 Unicode 分行符使 API 提取新增索引越界 | 公共行为测试及主审 | [组内证据](evidence/tooling-results.json) |
| RR-TOOL-03 | 显式 SDK 版本请求仍按子串筛选清单和 DevRepo 结果 | 本地 fixture 及主审 | [组内证据](evidence/tooling-results.json) |
| RR-TOOL-04 | 示例 smoke 的旧工作流说明没有随组件组合重定位更新 | 文档与实现核对 | [组内证据](evidence/tooling-results.json) |
| EXT-RR-01 | TerminalScreen 窄区域复制可留下孤立 WideLead | 公共行为测试及主审 | [组内证据](evidence/extensions-results.json) |
| EXT-RR-02 | side-by-side 总宽度为 1 时写到传入区域之外 | 公共行为测试及主审 | [组内证据](evidence/extensions-results.json) |
| EXT-RR-03 | 装箱容量已满且库存非空时状态仍显示 shipping box is empty | 公共行为测试及主审 | [组内证据](evidence/extensions-results.json) |
| RR-REPORT-01 | CJTUI-047 汇总误述采样器修复方式 | 文档与实现核对 | [组内证据](evidence/tooling-results.json) |
