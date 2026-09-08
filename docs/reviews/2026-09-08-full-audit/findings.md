# 问题明细

[返回总览](README.md)。原始候选与合并关系见 [去向记录](evidence/synthesis/rejected_or_merged.json)。

## CJTUI-001

**P1 · 已复现 · PTY 未建立子进程组，启动失败与信号转发会命中错误目标**

位置：[packages/core/src/pty.cj:400](../../../packages/core/src/pty.cj#L400)、[packages/core/src/pty.cj:592](../../../packages/core/src/pty.cj#L592)、[packages/core/src/pty.cj:744](../../../packages/core/src/pty.cj#L744)、[packages/core/src/pty.cj:754](../../../packages/core/src/pty.cj#L754)。

**原因：** fork 后没有建立 PGID=childPid 的会话关系；exec 失败分支调用 kill(0, SIGKILL)，公开 signal 路径却调用 kill(-childPid, signal)。

**观察：** 无效命令探针所在独立进程组以 SIGKILL 结束；正常子进程的 signal 调用返回 PtyFailed。

**影响：** 无效命令可终止 TUI 宿主及同组进程，且 Ctrl-C、终止和窗口相关信号不能可靠送达 PTY 作业。

**建议：** 子进程启动时建立明确会话/进程组；exec 失败只退出当前子进程并通过启动错误通道回报；所有信号路径使用同一已验证的进程组身份。

**兼容性：** 可保持 PtySpec 与 signal API 形状；需明确启动失败事件和子进程组语义。

证据：[logs/run-runtime-probe-pty-invalid-exec.log](evidence/logs/run-runtime-probe-pty-invalid-exec.log)、[logs/run-runtime-probe-pty-signal.log](evidence/logs/run-runtime-probe-pty-signal.log)、[logs/run-runtime-probe-pty-control.log](evidence/logs/run-runtime-probe-pty-control.log)。

原始条目：`RT-01`, `RT-02`。

## CJTUI-002

**P2 · 已复现 · PTY 退出回收由多个路径竞争，产生虚构终态或残留 active 记录**

位置：[packages/core/src/pty.cj:463](../../../packages/core/src/pty.cj#L463)、[packages/core/src/pty.cj:482](../../../packages/core/src/pty.cj#L482)、[packages/core/src/pty.cj:550](../../../packages/core/src/pty.cj#L550)、[packages/core/src/pty.cj:662](../../../packages/core/src/pty.cj#L662)。

**原因：** close、onReady(HUP) 与 drain 都调用 waitpid 并各自决定状态；close 在一次 WNOHANG 后即移除记录，HUP 路径则可能先回收而让 drain 永远无法删除记录。

**观察：** 真实 HUP 产生一次 exit=7 后 active 仍为 1，第二次 drain 仍无事件且 active=1；close 路径可直接报告 signal=15。

**影响：** 调用方可能收到与真实进程状态不一致的终态，已退出记录会累积，后续同 ID 管理和资源诊断失真。

**建议：** 指定唯一回收所有者；把关闭请求、信号发送、waitpid 完成和记录删除建成单一状态机，仅在获得真实 wait status 后发布终态。

**兼容性：** 事件类型可不变；终态时序会更准确，依赖当前虚构状态的调用需要调整。

**证据限制：** RT-04 的 active 残留完整复现；RT-03 只复现已知 exit=7 后又发布 signal=15，没有独立观察子 PID 的实际回收过程。

证据：[logs/run-runtime-probe-pty-hup.log](evidence/logs/run-runtime-probe-pty-hup.log)、[logs/run-runtime-probe-pty-signal.log](evidence/logs/run-runtime-probe-pty-signal.log)、[logs/run-runtime-probe-pty-control.log](evidence/logs/run-runtime-probe-pty-control.log)。

原始条目：`RT-03`, `RT-04`。

## CJTUI-003

**P2 · 已复现 · PTY 非阻塞写入把短写当作整批成功**

位置：[packages/core/src/pty.cj:544](../../../packages/core/src/pty.cj#L544)、[packages/core/src/pty.cj:565](../../../packages/core/src/pty.cj#L565)、[packages/core/src/pty.cj:768](../../../packages/core/src/pty.cj#L768)。

**原因：** write 只调用一次，任意非负返回值都被当成成功；没有比较 written 与请求长度，也没有保存剩余字节和注册可写事件。

**观察：** 请求写入 1,048,576 字节时 API 报成功，子进程只收到 11,776 字节；8 字节对照完整到达。

**影响：** 大段粘贴、协议帧或批量输入会在无错误结果下被截断。

**建议：** 循环写完或保存未写部分并监听可写状态；在完成全部字节前不要返回整批成功。

**兼容性：** 保持 write 命令入口；若引入排队结果，应明确背压和关闭时剩余数据的处理。

证据：[logs/run-runtime-probe_extra-write-large.log](evidence/logs/run-runtime-probe_extra-write-large.log)、[logs/run-runtime-probe_extra-write-control.log](evidence/logs/run-runtime-probe_extra-write-control.log)。

原始条目：`RT-05`。

## CJTUI-004

**P2 · 已复现 · PTY 启动忽略无效 cwd 并在宿主目录继续执行**

位置：[packages/core/src/pty.cj:728](../../../packages/core/src/pty.cj#L728)。

**原因：** 子进程丢弃 chdir 返回值并继续 execvp。

**观察：** 请求不存在的 cwd 后 /bin/pwd 输出审查临时目录；有效 cwd=/tmp 的对照输出 /tmp。

**影响：** 相对路径命令会读取或写入错误目录，调用方却收到正常启动和退出。

**建议：** chdir 失败时停止 exec，通过启动错误通道返回目录和系统错误。

**兼容性：** PtySpec 不需改型；此前静默回退的调用会改为明确失败。

证据：[logs/run-runtime-probe-cwd-invalid.log](evidence/logs/run-runtime-probe-cwd-invalid.log)、[logs/run-runtime-probe-cwd-control.log](evidence/logs/run-runtime-probe-cwd-control.log)。

原始条目：`RT-06`。

## CJTUI-005

**P2 · 已复现 · 单次异步任务取消发布两次 AsyncCancelled**

位置：[packages/core/src/app.cj:541](../../../packages/core/src/app.cj#L541)、[packages/core/src/app.cj:558](../../../packages/core/src/app.cj#L558)、[packages/core/src/app.cj:2211](../../../packages/core/src/app.cj#L2211)。

**原因：** 命令处理在接收 CancelAsync 时立即入队 AsyncCancelled，drain 看到 cancelRequested 后再次生成同一终态。

**观察：** 一个 AsyncStarted 后连续出现两条 AsyncCancelled，SUMMARY cancelled=2。

**影响：** 取消回调、计数、通知或资源清理可能执行两次。

**建议：** 只让任务状态机的一处发布终态，并以 terminalDelivered 标志保证每个任务一次。

**兼容性：** 重复终态会消失；事件类型和公开 ID 可保持。

证据：[logs/run-runtime-probe-async-cancel.log](evidence/logs/run-runtime-probe-async-cancel.log)、[logs/run-runtime-probe-async-control.log](evidence/logs/run-runtime-probe-async-control.log)。

原始条目：`RT-07`。

## CJTUI-006

**P2 · 已复现 · AsyncRuntime 清理仅位于正常 App 回调，helper 与启动失败路径会遗留唤醒资源**

位置：[packages/core/src/app.cj:512](../../../packages/core/src/app.cj#L512)、[packages/core/src/app.cj:581](../../../packages/core/src/app.cj#L581)、[packages/core/src/app.cj:841](../../../packages/core/src/app.cj#L841)、[packages/core/src/app.cj:1163](../../../packages/core/src/app.cj#L1163)、[packages/core/src/app.cj:1594](../../../packages/core/src/app.cj#L1594)、[packages/core/src/app.cj:1985](../../../packages/core/src/app.cj#L1985)、[packages/core/src/terminal.cj:751](../../../packages/core/src/terminal.cj#L751)。

**原因：** ExternalPort 的关闭依赖 session.run 回调内的 finally；若 helper 自建运行时或 TerminalSession.start 在回调前抛错，该清理路径不会执行。

**观察：** 重复 helper 后新 ExternalPort 从 Accepted 变为 Closed；startup-failure 返回后原 external port 仍 Accepted，而正常运行后为 Closed。

**影响：** 多轮测试、命令处理或启动重试会耗尽 FD/句柄，并让生产者误以为失败的运行时仍可接收工作。

**建议：** 让 AsyncRuntime 显式实现幂等 close，并把所有构造后的路径纳入外层 finally；helper 应拥有并关闭其运行时。

**兼容性：** 可增加 close/withRuntime 边界而不改变现有命令；关闭屏障将更早生效。

证据：[logs/run-runtime-probe_extra-fds-headless.log](evidence/logs/run-runtime-probe_extra-fds-headless.log)、[logs/run-runtime-probe_extra-fds-commands.log](evidence/logs/run-runtime-probe_extra-fds-commands.log)、[logs/run-runtime-probe-startup-failure.log](evidence/logs/run-runtime-probe-startup-failure.log)、[logs/run-runtime-probe-startup-control.log](evidence/logs/run-runtime-probe-startup-control.log)。

原始条目：`RT-09`, `RT-10`。

## CJTUI-007

**P2 · 已复现 · 待定裸 ESC 未进入事件等待截止时间**

位置：[packages/core/src/app.cj:1946](../../../packages/core/src/app.cj#L1946)、[packages/core/src/app.cj:1971](../../../packages/core/src/app.cj#L1971)、[packages/core/src/app.cj:2097](../../../packages/core/src/app.cj#L2097)。

**原因：** ESC 仅按后续循环次数 flush，waiter timeout 只考虑 tick、timer、frame 和 resize；待定 ESC 时仍可无限等待或依赖无关事件。

**观察：** 延迟输入对照在 300ms guard 前交付 1 个 Esc，裸 ESC 场景在 guard 前为 0。

**影响：** 取消、关闭弹窗等 Esc 操作可能直到下一外部事件才响应。

**建议：** 把 parser 的 ESC deadline 合并进 waiter 的最早截止时间，并按真实单调时间完成 flush。

**兼容性：** 保持键事件形状；修正延迟只会让配置过的 Esc 更准时。

证据：[logs/run-runtime-probe_extra-esc-delayed.log](evidence/logs/run-runtime-probe_extra-esc-delayed.log)、[logs/run-runtime-probe_extra-esc-control.log](evidence/logs/run-runtime-probe_extra-esc-control.log)。

原始条目：`RT-11`。

## CJTUI-008

**P2 · 已复现 · Linux epoll 事件按错误步长解码并漏派同批 source**

位置：[packages/core/src/app.cj:61](../../../packages/core/src/app.cj#L61)、[packages/core/src/app.cj:2468](../../../packages/core/src/app.cj#L2468)。

**原因：** x86_64 Linux 的 packed epoll_event 步长为 12 字节，代码固定按 16 字节递增。

**观察：** 一个 ready source 时回调数为 1；两个同时 ready 时第一项为 1、第二项为 0，尽管两项 completion 都存在。

**影响：** 同批异步、外部端口或 PTY 就绪事件会延迟或漏派，可能造成界面停顿。

**建议：** 按目标 ABI 定义匹配的结构布局，或通过窄原生封装返回已解析事件；增加双 source 同批断言。

**兼容性：** 内部 FFI 修复，不改公开 API；需按支持的 Linux 架构分别验证布局。

证据：[logs/run-runtime-probe_epoll-two-sources.log](evidence/logs/run-runtime-probe_epoll-two-sources.log)、[logs/run-runtime-probe_epoll-one-source.log](evidence/logs/run-runtime-probe_epoll-one-source.log)。

原始条目：`RT-12`。

## CJTUI-009

**P1 · 已复现 · FD 数值复用后 epoll 注册缓存把新 source 当作旧注册**

位置：[packages/core/src/app.cj:2493](../../../packages/core/src/app.cj#L2493)。

**原因：** 注册缓存只比较 fd 数值和 interest；旧 fd 关闭后内核已移除注册，新资源复用相同数值时 reconcile 不再执行 ADD。

**观察：** old/new 的 stdout 与 stderr fd 分别复用 4/6；复用 waiter 得不到 READY，但人工读取立即读到 READY；新 waiter 对照正常交付。

**影响：** 重新启动 PTY 或替换同类 source 后，新命令已有输出却永远没有就绪通知。

**建议：** 注册身份加入 source 实例代次，移除 source 时同步清缓存；新实例即使 fd/events 相同也必须重新 ADD。

**兼容性：** EventSource API 可保持；内部注册身份需从裸 fd 扩展。

证据：[logs/run-runtime-probe_extra-reuse-waiter.log](evidence/logs/run-runtime-probe_extra-reuse-waiter.log)、[logs/run-runtime-probe_extra-reuse-control.log](evidence/logs/run-runtime-probe_extra-reuse-control.log)。

原始条目：`RT-13`。

## CJTUI-010

**P2 · 已复现 · AppTestRunner 不持久化 StartTimer 创建的运行时状态**

位置：[packages/core/src/app.cj:1168](../../../packages/core/src/app.cj#L1168)、[packages/core/src/app.cj:1194](../../../packages/core/src/app.cj#L1194)、[packages/core/src/app.cj:1235](../../../packages/core/src/app.cj#L1235)、[packages/core/src/app.cj:2147](../../../packages/core/src/app.cj#L2147)。

**原因：** runner 只持久化 AsyncRuntime；每次 dispatch 使用临时 TimerRuntime，WaitMillis 也不 drain 先前创建的 timer。

**观察：** 相同 StartTimer 模型在真实 App 路径得到 TIMERS=1，在 headless runner 中为 0。

**影响：** 依赖 timer 的应用可以通过 headless 验证却在真实运行中表现不同，或其 timer 回调根本未被测试。

**建议：** 让 runner 持有与 App 同生命周期的 TimerRuntime，并让虚拟时间推进触发同一 drain 语义。

**兼容性：** 会改变 headless 观察结果，使其与生产语义一致；已有依赖漏触发的快照需要更新。

证据：[logs/run-runtime-probe_extra-timer-headless.log](evidence/logs/run-runtime-probe_extra-timer-headless.log)、[logs/run-runtime-probe_extra-timer-app.log](evidence/logs/run-runtime-probe_extra-timer-app.log)。

原始条目：`RT-14`。

## CJTUI-011

**P2 · 已复现 · TerminalProbe 首次空读即放弃剩余预算**

位置：[packages/core/src/terminal.cj:624](../../../packages/core/src/terminal.cj#L624)。

**原因：** 能力探测在第一次暂时无响应时 break，没有在预算窗口内继续等待。

**观察：** 立即响应对照执行 2 次读取、消费 5 字节并识别 key_up；延迟响应只读取 1 次、消费 0 字节并回退。

**影响：** 正常稍晚到达的终端响应被忽略，增强键盘等能力经常误判为不可用。

**建议：** 空读只表示本次暂无数据；在预算截止前按短 deadline 重试，并保留已收片段。

**兼容性：** 能力结果会更准确；可保留现有回退策略和公开返回类型。

证据：[logs/run-runtime-probe_extra-probe-delayed.log](evidence/logs/run-runtime-probe_extra-probe-delayed.log)、[logs/run-runtime-probe_extra-probe-control.log](evidence/logs/run-runtime-probe_extra-probe-control.log)。

原始条目：`RT-15`。

## CJTUI-012

**P2 · 已复现 · 会话恢复后光标物理状态与 Terminal 缓存不同步**

位置：[packages/core/src/terminal.cj:244](../../../packages/core/src/terminal.cj#L244)、[packages/core/src/terminal.cj:355](../../../packages/core/src/terminal.cj#L355)、[packages/core/src/terminal.cj:408](../../../packages/core/src/terminal.cj#L408)、[packages/core/src/terminal.cj:703](../../../packages/core/src/terminal.cj#L703)、[packages/core/src/app.cj:1661](../../../packages/core/src/app.cj#L1661)。

**原因：** session.start 每次隐藏物理光标，但 Terminal.cursorVisible 仍保留 true，clear 也不重置该缓存，下一帧因此省略 showCursor。

**观察：** 正常未恢复对照不需要 showCursor；stop/start 恢复后的首次重绘同样没有输出 showCursor。

**影响：** 暂停恢复后的文本框或编辑器光标不可见，直到后续状态切换偶然纠正。

**建议：** start/stop/clear 时统一重置物理状态缓存，恢复后首帧按请求重新发出光标命令。

**兼容性：** 只修正终端输出状态，不改 Terminal API。

证据：[logs/run-runtime-probe_extra-cursor-resume.log](evidence/logs/run-runtime-probe_extra-cursor-resume.log)、[logs/run-runtime-probe_extra-cursor-control.log](evidence/logs/run-runtime-probe_extra-cursor-control.log)。

原始条目：`RT-16`。

## CJTUI-013

**P1 · 静态确认 · macOS 分支复用 Linux 非阻塞与窗口 ioctl 常量**

位置：[packages/core/src/pty.cj:63](../../../packages/core/src/pty.cj#L63)、[packages/core/src/pty.cj:75](../../../packages/core/src/pty.cj#L75)、[packages/core/src/pty.cj:768](../../../packages/core/src/pty.cj#L768)、[packages/core/src/runtime_foundation.cj:584](../../../packages/core/src/runtime_foundation.cj#L584)、[packages/core/src/runtime_foundation.cj:609](../../../packages/core/src/runtime_foundation.cj#L609)、[packages/core/src/runtime_foundation.cj:751](../../../packages/core/src/runtime_foundation.cj#L751)。

**原因：** Unix 共用 O_NONBLOCK=0x800 和 TIOCSWINSZ=0x5414；Darwin 的对应值和编码不同，wake pipe 因此不能按预期设为非阻塞。

**观察：** 源码没有 Darwin 常量分支；审查记录依据 Apple XNU 头文件确认 O_NONBLOCK=0x4，0x800 对应其他标志。本轮无 macOS 运行日志。

**影响：** macOS 的空 wake pipe read/close 可能阻塞，PTY resize 也会使用错误 request，影响整套 App 运行。

**建议：** 从目标平台头文件经原生封装取得常量和结构，不在 Cangjie 层跨 Unix 复用数值；补 macOS 空闲 wake 与 resize 验证。

**兼容性：** 内部平台实现修复，不改公开 API；仍需真实 macOS gate 确认。

**证据限制：** 没有 macOS 编译或运行记录；结论来自当前源码与 Apple XNU fcntl.h、ttycom.h 的平台定义，Linux 运行结果不能替代目标平台 gate。

证据：。

原始条目：`RT-17`。

## CJTUI-014

**P2 · 已复现 · Alt+UTF-8 字符跨输入帧时丢失 Alt 修饰位**

位置：[packages/core/src/event.cj:665](../../../packages/core/src/event.cj#L665)。

**原因：** parseAltKey 在确认多字节字符完整前先消费 ESC；后续帧恢复普通 UTF-8 解码时已没有 Alt 状态。

**观察：** 完整 ESC+中输出 alt=true；在 UTF-8 字节内切分时输出同一字符但 alt=false，所有其他冻结切分组保持一致。

**影响：** 终端读取边界会改变快捷键含义，Alt 组合可变成普通文本输入。

**建议：** 仅在完整 Alt 帧可提交时消费 ESC，或保存显式 Alt 解码状态；测试 UTF-8 的所有切点。

**兼容性：** 保持 KeyEvent 形状，修正增量解析语义。

证据：[logs/run-render-probe-alt.log](evidence/logs/run-render-probe-alt.log)、[logs/run-render-probe-splits.log](evidence/logs/run-render-probe-splits.log)。

原始条目：`IN-01`。

## CJTUI-015

**P2 · 已复现 · Kitty 键盘协议的冒号子字段被拼成整数**

位置：[packages/core/src/event.cj:581](../../../packages/core/src/event.cj#L581)、[packages/core/src/event.cj:640](../../../packages/core/src/event.cj#L640)、[packages/core/src/text.cj:818](../../../packages/core/src/text.cj#L818)、[packages/core/src/lib_test.cj:875](../../../packages/core/src/lib_test.cj#L875)。

**原因：** 解析器把修饰键与事件类型的冒号子字段拼成一个十进制整数，第三主字段也没有按文本字段处理。

**观察：** 97;5:2u 与 97;5:3u 都变成 KeyDown 且修饰位错误；97;2;65u 的 text 为 a 而非 A。

**影响：** 启用增强键盘后，repeat/release 可再次执行编辑或命令，修饰位和文本也不正确。

**建议：** 按 Kitty 字段语法分别解析主字段与冒号子字段，增加官方 down/repeat/up 和文本字段用例。

**兼容性：** 默认 Basic 模式不受影响；Kitty 模式行为将与协议一致。

证据：[logs/run-render-probe-kitty.log](evidence/logs/run-render-probe-kitty.log)。

原始条目：`IN-02`。

## CJTUI-016

**P2 · 已复现 · Canvas 左侧裁剪可写入孤立宽字符 continuation**

位置：[packages/core/src/buffer.cj:343](../../../packages/core/src/buffer.cj#L343)、[packages/core/src/buffer.cj:477](../../../packages/core/src/buffer.cj#L477)、[packages/core/src/canvas.cj:154](../../../packages/core/src/canvas.cj#L154)。

**原因：** 宽字符写入时 lead 位于物理 Buffer 左界外而被忽略，continuation 仍落入 cell0，没有以字形为单位裁剪。

**观察：** 负起点绘制 界a 后 cell0 成为空 symbol 的 WideCont，cell1 为 a。

**影响：** Buffer 出现孤立宽格状态并干扰后续 diff 与光标推进。

**建议：** 宽字以 lead+continuation 原子写入；任一格越过物理边界时应用明确的整字裁剪策略。

**兼容性：** Canvas API 不变；需固定部分可见宽字的结果语义。

证据：[logs/run-render-probe-negative-wide.log](evidence/logs/run-render-probe-negative-wide.log)。

原始条目：`IN-04`。

## CJTUI-017

**P3 · 改进建议 · Buffer.resize 与 blitFrom 未定义宽字符对被切开时的约束**

位置：[packages/core/src/buffer.cj:388](../../../packages/core/src/buffer.cj#L388)、[packages/core/src/buffer.cj:413](../../../packages/core/src/buffer.cj#L413)。

**原因：** 两条复制路径按单格原样复制，没有修复被边界切断的 lead/continuation；公开契约尚未说明复制原始格还是保持完整字形。

**观察：** 探针可构造 resize 后的孤立 lead/cont，以及 blit 后 lead 邻接普通字符；现有契约不足以判定唯一正确的边缘表示。

**影响：** 调用滚动、缓存复制或 resize 的自定义渲染器可能得到后端难以解释的宽格状态。

**建议：** 先在 Buffer 契约中规定边界策略，再让 resize/blitFrom 共同维持该不变量并加入 CellKind 断言。

**兼容性：** 可能改变依赖原始格复制的调用，适合先文档化后修正。

证据：[logs/run-render-probe-wide-copies.log](evidence/logs/run-render-probe-wide-copies.log)。

原始条目：`IN-05`, `IN-06`。

## CJTUI-018

**P3 · 已复现 · cut 在宽度预算 1 或 2 时仍返回三列省略号**

位置：[packages/core/src/text.cj:112](../../../packages/core/src/text.cj#L112)。

**原因：** 省略分支固定返回 "..."，没有先判断预算是否能容纳三列。

**观察：** budget=1 和 2 的结果宽度均为 3；budget=0、3、4 的对照符合预算。

**影响：** 窄状态栏、标签或列标题会突破调用方布局宽度。

**建议：** 对 0、1、2 分别返回可容纳结果，并始终断言 displayWidth(result)<=budget。

**兼容性：** 只改变极窄结果文本，不改函数签名。

证据：[logs/run-render-probe-cut.log](evidence/logs/run-render-probe-cut.log)。

原始条目：`IN-08`。

## CJTUI-019

**P2 · 已复现 · TextArea 多选区替换后 caret 停在插入文本之前**

位置：[packages/core/src/text_area.cj:885](../../../packages/core/src/text_area.cj#L885)、[packages/core/src/text_area.cj:972](../../../packages/core/src/text_area.cj#L972)。

**原因：** 批量替换正确写入文本后，caret 使用旧起点而非每个插入文本的新末端重建。

**观察：** 替换后文本为 x/x，但 carets 为 0,2；继续输入 y 得到 yx/yx，而非 xy/xy。

**影响：** 下一次输入被插到替换文本之前。

**建议：** 逆序应用 edit，并从每个 edit 的实际新末端重建 caret。

**兼容性：** 公开多光标 API 不变，修正编辑结果与 caret 位置。

证据：[logs/run-render-probe-multi-replace.log](evidence/logs/run-render-probe-multi-replace.log)。

原始条目：`IN-09`。

## CJTUI-020

**P2 · 已复现 · TextArea 主选区、selectedTexts 与绘制高亮读取不同状态**

位置：[packages/core/src/text_area.cj:440](../../../packages/core/src/text_area.cj#L440)、[packages/core/src/text_area.cj:500](../../../packages/core/src/text_area.cj#L500)、[packages/core/src/text_area.cj:839](../../../packages/core/src/text_area.cj#L839)、[packages/core/src/text_area.cj:1256](../../../packages/core/src/text_area.cj#L1256)。

**原因：** select 更新的主选区与批量选择集合分离，查询和渲染分别读取不同字段。

**观察：** selectedText 返回 cd，selectedTexts 返回 ab，画面高亮 x=0,1 而非 x=2,3。

**影响：** 复制、批量替换与用户看到的选择范围互相矛盾。

**建议：** 建立单一 canonical selection 集合，主选区只是其中一项；所有查询、编辑和渲染从同一快照派生。

**兼容性：** 可能纠正 selectedTexts 的既有错误结果；签名不需改变。

证据：[logs/run-render-probe-selection.log](evidence/logs/run-render-probe-selection.log)。

原始条目：`IN-11`。

## CJTUI-021

**P2 · 已复现 · TextArea 文本变更未统一推进 revision，Composer 因此复用旧布局**

位置：[packages/core/src/text_area.cj:170](../../../packages/core/src/text_area.cj#L170)、[packages/core/src/text_area.cj:649](../../../packages/core/src/text_area.cj#L649)、[packages/core/src/text_area.cj:798](../../../packages/core/src/text_area.cj#L798)、[packages/core/src/text_area.cj:1033](../../../packages/core/src/text_area.cj#L1033)、[packages/core/src/text_area.cj:1165](../../../packages/core/src/text_area.cj#L1165)、[packages/core/src/text_area.cj:1343](../../../packages/core/src/text_area.cj#L1343)、[packages/core/src/content_widgets.cj:298](../../../packages/core/src/content_widgets.cj#L298)、[packages/core/src/content_widgets.cj:496](../../../packages/core/src/content_widgets.cj#L496)、[packages/core/src/content_widgets.cj:549](../../../packages/core/src/content_widgets.cj#L549)。

**原因：** 公开 value 同长赋值、undo/redo 和退出空 Markdown 列表等路径绕过共同 markEdited；Composer 缓存只依赖 editRevision 和宽度。

**观察：** abc 改成 axc 后旧 TextArea 仍显示 abc 且 revision=0；undo 后 revision 不变、旧补全可接受；Composer mutation 与 fresh 对照不同。

**影响：** 模型值已改变但编辑器继续显示旧文本，旧异步补全还能覆盖撤销后的状态。

**建议：** 所有文本语义变更只经统一 mutation helper，原子推进 revision、失效行缓存并通知 Composer；异步结果绑定 revision/代次。

**兼容性：** revision 会在更多正确路径递增；依赖其不变的缓存和测试需更新。

**证据限制：** 公开 value、undo、空 Markdown 列表和 Composer 传播已覆盖；redo 路径没有单独运行。

证据：[logs/run-render-probe-value-cache.log](evidence/logs/run-render-probe-value-cache.log)、[logs/run-render-probe-history.log](evidence/logs/run-render-probe-history.log)、[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`IN-12`, `IN-14`, `WD-11`。

## CJTUI-022

**P2 · 已复现 · TextArea 首次渲染后更新 foldState 不重建可见行**

位置：[packages/core/src/text_area.cj:1088](../../../packages/core/src/text_area.cj#L1088)、[packages/core/src/text_area.cj:1102](../../../packages/core/src/text_area.cj#L1102)。

**原因：** 行缓存身份只含文本 revision 和宽度，不含 foldState 的版本；折叠标记读新状态而正文行表仍来自旧缓存。

**观察：** 同一对象切换折叠后 actual-row1 仍为 two，fresh 对照为 three，equal=false。

**影响：** 折叠/展开后正文、caret 和鼠标的视觉行映射保持旧状态。

**建议：** 为 FoldState 提供 revision 并纳入 TextArea 行缓存身份，或在 fold 变更时显式失效。

**兼容性：** 内部缓存修复；可新增 FoldState revision 而保留现有调用。

证据：[logs/run-render-probe-fold-cache.log](evidence/logs/run-render-probe-fold-cache.log)。

原始条目：`IN-13`。

## CJTUI-023

**P2 · 已复现 · TextArea readOnly 可被 undo/redo 与补全确认绕过**

位置：[packages/core/src/text_area.cj:239](../../../packages/core/src/text_area.cj#L239)、[packages/core/src/text_area.cj:265](../../../packages/core/src/text_area.cj#L265)、[packages/core/src/text_area.cj:1196](../../../packages/core/src/text_area.cj#L1196)。

**原因：** readOnly guard 只包围常规输入路径，历史恢复和 completion accept 在 guard 外直接改 value。

**观察：** readOnly 下 Ctrl-Z 把 ab 改为 a，补全 Enter 把 pri 改为 COMPLETED。

**影响：** 只读预览或临时锁定仍会响应键盘修改，宿主不能依赖该属性保护当前内容。

**建议：** 所有改变文本的命令在统一 mutation 边界检查 readOnly；允许选择、滚动等非修改操作继续执行。

**兼容性：** 会让此前 handled=true 的修改命令拒绝变更；属性语义更一致。

**证据限制：** Ctrl-Z 和补全确认已复现；Ctrl-Y 没有单独运行。

证据：[logs/run-render-probe-readonly.log](evidence/logs/run-render-probe-readonly.log)。

原始条目：`IN-15`。

## CJTUI-024

**P2 · 已复现 · TextArea.handleWithDirty 未包含光标移动引起的新视口**

位置：[packages/core/src/text_area.cj:336](../../../packages/core/src/text_area.cj#L336)、[packages/core/src/text_area.cj:393](../../../packages/core/src/text_area.cj#L393)、[packages/core/src/text_area.cj:409](../../../packages/core/src/text_area.cj#L409)。

**原因：** dirty 预测只标记旧行，没有先计算 ensure-visible 导致的 scroll 变化，也没有覆盖新旧 viewport 的差集。

**观察：** 光标移动后 scroll 仍由后续 render 调整；按返回 dirty 局部绘制得到 0/2，完整绘制为 1/2，equal=false。

**影响：** 局部渲染混合两帧内容，文本行与光标错位。

**建议：** handle 阶段先决定新 scroll，并把新旧 viewport 全部变化加入 dirty；以 partial 与 fresh full 等价作为回归标准。

**兼容性：** DirtyRects 可能变大，但公开编辑行为不变。

证据：[logs/run-render-probe-dirty-scroll.log](evidence/logs/run-render-probe-dirty-scroll.log)。

原始条目：`IN-16`。

## CJTUI-025

**P2 · 已复现 · 短文档提前返回导致已打开的补全菜单不可见**

位置：[packages/core/src/text_area.cj:394](../../../packages/core/src/text_area.cj#L394)。

**原因：** TextArea render 在正文行不足时提前 return，补全菜单绘制位于该返回之后。

**观察：** completionVisible=true，集成渲染第二行为空；直接 overlay 对照显示 > COMPLETED。

**影响：** 最常见的短输入看不到候选，但 Enter 仍可确认隐藏选项。

**建议：** 正文绘制结束后始终进入 overlay 阶段；把空文档、单行文档和滚动文档共用同一收尾路径。

**兼容性：** 仅补齐可见菜单，不改补全 API。

证据：[logs/run-render-probe-popup.log](evidence/logs/run-render-probe-popup.log)。

原始条目：`IN-17`。

## CJTUI-026

**P3 · 改进建议 · cursorPositions 会把 scroll 留在最后一个额外 caret 的视口**

位置：[packages/core/src/text_area.cj:409](../../../packages/core/src/text_area.cj#L409)。

**原因：** 查询每个 caret 坐标时复用并修改 TextArea.scroll，最后只恢复主 cursor，不恢复统一视口；公开契约尚未说明返回坐标必须共享哪一个 viewport。

**观察：** 查询前 scroll=0，查询后 scroll=2；主 cursor offset 仍为 0，两个 position 分别按不同 viewport 计算。

**影响：** 宿主读取多光标坐标后可能出现跳滚，后续命中测试也可能使用不一致坐标。

**建议：** 先明确坐标集合的 viewport 契约；查询应无副作用，并对所有 caret 使用同一冻结 scroll。

**兼容性：** 若现有调用依赖查询带动滚动，行为会改变，宜先文档化。

证据：[logs/run-render-probe-cursor-viewport.log](evidence/logs/run-render-probe-cursor-viewport.log)。

原始条目：`IN-18`。

## CJTUI-027

**P3 · 已复现 · TaskPad 的全局单字符快捷键优先于 New task 输入**

位置：[examples/taskpad/src/main.cj:25](../../../examples/taskpad/src/main.cj#L25)、[examples/taskpad/src/main.cj:48](../../../examples/taskpad/src/main.cj#L48)。

**原因：** 空格、c、q 等全局快捷键在 New task 输入状态之前处理。

**观察：** 输入 a 后空格切换任务状态且文本仍为 a；c 打开命令菜单；新实例输入 q 直接 Exit，输入为空。

**影响：** 示例的新增任务流程不能逐键输入包含这些常见字符的文本。

**建议：** 输入状态先接收字符，未消费事件再交给全局快捷键；若保留单键设计，应在界面清楚呈现限制。

**兼容性：** 局限示例；已公开的全局单键设计需要决定保留快捷键还是让输入模式优先。

证据：[logs/run-render-taskpad_probe-all.log](evidence/logs/run-render-taskpad_probe-all.log)。

原始条目：`IN-19`。

## CJTUI-028

**P2 · 已复现 · EventParser 对 CSI 数值与 Unicode scalar 缺少边界校验**

位置：[packages/core/src/event.cj:581](../../../packages/core/src/event.cj#L581)、[packages/core/src/event.cj:640](../../../packages/core/src/event.cj#L640)、[packages/core/src/event.cj:843](../../../packages/core/src/event.cj#L843)、[packages/core/src/text.cj:818](../../../packages/core/src/text.cj#L818)。

**原因：** CSI 数字累加没有溢出检查，解析后又直接用任意数值构造 Rune。

**观察：** 超长数字触发 mul 异常，1114112 与 55296 构造 Rune 时异常，没有返回可恢复 Unknown。

**影响：** 终端产生的异常 CSI 帧会中断 App 事件处理。

**建议：** 对数字使用有界累加，对 scalar 做合法范围检查，失败时返回可恢复 Unknown。

**兼容性：** 有效输入不变；无效输入从抛异常改为可恢复事件。

证据：[logs/run-render-probe-invalid.log](evidence/logs/run-render-probe-invalid.log)。

原始条目：`IN-22`。

## CJTUI-029

**P2 · 已复现 · DocumentView 布局缓存不观察折叠和当前源位置变化**

位置：[packages/core/src/document.cj:227](../../../packages/core/src/document.cj#L227)、[packages/core/src/document.cj:440](../../../packages/core/src/document.cj#L440)、[packages/core/src/document.cj:478](../../../packages/core/src/document.cj#L478)、[packages/core/src/document.cj:541](../../../packages/core/src/document.cj#L541)。

**原因：** cacheLayout 命中只比较 width，cachedRows 已固化 foldState 和 cursorSourceOffset 的结果。

**观察：** setFolded 后旧实例与 fresh 对照相差 10 格，正文仍是 folded 而非 tail；只改 cursorSourceOffset 也相差 8 格。

**影响：** 折叠内容、展开内容和当前源高亮停留在旧帧，源位置映射也随之过期。

**建议：** 把折叠 revision 纳入缓存身份，并把不影响断行的当前高亮移到绘制阶段或单独失效。

**兼容性：** 构造器与默认 cacheLayout=false 可保留；只修正启用缓存时的状态响应。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-01`。

## CJTUI-030

**P2 · 已复现 · VirtualTranscriptView.setCardTheme 不失效已测量几何**

位置：[packages/core/src/virtual_transcript.cj:515](../../../packages/core/src/virtual_transcript.cj#L515)、[packages/core/src/virtual_transcript.cj:1042](../../../packages/core/src/virtual_transcript.cj#L1042)、[packages/core/src/virtual_transcript.cj:1067](../../../packages/core/src/virtual_transcript.cj#L1067)。

**原因：** setter 只替换 cardTheme，缓存身份不含主题；fullFrame、padding 和 height 继续沿用旧测量。

**观察：** 切换主题后旧实例与 fresh 对照相差 79 格，旧条目 4 行而新主题应为 6 行。

**影响：** 运行时换主题后边框、内边距、卡片高度和滚动索引不一致。

**建议：** 主题几何变化提高 layout generation，失效所有受影响条目并重建高度索引。

**兼容性：** 主题 setter 入口不变；切换成本会正确体现为一次重测量。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-02`。

## CJTUI-031

**P2 · 已复现 · List、Table 和 VirtualTable 未限制在传入 area 内**

位置：[packages/core/src/widgets.cj:319](../../../packages/core/src/widgets.cj#L319)、[packages/core/src/widgets.cj:459](../../../packages/core/src/widgets.cj#L459)、[packages/core/src/widgets.cj:500](../../../packages/core/src/widgets.cj#L500)、[packages/core/src/data_widgets.cj:365](../../../packages/core/src/data_widgets.cj#L365)。

**原因：** List 不按 target.width 截断，Table 缺空区域 guard，VirtualTable 的停止条件使用 Buffer.right 而非 target.right。

**观察：** VirtualTable/List/Table 分别在区域外改写 10/10/8 格，height=0 的 Table 仍改写 4 格。

**影响：** 窄布局或零尺寸表格会覆盖相邻面板与边框。

**建议：** 入口先处理空 area，并对每个文本 span 与 target 求交；VirtualTable 停止条件使用 target.right。

**兼容性：** 只移除区域外写入；区域内显示保持。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-03`。

## CJTUI-032

**P2 · 已复现 · DocumentView.handleMouse 使用外框坐标且接受区域外点击**

位置：[packages/core/src/document.cj:414](../../../packages/core/src/document.cj#L414)。

**原因：** 鼠标映射直接用 mouse.y-area.y 和 area.width，没有换算正文 inner area，也没有先检查 x/y 是否在区域内。

**观察：** 正文首行点击期望 source offset 0，实际得到 10；区域外点击期望 None，实际仍为 Some(10)。

**影响：** 点击导航偏行，其他面板的点击也可能触发错误文档定位。

**建议：** 复用 render 的正文 area 计算，区域外立即返回 None，并以相同可见行表做源位置映射。

**兼容性：** 此前区域外返回值会改为 None，符合常规 hit-test 语义。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-05`。

## CJTUI-033

**P2 · 已复现 · VirtualTable 的外部滚动与选择绑定存在双重状态真相**

位置：[packages/core/src/data_widgets.cj:138](../../../packages/core/src/data_widgets.cj#L138)、[packages/core/src/data_widgets.cj:157](../../../packages/core/src/data_widgets.cj#L157)、[packages/core/src/data_widgets.cj:174](../../../packages/core/src/data_widgets.cj#L174)、[packages/core/src/data_widgets.cj:315](../../../packages/core/src/data_widgets.cj#L315)、[packages/core/src/data_widgets.cj:541](../../../packages/core/src/data_widgets.cj#L541)、[packages/core/src/data_widgets.cj:558](../../../packages/core/src/data_widgets.cj#L558)。

**原因：** 键盘滚动只改内部 offset，下一帧又从未更新的 ScrollState 覆盖；选择操作只改 SelectionModel，而查询方法只读本地 selectedRows。

**观察：** PageDown 后期望 offset=97，render 后回到 0；model 显示 row0 已选中，但 isSelected=false 且 selectedRowIndices 为空。

**影响：** 选中项可停在屏外，界面高亮与应用导出的选择集合互相矛盾。

**建议：** 绑定外部 state 时将其设为唯一真相，handle 和查询都读写同一对象；未绑定时才使用内部状态。

**兼容性：** 外部 state 会开始随交互更新；需要明确双向绑定契约。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-06`, `WD-18`。

## CJTUI-034

**P1 · 已复现 · ConfirmDialog 显示默认 No，Enter 却返回 true**

位置：[packages/core/src/command_widgets.cj:362](../../../packages/core/src/command_widgets.cj#L362)。

**原因：** 初始 selected=0 渲染为 No，但 Enter 分支无条件把 confirmed 设为 true。

**观察：** 初始按钮行为 [No] [Yes] 且 confirmed=false；按 Enter 返回 Some(true)。

**影响：** 应用按用户看到的默认拒绝呈现，却执行确认分支。

**建议：** Enter 按当前 selected 返回 false/true；增加初始状态、左右切换与 Enter 的组合断言。

**兼容性：** 修正现有错误结果；依赖默认 Enter=true 的调用应改为显式选择 Yes。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-07`。

## CJTUI-035

**P2 · 已复现 · FilePicker 从绝对一级目录返回父目录时跳到当前目录**

位置：[packages/core/src/data_widgets.cj:889](../../../packages/core/src/data_widgets.cj#L889)、[packages/core/src/data_widgets.cj:963](../../../packages/core/src/data_widgets.cj#L963)。

**原因：** parentPath 的反向循环条件 i>0 永远不处理索引 0 的根斜线，最终回退到 "."。

**观察：** 一级绝对目录的 parent 期望 /，实际为 .。

**影响：** 向上导航跳到启动目录，后续路径选择落在错误位置。

**建议：** 使用平台路径 API或显式处理 root、一级目录和尾斜线，并补绝对/相对路径表。

**兼容性：** 只修正根边界；Windows 路径需另按平台验证。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-08`。

## CJTUI-036

**P2 · 已复现 · 带框 Input 返回的 dirty 行不是实际文本行**

位置：[packages/core/src/widgets.cj:681](../../../packages/core/src/widgets.cj#L681)。

**原因：** handleWithDirty 固定标记 area.y 高度 1，render 却把正文画在 inner.y，通常为 area.y+1。

**观察：** 输入改变后返回区域不覆盖真实内容格，expected_content_covered=true、actual=false。

**影响：** 按 DirtyRects 局部重绘的应用看不到新输入，直到其他事件触发全绘。

**建议：** dirty 计算复用 render 的 inner area；边框/标题变化与内容变化分别标记。

**兼容性：** DirtyRects 坐标修正，控件 API 不变。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-09`。

## CJTUI-037

**P2 · 已复现 · Document 富文本换行按 Rune 拆分并破坏字素**

位置：[packages/core/src/document.cj:650](../../../packages/core/src/document.cj#L650)、[packages/core/src/document.cj:813](../../../packages/core/src/document.cj#L813)、[packages/core/src/document.cj:837](../../../packages/core/src/document.cj#L837)。

**原因：** 每个 Rune 被单独变成 RichSpan，换行和右边界判断也按 Rune 执行，没有保持组合字符和 ZWJ 序列。

**观察：** A+组合重音的旧实例首格只显示 A；👩‍💻 被拆为 👩，与按完整字素的 fresh 对照分别相差 1 和 5 格。

**影响：** 文档正文丢重音、拆开表情并产生错误换行和源位置映射。

**建议：** 按 grapheme cluster 迭代和测宽，span 切分保留源字节范围到完整字素的映射。

**兼容性：** Unicode 文档的换行与位置会纠正；ASCII 不受影响。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-10`。

## CJTUI-038

**P2 · 已复现 · 空 MultiSelect 可以选中不存在的索引 0**

位置：[packages/core/src/form_widgets.cj:343](../../../packages/core/src/form_widgets.cj#L343)。

**原因：** 构造器把空集合 cursor 夹到 0，toggle 未检查 items.size 就把 cursor 加入选择集。

**观察：** 空 items 切换后 expected_selected=0，actual_selected=1。

**影响：** 调用方按返回索引访问数据会越界，或提交不存在的选项。

**建议：** 空集合使用无 cursor 状态，所有 toggle/query 在索引有效后才操作。

**兼容性：** 空集合的错误 [0] 结果会改为空；非空行为不变。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-12`。

## CJTUI-039

**P2 · 已复现 · DatePicker 可通过正常按键产生不存在的日期**

位置：[packages/core/src/form_widgets.cj:386](../../../packages/core/src/form_widgets.cj#L386)。

**原因：** day 只夹在 1..31，月份或年份变化后没有按当月天数重新约束。

**观察：** 从有效日期通过控件按键得到 2026-02-31。

**影响：** 表单显示并提交无效日期，下游解析和业务校验失败。

**建议：** 每次 month/year/day 变化后用闰年规则夹取到当月最大日，或用合法 Date 值做内部状态。

**兼容性：** 此前可见的无效日期会被夹取；需明确月底切月策略。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-13`。

## CJTUI-040

**P2 · 已复现 · VirtualTranscript ASCII 侧栏的测量宽度比绘制宽度多一列**

位置：[packages/core/src/virtual_transcript.cj:815](../../../packages/core/src/virtual_transcript.cj#L815)、[packages/core/src/virtual_transcript.cj:846](../../../packages/core/src/virtual_transcript.cj#L846)、[packages/core/src/virtual_transcript.cj:1078](../../../packages/core/src/virtual_transcript.cj#L1078)。

**原因：** materialize 对非 fullFrame chrome 只减 2 列，paint 实际以 x+3、width-3 绘制。

**观察：** 布局向正文请求 width=8，但画面实际只有 7 列，正文行末字符被裁。

**影响：** 无 Unicode 能力终端的卡片正文稳定丢失每行末字，并污染高度测量。

**建议：** 让测量和绘制共享同一 chrome geometry 计算，并对 ASCII/Unicode/fullFrame 建参数表。

**兼容性：** ASCII 布局可能增加换行和高度，属于正确测量结果。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-14`。

## CJTUI-041

**P3 · 已复现 · BlockOptions.border 接受自定义边框但 Block 从不读取**

位置：[packages/core/src/widgets.cj:63](../../../packages/core/src/widgets.cj#L63)、[packages/core/src/widgets.cj:194](../../../packages/core/src/widgets.cj#L194)。

**原因：** resolvedBorder 只按 borderKind 选择内置 BorderSet，忽略 options.border。

**观察：** 自定义 horizontal='=' 后期望 =，实际仍为 -。

**影响：** 公开自定义选项无效，应用只能得到内置外观。

**建议：** 定义 border 与 borderKind 的优先级并实际读取自定义值；若不支持则移除或弃用该参数。

**兼容性：** 启用此前被忽略的参数会改变传值调用的外观，需在版本说明中指出。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-16`。

## CJTUI-042

**P2 · 已复现 · TranscriptView 用逻辑项目数代替视觉行高**

位置：[packages/core/src/content_widgets.cj:247](../../../packages/core/src/content_widgets.cj#L247)、[packages/core/src/content_widgets.cj:261](../../../packages/core/src/content_widgets.cj#L261)。

**原因：** 每个卡片按 document.lines.size 分配高度，未使用 DocumentView 换行后的视觉行；ensureVisible 又把 item index 与 viewportHeight 直接相加。

**观察：** 窄宽长段落的第三视觉行为空；选中第二项后 offset 仍为 0，首屏继续显示第一张高卡片。

**影响：** 长消息正文被截断，键盘选中的项目可能不可见。

**建议：** 为每项缓存真实视觉高度和前缀和，滚动与导航都使用屏幕行坐标。

**兼容性：** 窄宽 transcript 的高度和 scroll offset 会改变；API 可保持。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-17`。

## CJTUI-043

**P3 · 已复现 · assistant_console 开启 Paste 模式却丢弃 Paste 事件**

位置：[examples/assistant_console/src/main.cj:20](../../../examples/assistant_console/src/main.cj#L20)、[examples/assistant_console/src/main.cj:58](../../../examples/assistant_console/src/main.cj#L58)。

**原因：** assistant_console 的宿主 update 没有把 Event.Paste 交给 Composer，事件落入默认分支。

**观察：** 关闭请求框后 Paste(pasted)，Composer 文本不含 pasted，actual_inserted=false。

**影响：** 用户按推荐示例学习或使用编辑器时，终端粘贴无响应。

**建议：** 当前编辑控件优先接收 Paste，并以完整文本 API 插入。

**兼容性：** 局限示例路由，不需改 core API。

证据：[logs/run-widgets-probe_assistant_console-all.log](evidence/logs/run-widgets-probe_assistant_console-all.log)。

原始条目：`WD-19`。

## CJTUI-044

**P3 · 已复现 · form_studio 在 Notes 焦点粘贴时覆盖 Name**

位置：[examples/form_studio/src/main.cj:23](../../../examples/form_studio/src/main.cj#L23)、[examples/form_studio/src/main.cj:40](../../../examples/form_studio/src/main.cj#L40)。

**原因：** Paste 分支无条件调用 name.setValue，没有按当前 focus 选择目标控件。

**观察：** focus 为 notes 时粘贴 ZZ，Name 从 Ada 变为 ZZ，Notes 不变。

**影响：** 编辑备注会误写姓名并丢失原值。

**建议：** 按 focus 将 Paste 交给对应控件，未聚焦文本控件时才拒绝。

**兼容性：** 局限示例；修正焦点语义。

证据：[logs/run-widgets-probe_form_studio-all.log](evidence/logs/run-widgets-probe_form_studio-all.log)。

原始条目：`WD-20`。

## CJTUI-045

**P3 · 已复现 · oh_my_pi_skin 未把查询字符和返回动作接入 CommandPalette**

位置：[examples/oh_my_pi_skin/src/main.cj:240](../../../examples/oh_my_pi_skin/src/main.cj#L240)、[examples/oh_my_pi_skin/src/main.cj:298](../../../examples/oh_my_pi_skin/src/main.cj#L298)。

**原因：** paletteOpen 时普通字符没有转交 palette.handle，导航/Enter 的 Some(action) 结果也被丢弃。

**观察：** 输入 z 后 query 仍为空；确认命令后 busy 状态不变且 palette 仍打开。

**影响：** 示例命令面板无法筛选或执行动作。

**建议：** modal 打开时先转交所有相关键，并对返回 action 走统一 dispatch 和关闭逻辑。

**兼容性：** 局限示例；core CommandPalette 无需改型。

证据：[logs/run-widgets-probe_oh_my_pi_skin-all.log](evidence/logs/run-widgets-probe_oh_my_pi_skin-all.log)。

原始条目：`WD-21`。

## CJTUI-046

**P3 · 已复现 · btm_clone 搜索 Backspace 按 UTF-8 字节删除**

位置：[examples/btm_clone/src/main.cj:741](../../../examples/btm_clone/src/main.cj#L741)。

**原因：** 字符追加使用完整 UTF-8 字符串，删除却用 filter.size-1 作为字节切片终点。

**观察：** 多字节搜索词执行 Backspace 时 actual_no_exception=false。

**影响：** 中文或表情搜索无法正常删除，并会中断该示例运行。

**建议：** 使用 grapheme-aware 文本缓冲或至少删除最后一个合法 Rune 边界。

**兼容性：** 局限示例；ASCII 行为保持。

证据：[logs/run-widgets-probe_btm_clone-all.log](evidence/logs/run-widgets-probe_btm_clone-all.log)。

原始条目：`WD-22`。

## CJTUI-047

**P3 · 改进建议 · btm_clone 前台与后台采样共享可变基线**

位置：[examples/btm_clone/src/main.cj:333](../../../examples/btm_clone/src/main.cj#L333)、[examples/btm_clone/src/main.cj:429](../../../examples/btm_clone/src/main.cj#L429)、[examples/btm_clone/src/main.cj:562](../../../examples/btm_clone/src/main.cj#L562)、[examples/btm_clone/src/main.cj:829](../../../examples/btm_clone/src/main.cj#L829)、[examples/btm_clone/src/main.cj:913](../../../examples/btm_clone/src/main.cj#L913)。

**原因：** UI refresh 与 AsyncTask 闭包调用同一个 sampler，sampleProcessesOnly 会改写多组 previous 基线；完成槽锁不覆盖 sampler 本身。

**观察：** 源码和 AsyncTask 调度路径允许两次采样重叠；本轮没有数值异常运行日志。

**影响：** 示例可能混用 CPU/进程采样基线并显示跳变结果。

**建议：** 让单一任务拥有 sampler，或在完整采样事务外加锁并把不可变结果交给 UI。

**兼容性：** 局限实验示例；只改变采样调度。

证据：。

原始条目：`WD-23`。

## CJTUI-048

**P3 · 已复现 · example_smoke 重写事件状态，不能证明真实示例流程**

位置：[packages/example_smoke/src/main.cj:113](../../../packages/example_smoke/src/main.cj#L113)、[packages/example_smoke/src/main.cj:244](../../../packages/example_smoke/src/main.cj#L244)、[examples/assistant_console/src/main.cj:28](../../../examples/assistant_console/src/main.cj#L28)。

**原因：** smoke 用独立硬编码状态代替调用真实示例 update；过滤/分页只改文字，审批 Enter 直接写 accepted。

**观察：** 真实 assistant_console Enter 得到 approval: Cancel，而 smoke 断言 approval: accepted；真实示例路由缺陷仍可被现有 smoke 漏过。

**影响：** 门禁名称暗示覆盖真实示例，实际不能发现其关键交互回归。

**建议：** 把可复用 update 抽成可调用模块，smoke 直接驱动真实状态机；无法共享的用例应明确标为模型级检查。

**兼容性：** 只调整测试结构和声明范围。

**证据限制：** 只运行对比了 AssistantConsole 的初始 Enter；data_browser 等其他 smoke 重写路径来自静态审读。

证据：[logs/run-widgets-probe_assistant_console-all.log](evidence/logs/run-widgets-probe_assistant_console-all.log)。

原始条目：`WD-24`。

## CJTUI-049

**P1 · 已复现 · ANSI 解析遇到裸 ESC 或非 CSI 序列时循环不前进**

位置：[packages/terminal/src/terminal.cj:24](../../../packages/terminal/src/terminal.cj#L24)、[packages/terminal/src/terminal.cj:47](../../../packages/terminal/src/terminal.cj#L47)、[packages/terminal/src/terminal.cj:86](../../../packages/terminal/src/terminal.cj#L86)、[packages/terminal/src/terminal.cj:249](../../../packages/terminal/src/terminal.cj#L249)。

**原因：** parseAnsi 遇到 ESC 但不是可消费的完整 CSI 时，正文扫描立即退出，offset 不变，外层循环继续添加空 token。

**观察：** 裸 ESC 与非 CSI 输入分别在 2.024 秒和 1.627 秒达到 256MiB 限制并被执行器终止。

**影响：** 普通 PTY 片段可让终端视图持续占用 CPU 和内存并停止处理其他事件。

**建议：** 保证每轮消费、缓存待续前缀或返回；未知/截断 ESC 使用有界规则，并保留两种输入的受限回归。

**兼容性：** parseAnsi 单次入口可保留；TerminalScreen.feed 的截断语义会被纠正。

证据：[logs/run-extensions-probe-ansi-bare-esc.log](evidence/logs/run-extensions-probe-ansi-bare-esc.log)、[logs/run-extensions-probe-ansi-non-csi.log](evidence/logs/run-extensions-probe-ansi-non-csi.log)。

原始条目：`EX-01`。

## CJTUI-050

**P2 · 已复现 · Terminal 搜索按任意 UTF-8 字节切片并把字节下标当显示列**

位置：[packages/terminal/src/terminal.cj:281](../../../packages/terminal/src/terminal.cj#L281)、[packages/terminal/src/terminal.cj:355](../../../packages/terminal/src/terminal.cj#L355)。

**原因：** findTerminalText 枚举任意字节区间切 String，匹配结果又直接用字节 offset 作为 screen cell 列。

**观察：** TerminalTranscript.append(中x) 后搜索 x 的 render 抛 Invalid utf8 byte sequence。

**影响：** 中文或 emoji 转录中的搜索会中断渲染，高亮列也可能错位。

**建议：** 只在合法字符边界切片，并维护文本匹配范围到原 screen cell 的显式映射。

**兼容性：** Unicode 截断和高亮位置会纠正；ASCII 结果保持。

**证据限制：** 已复现 UTF-8 切片异常；原报告的具体列值推演已撤回，正确 cell 映射仍需实现后验证。

证据：[logs/run-extensions-probe-ansi-unicode-search.log](evidence/logs/run-extensions-probe-ansi-unicode-search.log)。

原始条目：`EX-03`。

## CJTUI-051

**P2 · 已复现 · TerminalScreen 满行后立即换行，使随后的 LF 再前进一行**

位置：[packages/terminal/src/terminal.cj:127](../../../packages/terminal/src/terminal.cj#L127)。

**原因：** 写入最后一列时马上 newline，没有 pending-wrap 状态；下一字节若是 LF 会再次 newline。

**观察：** 宽度 3 写 abc\nX 后 row0=abc、row1 为空、X 落在 row2。

**影响：** 恰好填满宽度的普通输出出现空行，底部还会过早滚屏丢内容。

**建议：** 实现 pending-wrap：最后一列写入后延迟换行，按下一字符类型决定换行一次。

**兼容性：** 终端输出位置会与常见终端模型一致；快照需更新。

证据：[logs/run-extensions-probe-ansi-wrap-newline.log](evidence/logs/run-extensions-probe-ansi-wrap-newline.log)。

原始条目：`EX-04`。

## CJTUI-052

**P2 · 已复现 · Diff 解析器未按状态区分文件头、hunk 正文和 no-newline 元信息**

位置：[packages/diff/src/diff.cj:99](../../../packages/diff/src/diff.cj#L99)、[packages/diff/src/diff.cj:118](../../../packages/diff/src/diff.cj#L118)。

**原因：** 解析顺序仅凭 startsWith(---/+++/\) 分类，没有把当前是否在 hunk 纳入状态。

**观察：** hunk 内合法 ---/+++ 正文被当文件路径，path 变为 new 且 added/deleted=0；no-newline 标记被算作第四条 hunk 行并推进双侧行号。

**影响：** 合法补丁内容丢失，文件名、统计和后续行号错误。

**建议：** 按 unified diff 状态机分类：仅在文件边界接收文件头，在 hunk 内把符号行视为正文，把 no-newline 作为前一行元信息且不推进行号。

**兼容性：** 公开模型不必改型；解析出的路径、行数和 hunk 内容会纠正。

证据：[logs/run-extensions-probe-diff-hunk-header.log](evidence/logs/run-extensions-probe-diff-hunk-header.log)、[logs/run-extensions-probe-diff-no-newline.log](evidence/logs/run-extensions-probe-diff-no-newline.log)。

原始条目：`EX-05`, `EX-07`。

## CJTUI-053

**P3 · 改进建议 · DiffView 对负选择值缺少明确契约和范围处理**

位置：[packages/diff/src/diff.cj:139](../../../packages/diff/src/diff.cj#L139)、[packages/diff/src/diff.cj:160](../../../packages/diff/src/diff.cj#L160)。

**原因：** render 只对 selectedFile 做上界 min，负值仍可用于数组索引；尚无公开契约说明 -1 是合法的无选择哨兵。

**观察：** selectedFile=-1 时探针抛 IndexOutOfBoundsException；该值是否属于支持输入尚未定义。

**影响：** 外部直接更新公开状态为负值时视图会中断渲染。

**建议：** 明确选择值域；若支持无选择则用 Option 或完整 clamp，若不支持则限制 setter/构造器并给出诊断。

**兼容性：** 契约选择会影响使用 -1 的调用，需先确定再修。

证据：[logs/run-extensions-probe-diff-negative-selection.log](evidence/logs/run-extensions-probe-diff-negative-selection.log)。

原始条目：`EX-08`。

## CJTUI-054

**P1 · 已复现 · Markdown 任务标记解析对空项和紧邻多字节文本越界**

位置：[packages/cj_markdown/src/markdown.cj:495](../../../packages/cj_markdown/src/markdown.cj#L495)、[packages/cj_markdown/src/markdown.cj:1503](../../../packages/cj_markdown/src/markdown.cj#L1503)。

**原因：** taskMarkerAt 只确认三个标记字符，parseListItem 随后无条件 idx+=4，既可能超过结尾，也可能落入 UTF-8 续字节。

**观察：** 空任务项抛 Invalid range，标记后紧接中文抛 Invalid utf8 byte sequence。

**影响：** 用户逐字编辑任务列表的自然中间状态即可中断实时预览。

**建议：** 把可选空格作为实际解析条件，仅按合法字符边界推进；空内容和无空格形式应有限地解析或降级成普通文本。

**兼容性：** 会使此前异常的输入得到 AST 或普通文本；有效任务列表保持。

证据：[logs/run-extensions-probe-markdown-empty-task.log](evidence/logs/run-extensions-probe-markdown-empty-task.log)、[logs/run-extensions-probe-markdown-task-unicode.log](evidence/logs/run-extensions-probe-markdown-task-unicode.log)。

原始条目：`EX-09`。

## CJTUI-055

**P2 · 已复现 · 列表与标题树以首节点层级为根并丢弃后续浅层节点**

位置：[packages/cj_markdown/src/markdown.cj:1191](../../../packages/cj_markdown/src/markdown.cj#L1191)、[packages/markdown/src/markdown.cj:238](../../../packages/markdown/src/markdown.cj#L238)。

**原因：** 根调用把首节点层级当基准，遇到更浅节点即 break；返回的 next 索引没有被根层继续消费。

**观察：** 先深后浅的 outlineNodes=1，outdent 列表的 listItems=1，后续合法节点均消失。

**影响：** 有效文档的列表正文或导航目录静默缺项。

**建议：** 增加虚拟根层并循环消费全部顶层片段；递归只负责自身子树，调用者必须继续处理 next。

**兼容性：** AST 会补回此前丢失的节点；公开类型不需改变。

证据：[logs/run-extensions-probe-markdown-outline-backout.log](evidence/logs/run-extensions-probe-markdown-outline-backout.log)、[logs/run-extensions-probe-markdown-list-backout.log](evidence/logs/run-extensions-probe-markdown-list-backout.log)。

原始条目：`EX-10`。

## CJTUI-056

**P2 · 已复现 · 代码围栏内的参考定义污染围栏外链接解析**

位置：[packages/cj_markdown/src/markdown.cj:223](../../../packages/cj_markdown/src/markdown.cj#L223)、[packages/cj_markdown/src/markdown.cj:390](../../../packages/cj_markdown/src/markdown.cj#L390)、[packages/cj_markdown/src/markdown.cj:606](../../../packages/cj_markdown/src/markdown.cj#L606)。

**原因：** collectReferences 在块解析前扫描所有原始行，没有跳过 fenced code 范围。

**观察：** 仅在代码围栏中出现的 [id] 定义让围栏外引用被解析为 links=1。

**影响：** 文档中的示例代码会意外改变正文链接目标。

**建议：** 先完成块级状态解析，再只从可定义 reference 的正文块收集定义。

**兼容性：** 围栏内定义将不再对正文生效，符合围栏隔离语义。

证据：[logs/run-extensions-probe-markdown-fenced-reference.log](evidence/logs/run-extensions-probe-markdown-fenced-reference.log)。

原始条目：`EX-11`。

## CJTUI-057

**P2 · 已复现 · 表格单元格与列表续行的 SourceRange 从错误偏移重建**

位置：[packages/cj_markdown/src/markdown.cj:522](../../../packages/cj_markdown/src/markdown.cj#L522)、[packages/cj_markdown/src/markdown.cj:595](../../../packages/cj_markdown/src/markdown.cj#L595)。

**原因：** 表格所有裁剪单元格复用 baseColumn=0/line.offset；列表续行则用含标记的块起点映射拼接正文。

**观察：** 表格第二单元格 B 的 source offset 实际为 0，期望为原文 byte 6；列表续行同样缺少独立原文偏移。

**影响：** 公开 SourceRange 无法准确支持定位、选择和预览同步。

**建议：** 在分词阶段保留每段原文字节区间，table cell 和每条 continuation 分别携带自己的映射。

**兼容性：** SourceRange 值会纠正，AST 形状可保持。

**证据限制：** 表格第二单元格偏移已运行复现；列表续行映射来自同一 source_id 的静态路径，没有独立运行场景。

证据：[logs/run-extensions-probe-markdown-table-range.log](evidence/logs/run-extensions-probe-markdown-table-range.log)。

原始条目：`EX-12`。

## CJTUI-058

**P2 · 已复现 · 碰撞计算在静止轴上不检查空间分离**

位置：[packages/game/src/game.cj:699](../../../packages/game/src/game.cj#L699)、[examples/crystal_caves/src/main.cj:260](../../../examples/crystal_caves/src/main.cj#L260)。

**原因：** 某轴速度为零时 entry/exit 直接设为正负无穷，没有先验证该轴投影是否重叠。

**观察：** y 轴完全分离的实体仍报告 hits=1，并在 x=4 停下；实际相交的 control 也在 x=4 停下。

**影响：** 不同高度的平台或墙会像真实障碍一样阻挡移动实体。

**建议：** 静止轴若投影不重叠立即判无碰撞；重叠时才用无穷 entry/exit 参与 swept 测试。

**兼容性：** 修正 game 包碰撞结果；属于实验包但会改变错误关卡行为。

证据：[logs/run-extensions-probe-physics-disjoint-axis.log](evidence/logs/run-extensions-probe-physics-disjoint-axis.log)、[logs/run-extensions-probe-physics-control.log](evidence/logs/run-extensions-probe-physics-control.log)。

原始条目：`EX-13`。

## CJTUI-059

**P2 · 已复现 · 移动 Sensor 被 Solid 碰撞响应截停**

位置：[packages/game/src/game.cj:440](../../../packages/game/src/game.cj#L440)、[packages/game/src/game.cj:462](../../../packages/game/src/game.cj#L462)。

**原因：** 碰撞筛选只跳过 otherCollider.kind==Sensor，没有检查运动实体自身是 Sensor，随后仍执行实体阻挡响应。

**观察：** 移动 Sensor 期望无阻挡到 x=10，实际 hits=1 且停在 x=4。

**影响：** 触发区或感应实体移动时被普通实体阻挡，位置与事件语义不一致。

**建议：** 把接触检测与实体阻挡响应分开；任一侧为 Sensor 时可报告 overlap，但不修正位置或清零速度。

**兼容性：** 会改变移动 Sensor 的既有错误轨迹；Solid/Solid 对照保持。

证据：[logs/run-extensions-probe-physics-moving-sensor.log](evidence/logs/run-extensions-probe-physics-moving-sensor.log)、[logs/run-extensions-probe-physics-control.log](evidence/logs/run-extensions-probe-physics-control.log)。

原始条目：`EX-14`。

## CJTUI-060

**P3 · 改进建议 · 媒体预解码和示例同步加载缺少显式预算与取消**

位置：[packages/media/src/media.cj:252](../../../packages/media/src/media.cj#L252)、[packages/media/src/media.cj:356](../../../packages/media/src/media.cj#L356)、[packages/media/src/media.cj:411](../../../packages/media/src/media.cj#L411)、[examples/gif_ascii/src/main.cj:30](../../../examples/gif_ascii/src/main.cj#L30)、[examples/gif_ascii/src/main.cj:73](../../../examples/gif_ascii/src/main.cj#L73)。

**原因：** runTool 同步收集完整输出，ASCII 解码不限制帧数或时长，示例在事件线程等待全部结果；API 未承诺恒定内存或流式处理。

**观察：** 有限假工具一次产生 4096 帧并被全部接收；延迟 2 秒的工具让调用同步等待后才返回。未观察无限等待或内存耗尽。

**影响：** 长素材会提高内存占用并延迟普通按键处理，但本轮没有确认具体上限。

**建议：** 提供帧数/时长/输出字节预算和取消入口，示例把加载放入异步任务并增量发布。

**兼容性：** 属于增强建议；默认预算取值需要避免截断现有正常素材。

证据：[logs/run-extensions-probe-media-fake-frames.log](evidence/logs/run-extensions-probe-media-fake-frames.log)、[logs/run-extensions-probe-media-fake-slow.log](evidence/logs/run-extensions-probe-media-fake-slow.log)。

原始条目：`EX-15`。

## CJTUI-061

**P2 · 已复现 · ExternalMediaAdapter 忽略公开 frameIndex**

位置：[packages/media/src/media.cj:13](../../../packages/media/src/media.cj#L13)、[packages/media/src/media.cj:52](../../../packages/media/src/media.cj#L52)、[packages/media/src/media.cj:99](../../../packages/media/src/media.cj#L99)。

**原因：** 两个 ffmpeg 命令都固定 -frames:v 1，没有 seek/select，decode 也从未读取请求中的 frameIndex。

**观察：** frameIndex 不同的 first/later 请求生成完全相同命令，均提取第一帧。

**影响：** 逐帧显示反复绘制首帧，同时 core 因 frameIndex 变化做无效重绘。

**建议：** 把 frameIndex 转换成明确的帧选择表达式或 seek，并验证 0 与非 0 帧返回不同内容。

**兼容性：** 非零 frameIndex 结果会纠正；请求类型不变。

**证据限制：** 只比较了公开 commandFor(frameIndex=0/7) 的命令选择；没有用真实多帧媒体比较返回像素。

证据：[logs/run-extensions-probe-media-frame-index.log](evidence/logs/run-extensions-probe-media-frame-index.log)。

原始条目：`EX-16`。

## CJTUI-062

**P2 · 已复现 · Kitty 媒体帧只检查非空输出，不验证 RGBA 长度**

位置：[packages/media/src/media.cj:82](../../../packages/media/src/media.cj#L82)、[packages/media/src/media.cj:356](../../../packages/media/src/media.cj#L356)、[packages/media/src/media_test.cj:17](../../../packages/media/src/media_test.cj#L17)。

**原因：** 外部工具只要成功且 stdout 非空就被 base64 封装，没有校验 bytes==width*height*4。

**观察：** 声明 8x16 的请求只返回 1 字节，adapter 仍生成 base64Bytes=4 的像素载荷，探针判定未拒绝。

**影响：** 异常工具输出会被误报成功并产生与声明尺寸不一致的终端图像；现有测试也把短文本当正常帧。

**建议：** 严格校验尺寸乘法和 RGBA 字节数，失败时走 adapter 降级；测试使用精确长度 fixture。

**兼容性：** 此前接受的无效输出会改为失败/降级；有效帧不变。

证据：[logs/run-extensions-probe-media-fake-short-rgba.log](evidence/logs/run-extensions-probe-media-fake-short-rgba.log)。

原始条目：`EX-17`。

## CJTUI-063

**P3 · 静态确认 · Markdown Studio 预览导航没有持久状态也未实际处理事件**

位置：[examples/markdown_studio/src/main.cj:19](../../../examples/markdown_studio/src/main.cj#L19)、[examples/markdown_studio/src/main.cj:53](../../../examples/markdown_studio/src/main.cj#L53)、[examples/markdown_studio/src/main.cj:82](../../../examples/markdown_studio/src/main.cj#L82)。

**原因：** 每帧新建 DocumentView，previewScroll 固定为 0；预览模式的导航事件没有交给 view，也没有保存任何新 scroll。

**观察：** 源码中预览导航分支没有状态更新，render 始终用 previewScroll=0；本轮无独立运行日志。

**影响：** 预览模式看似提供导航键，但内容不会滚动。

**建议：** 让 model 持有 DocumentState/scroll，并把导航事件交给持久 view state 后保存结果。

**兼容性：** 局限示例；core DocumentView 契约不变。

证据：。

原始条目：`EX-19`。

## CJTUI-064

**P2 · 静态确认 · FarmGame 把任意读档失败当作新档并覆盖原路径**

位置：[examples/game_demo/src/main.cj:107](../../../examples/game_demo/src/main.cj#L107)、[examples/game_demo/src/main.cj:433](../../../examples/game_demo/src/main.cj#L433)。

**原因：** 加载失败统一置 saveLoaded=false，构造器随后立即把默认或部分状态保存回同一路径，没有区分文件不存在与已有文件读取失败。

**观察：** 控制流确认所有失败进入自动 save；本轮没有构造可写但不可读文件的运行日志。

**影响：** 已有存档因暂时读取失败或内容错误而被默认状态覆盖。

**建议：** 仅在路径不存在时创建新档；其他读档失败保留原文件、向用户报告并要求显式恢复或另存。

**兼容性：** 失败启动行为会从自动重置改为明确错误；存档格式不需改变。

证据：。

原始条目：`EX-20`。

## CJTUI-065

**P3 · 静态确认 · FarmGame tick 改变动画相位却不标记农场区域**

位置：[examples/game_demo/src/main.cj:168](../../../examples/game_demo/src/main.cj#L168)、[examples/game_demo/src/main.cj:662](../../../examples/game_demo/src/main.cj#L662)、[examples/game_demo/src/main.cj:801](../../../examples/game_demo/src/main.cj#L801)、[examples/game_demo/src/main.cj:822](../../../examples/game_demo/src/main.cj#L822)。

**原因：** tick 只标记 HUD/metrics，水面动画相位变化没有加入 farm dirty 区域。

**观察：** 源码 dirty 集合不包含 farm；本轮无视觉运行日志。

**影响：** 静止时水面动画冻结，直到其他事件触发农场重绘。

**建议：** 动画相位改变时标记实际受影响的 tile/农场区域，保持局部更新。

**兼容性：** 局限示例显示，增加每 tick 的有限 dirty 区域。

证据：。

原始条目：`EX-21`。

## CJTUI-066

**P3 · 静态确认 · FarmGame 存档计数未限制在结算算术可表示范围**

位置：[examples/game_demo/src/main.cj:408](../../../examples/game_demo/src/main.cj#L408)、[examples/game_demo/src/main.cj:484](../../../examples/game_demo/src/main.cj#L484)、[examples/game_demo/src/main.cj:516](../../../examples/game_demo/src/main.cj#L516)、[examples/game_demo/src/main.cj:576](../../../examples/game_demo/src/main.cj#L576)。

**原因：** decodeCounts 只做非负夹取，shippingValue、sleepNight 和 nextGoal 的乘加没有上界或 checked arithmetic。

**观察：** 源码允许 Int64.Max 计数进入后续乘加；本轮未运行 overflow.save，因此不声称具体异常类型。

**影响：** 手工编辑或损坏存档可能让 HUD 或日结计算溢出并中断示例。

**建议：** 加载时按游戏最大规模验证计数，结算使用 checked arithmetic 并报告具体字段。

**兼容性：** 会拒绝此前可解析但不可计算的极值存档。

证据：。

原始条目：`EX-22`。

## CJTUI-067

**P2 · 静态确认 · 示例首跑命令依赖作者机器的绝对路径**

位置：[README.md:61](../../../README.md#L61)、[docs/examples.md:3](../../../docs/examples.md#L3)、[docs/examples.md:59](../../../docs/examples.md#L59)。

**原因：** README 与 examples 文档把 /home/elliot/.codex/scripts/codex_cangjie_env 写成主要入口，该脚本不属于仓库发布内容。

**观察：** 绝对路径脚本不在 tracked 发布树，仓库另有可用的 scripts/cangjie_cmd.sh。

**影响：** 干净 checkout 用户复制示例首跑命令立即失败。

**建议：** 使用仓内 wrapper 或可移植 cjpm 命令，并明确 SDK 前提与工作目录。

**兼容性：** 仅文档修正，不改运行时/API。

证据：。

原始条目：`DOC-01`。

## CJTUI-068

**P2 · 静态确认 · versioning 文档与生成契约对四个公开入口分级相反**

位置：[docs/versioning.md:8](../../../docs/versioning.md#L8)、[docs/versioning.md:27](../../../docs/versioning.md#L27)、[architecture/api-classification.json:78](../../../architecture/api-classification.json#L78)、[docs/stable-api-contract.txt:106](../../../docs/stable-api-contract.txt#L106)。

**原因：** 手写兼容性表没有随 api-classification 和 stable contract 更新。

**观察：** EventScript/EventScenario 文档称 STABLE、生成分类为 TEST_ONLY；Command.Exec/AsyncExec 文档称 EXPERIMENTAL、生成稳定契约却包含它们。

**影响：** 维护者和库用户会依据错误承诺判断兼容性和弃用窗口。

**建议：** 从同一分类源生成或校验 versioning 表，并以当前生成契约为准修正文案。

**兼容性：** 文档校正不改变现有 API，但会澄清既有承诺。

证据：。

原始条目：`DOC-03`。

## CJTUI-069

**P3 · 静态确认 · API Overview 数量仍包含已退役接口**

位置：[docs/api.md:9](../../../docs/api.md#L9)。

**原因：** 手写总数没有在 advanced editor 与 navigation 接口移除后更新。

**观察：** 页面仍写 398 个顶层声明和 138 个 EXPERIMENTAL，计数包含已移除的 15 个入口。

**影响：** 当前 API 规模和治理状态被高估。

**建议：** 从已验证 inventory 自动嵌入计数，或删除易漂移的硬编码数字。

**兼容性：** 仅文档。

证据：。

原始条目：`DOC-04`。

## CJTUI-070

**P2 · 已复现 · summarize-only 用当前构建身份覆盖历史 benchmark provenance**

位置：[scripts/architecture_proof_step0.py:170](../../../scripts/architecture_proof_step0.py#L170)。

**原因：** 脚本在判断 summarize-only 分支前调用 git_identifier 并重写 provenance.json。

**观察：** summarize-only 后 raw 仍为 original-source-and-binary，旁边 provenance 已变为 different-current-source-and-binary。

**影响：** 历史报告会归属到没有产生这些 raw 数据的当前构建。

**建议：** summarize-only 保留原 provenance，校验每条 raw 的 build_identifier，并把当前汇总工具身份另存。

**兼容性：** 证据 schema 可保持；旧产物需要按 raw 身份重新核对。

证据：[docs/probes.json](evidence/docs/probes.json)。

原始条目：`DOC-05`。

## CJTUI-071

**P2 · 已复现 · append benchmark 改写旧末项内容却保持相同 revision**

位置：[benchmarks/architecture-proof-step0/fixture/src/main.cj:16](../../../benchmarks/architecture-proof-step0/fixture/src/main.cj#L16)、[packages/core/src/virtual_transcript.cj:1039](../../../packages/core/src/virtual_transcript.cj#L1039)。

**原因：** fixture 的 count++ 让旧末项从 tail 变成 history 文本，但 itemId 和 revision 仍为 0，违反 VirtualTranscript 缓存身份约定。

**观察：** 静态数据流显示相同 source identity 对应不同 document；本轮没有重跑 benchmark。

**影响：** append 测量使用不一致缓存状态，不能完整证明所报告的布局正确性和工作量。

**建议：** 旧项内容不变时才复用 revision；若内容改变则提高 revision，或调整 fixture 只 append 新项。

**兼容性：** 只修 benchmark fixture，不改库 API。

证据：。

原始条目：`DOC-06`。

## CJTUI-072

**P1 · 静态确认 · 两个 benchmark manifest 未被跟踪，干净 checkout 的正式 gate 必然失败**

位置：[architecture/architecture-fitness.json:26](../../../architecture/architecture-fitness.json#L26)、[scripts/validate_architecture.py:377](../../../scripts/validate_architecture.py#L377)。

**原因：** 全局 *.json ignore 隐藏了两份手写 manifest，仓库 .gitignore 没有窄例外；architecture validator 无条件要求这些 evidence_path 存在。

**观察：** tracked clean archive 的 architecture validator rc=1，且只报告两份 manifest 不存在；仅补入这两份 manifest 后同一 validator rc=0。当前工作树完整 gate rc=0，因为本地忽略文件仍存在。

**影响：** 任何只含 tracked 文件的 checkout 都无法通过正式 release gate，Step0 runner 也无法加载采样配置。

**建议：** 明确加入两份 manifest，并为这两个窄路径添加 ignore 例外；增加 tracked-only 依赖检查。

**兼容性：** 补充发布源文件，不改运行时/API。

证据：[docs/clean_checkout.json](evidence/docs/clean_checkout.json)、[logs/clean-archive-architecture.log](evidence/logs/clean-archive-architecture.log)、[logs/clean-archive-control.log](evidence/logs/clean-archive-control.log)、[supplemental-validation.json](evidence/supplemental-validation.json)、[gate-result.json](evidence/gate-result.json)。

原始条目：`DOC-08`。

## CJTUI-073

**P1 · 已复现 · Windows smoke 前置检查失败会删除已有共享 runner 和 staging**

位置：[scripts/run_windows_smoke.sh:13](../../../scripts/run_windows_smoke.sh#L13)。

**原因：** EXIT trap 在完成前置检查和取得目录所有权前注册，HAD_CUSTOM_RUNNER=0 被误当成本次可删除许可。

**观察：** RUNNER 不存在时命令 rc=127，但预先放置的 runner 和 stage sentinel 均消失。

**影响：** 仅尝试 smoke 就会删除其他工作流放在共享目录中的文件。

**建议：** 前置检查全部成功后再注册 cleanup；每次运行使用唯一 staging，只删除本次确实创建的路径。

**兼容性：** 正常入口和成功行为可保持；失败路径改为保留既有内容。

证据：[tooling/probe-output.json](evidence/tooling/probe-output.json)。

原始条目：`TOOL-01`。

## CJTUI-074

**P2 · 已复现 · API inventory 把块注释中的 public 声明当成真实接口**

位置：[scripts/api_contract.py:375](../../../scripts/api_contract.py#L375)。

**原因：** 词法扫描没有在识别 public 声明前去除或跳过块注释。

**观察：** 正常样本产出 A/A.ok，加入块注释后额外产出不存在的 A.ghost。

**影响：** 文档例子可制造虚假 unclassified、stable dependency 和 contract drift。

**建议：** 使用最小词法状态机跳过行/块注释与字符串，再识别声明；添加嵌套文本和多行注释 fixture。

**兼容性：** 生成 inventory 会移除虚假项；真实 API 不变。

证据：[tooling/probe-output.json](evidence/tooling/probe-output.json)。

原始条目：`TOOL-02`。

## CJTUI-075

**P2 · 已复现 · 动态 latest nightly 与固定日期 SDK gate 不兼容**

位置：[.github/workflows/ci.yml:18](../../../.github/workflows/ci.yml#L18)、[scripts/check_sdk.sh:4](../../../scripts/check_sdk.sh#L4)、[scripts/check_sdk.sh:42](../../../scripts/check_sdk.sh#L42)。

**原因：** workflow 默认解析 latest nightly，check_sdk 却只接受一个固定日期版本。

**观察：** 固定版 mock rc=0，20260908 nightly rc=2；远端 secret 可以显式固定 URL，本轮没有核实真实托管 CI 的当前取值。

**影响：** 使用动态 nightly 分支时会在库测试前被版本 gate 拒绝。

**建议：** 统一选择固定版本或受支持的版本范围，并在 workflow fixture 中覆盖 latest 与显式固定 URL。

**兼容性：** 只改 CI/bootstrap 约定，不改库 API。

**证据限制：** mock 证明两项版本规则互斥；没有读取远端 secret 或真实托管 CI 结果，因此不称当前所有 CI 必然失败。

证据：[tooling/probe-output.json](evidence/tooling/probe-output.json)。

原始条目：`TOOL-03`。

## CJTUI-076

**P2 · 已复现 · macOS smoke 的远端 helper 进入 Linux 专用 SDK 检查**

位置：[scripts/run_macos_smoke.sh:39](../../../scripts/run_macos_smoke.sh#L39)、[scripts/cangjie_cmd.sh:15](../../../scripts/cangjie_cmd.sh#L15)、[scripts/check_sdk.sh:21](../../../scripts/check_sdk.sh#L21)。

**原因：** run_macos_smoke 的远端命令经 cangjie_cmd.sh 复用 check_sdk，后者要求 Linux 布局和组件。

**观察：** 临时 Darwin SDK 布局执行远端 body 时 rc=2，报告 incomplete Cangjie SDK，未进入 macOS smoke。

**影响：** 文档化的 macOS 配置组合无法完成平台验证。

**建议：** 按目标平台选择 SDK 校验规则，macOS helper 验证其真实 cjc/cjpm 和库布局，不复用 Linux 组件清单。

**兼容性：** 只改 smoke 工具路径。

证据：[tooling/probe-env-output.json](evidence/tooling/probe-env-output.json)。

原始条目：`TOOL-05`。

## CJTUI-077

**P3 · 已复现 · event syntax validator 忽略无结尾换行的最后一行**

位置：[scripts/run_event_script.sh:17](../../../scripts/run_event_script.sh#L17)。

**原因：** shell 读取循环只处理 read 成功的行，没有用 `read ... || [ -n "$line" ]` 保留 EOF 前的最后片段。

**观察：** bogus 加换行时 rc=1；相同内容无末尾换行时 rc=0，并报告 0 lines。

**影响：** 用户正在编辑的最后一条非法事件可漏过门禁。

**建议：** 让读取循环处理 EOF 前非空缓冲，并增加有/无末尾换行等价测试。

**兼容性：** 只使此前漏检输入正确失败。

证据：[tooling/probe-output.json](evidence/tooling/probe-output.json)。

原始条目：`TOOL-06`。

## CJTUI-078

**P2 · 已复现 · 相同异步任务 ID 重启后 cancel 命中旧代次**

位置：[packages/core/src/app.cj:516](../../../packages/core/src/app.cj#L516)、[packages/core/src/app.cj:541](../../../packages/core/src/app.cj#L541)。

**原因：** start 只标记旧记录取消后 append 新记录；cancel 从队首按 ID 查找并在旧记录处返回，没有任务代次身份。

**观察：** slot 启动两次后 cancel，日志出现两条 AsyncCancelled，但新任务仍 AsyncCompleted 并交付 new-value。

**影响：** “后一次替换前一次”的搜索、构建或加载仍会交付本应取消的新结果。

**建议：** 为每次 start 分配 generation，替换时移除/封存旧记录，cancel 明确命中当前代次。

**兼容性：** 公开字符串 ID 可保留；同 ID 取消语义需固定为当前代次或全部代次。

证据：[logs/run-runtime-probe-async-reuse.log](evidence/logs/run-runtime-probe-async-reuse.log)。

原始条目：`RT-08`。

## CJTUI-079

**P2 · 已复现 · Kitty 功能键代码映射偏移**

位置：[packages/core/src/event.cj:827](../../../packages/core/src/event.cj#L827)。

**原因：** 增强键盘代码表的功能键常量与协议值不一致。

**观察：** 57376u 输出 F1 而非 F13，57359u 输出 Delete 而非 ScrollLock。

**影响：** 较高功能键不可用，ScrollLock 可触发删除等无关命令。

**建议：** 按 Kitty 官方表重建常量映射，并加入每个边界键的表驱动测试。

**兼容性：** 默认 Basic 不受影响；Kitty 模式键值会纠正。

证据：[logs/run-render-probe-kitty.log](evidence/logs/run-render-probe-kitty.log)。

原始条目：`IN-03`。

## CJTUI-080

**P3 · 已复现 · Canvas.hline/vline 忽略零宽或零高裁剪交集**

位置：[packages/core/src/canvas.cj:105](../../../packages/core/src/canvas.cj#L105)。

**原因：** 线段绘制没有在 clip 交集为空时停止，宽字符 continuation 也未重新检查右边界。

**观察：** clip(0,0,1,1) 下 vline 写到 x=2、hline 写到 y=2，宽字 continuation 写到 clip 右侧。

**影响：** 自定义边框和绘图可覆盖相邻控件的一小段区域。

**建议：** 先计算线段与 clip 的非空交集，逐格写入仍经过 Canvas clip；宽字保持成对边界。

**兼容性：** 只移除 clip 外写入。

证据：[logs/run-render-probe-vertical-clip.log](evidence/logs/run-render-probe-vertical-clip.log)。

原始条目：`IN-07`。

## CJTUI-081

**P2 · 已复现 · 主光标有选区时 Backspace/Delete 跳过额外选区**

位置：[packages/core/src/text_area.cj:288](../../../packages/core/src/text_area.cj#L288)、[packages/core/src/text_area.cj:528](../../../packages/core/src/text_area.cj#L528)、[packages/core/src/text_area.cj:667](../../../packages/core/src/text_area.cj#L667)。

**原因：** 主选区非空时删除路径提前返回，只处理主选区，额外 caret/selection 不进入批量变换。

**观察：** one/two 的两个选区执行 Backspace 或 Delete 都只删除 one，留下 /two，carets 仍为 0,4。

**影响：** 同一删除键只作用于部分选区，并遗留过期 caret。

**建议：** 所有 selection 统一生成删除 edit，去重/排序后一次应用并重建 caret。

**兼容性：** 修正多选删除结果；单选行为保持。

证据：[logs/run-render-probe-multi-delete.log](evidence/logs/run-render-probe-multi-delete.log)。

原始条目：`IN-10`。

## CJTUI-082

**P3 · 已复现 · TaskPad 命令菜单打开后 Esc 无法取消**

位置：[examples/taskpad/src/main.cj:50](../../../examples/taskpad/src/main.cj#L50)、[packages/core/src/command_widgets.cj:164](../../../packages/core/src/command_widgets.cj#L164)。

**原因：** 宿主在 commandMode 分支外吞掉 Esc，没有把它交给 Menu 或关闭当前模式。

**观察：** 通过 c 打开命令菜单后输入 Esc，commandMode 仍为 true。

**影响：** 用户无法取消菜单，只能选择命令或离开流程。

**建议：** modal 打开时由其优先处理 Esc，明确关闭 commandMode。

**兼容性：** 局限示例。

证据：[logs/run-render-taskpad_probe-all.log](evidence/logs/run-render-taskpad_probe-all.log)。

原始条目：`IN-20`。

## CJTUI-083

**P3 · 已复现 · TaskPad 把 Paste 重新解释为按键并写入隐藏输入**

位置：[examples/taskpad/src/main.cj:68](../../../examples/taskpad/src/main.cj#L68)。

**原因：** Paste 文本被逐字符转换回 KeyEvent 并固定发送给 task input，没有按当前 commandMode 选择目标。

**观察：** Paste(a+Backspace+b) 后只剩 b；菜单开启时 Paste(find) 使隐藏 input=find，而 palette.query 为空。

**影响：** 粘贴内容中的控制字符会编辑先前文本，命令面板粘贴进入不可见字段。

**建议：** 将 Paste 作为完整文本交给当前焦点控件，命令菜单打开时交给 palette query。

**兼容性：** 局限示例。

证据：[logs/run-render-taskpad_probe-all.log](evidence/logs/run-render-taskpad_probe-all.log)。

原始条目：`IN-21`。

## CJTUI-084

**P3 · 已复现 · Bracketed Paste 以未校验 UTF-8 构造 String**

位置：[packages/core/src/event.cj:700](../../../packages/core/src/event.cj#L700)、[packages/core/src/text.cj:394](../../../packages/core/src/text.cj#L394)。

**原因：** EventParser 使用 fromUtf8Unchecked 生成 Paste(text)，把字节合法性推迟到后续文本操作。

**观察：** 仅含 0xFF 的 bracketed paste 先生成 Paste，随后 displayWidth 抛 Invalid unicode scalar value。

**影响：** 破损粘贴内容可中断普通文本操作和渲染。

**建议：** 在事件边界严格解码，失败时产生可恢复 Unknown 或明确替代文本。

**兼容性：** 有效 Paste 不变；无效字节不再形成非法 String。

证据：[logs/run-render-probe-invalid.log](evidence/logs/run-render-probe-invalid.log)。

原始条目：`IN-23`。

## CJTUI-085

**P3 · 已复现 · ColorPicker 在只剩一列时仍绘制两个字符**

位置：[packages/core/src/form_widgets.cj:324](../../../packages/core/src/form_widgets.cj#L324)。

**原因：** 循环只检查起点 x<right，随后无条件 setString("##")。

**观察：** width=1 的非零原点区域外实际改变 1 格。

**影响：** 极窄表单中会覆盖相邻控件一列。

**建议：** 根据剩余宽度绘制一格或跳过，并让 setString 受 area 裁剪。

**兼容性：** 只修正极窄外观。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-04`。

## CJTUI-086

**P2 · 已复现 · TimeSeriesChart 对超量程值绘制到图表上边界之外**

位置：[packages/core/src/dashboard_widgets.cj:117](../../../packages/core/src/dashboard_widgets.cj#L117)。

**原因：** 柱高直接按 value*height/maxV 计算，显式 maxValue 不夹取输入值。

**观察：** values=[3]、maxValue=1、area 高 2 时区域外有 2 个 Cell 被改写。

**影响：** 数据超过量程就覆盖上方面板或标题。

**建议：** 在映射到像素前把值夹到显示量程，并处理 maxV<=0。

**兼容性：** 超量程柱会封顶显示；正常范围不变。

证据：[logs/run-widgets-probe-all.log](evidence/logs/run-widgets-probe-all.log)。

原始条目：`WD-15`。

## CJTUI-087

**P3 · 静态确认 · Markdown Studio 开启编辑模式却丢弃 Paste 事件**

位置：[examples/markdown_studio/src/main.cj:28](../../../examples/markdown_studio/src/main.cj#L28)。

**原因：** 示例 update 没有 Event.Paste 分支，事件落入默认处理。

**观察：** 源码分派确认 Paste 不会交给 TextArea；本轮没有该示例的运行记录。

**影响：** Markdown 编辑示例无法使用终端粘贴。

**建议：** 编辑模式把 Paste 完整文本交给 TextArea；普通字符快捷键的优先级另行决定。

**兼容性：** 局限示例。

**证据限制：** 只做源码确认；没有运行 Markdown Studio 交互场景。

证据：。

原始条目：`EX-18`。

## CJTUI-088

**P2 · 已复现 · TerminalScreen.feed 不保留跨 chunk 的未结束 CSI**

位置：[packages/terminal/src/terminal.cj:29](../../../packages/terminal/src/terminal.cj#L29)、[packages/terminal/src/terminal.cj:86](../../../packages/terminal/src/terminal.cj#L86)、[examples/terminal_lab/src/main.cj:32](../../../examples/terminal_lab/src/main.cj#L32)。

**原因：** 每次 feed 都独立调用 parseAnsi，首段只消费 ESC，没有把待续 CSI 前缀留到下一段。

**观察：** ESC 与 [31mX 分两次 feed 后，画面显示字面 [31mX，断言与完整 CSI 不等。

**影响：** PTY 恰好在控制序列内分片时颜色和屏幕状态损坏。

**建议：** TerminalScreen 持有待续 ANSI 状态，只在序列完整时提交 token。

**兼容性：** 完整单次输入不变；跨 chunk 行为纠正。

证据：[logs/run-extensions-probe-ansi-split-csi.log](evidence/logs/run-extensions-probe-ansi-split-csi.log)。

原始条目：`EX-02`。

## CJTUI-089

**P2 · 已复现 · DiffView 用显示宽度作为 UTF-8 字节切片终点**

位置：[packages/diff/src/diff.cj:154](../../../packages/diff/src/diff.cj#L154)、[packages/diff/src/diff.cj:330](../../../packages/diff/src/diff.cj#L330)。

**原因：** truncateDiff 在 displayWidth 超预算后直接执行 text[..width]。

**观察：** 含中文路径的 DiffView 渲染到宽 1 时抛 Invalid utf8 byte sequence。

**影响：** 中文或 emoji 文件名/行内容在窄栏中中断渲染。

**建议：** 按合法 grapheme/Rune 边界累计显示宽度并切片。

**兼容性：** Unicode 截断会纠正；ASCII 保持。

证据：[logs/run-extensions-probe-diff-unicode-clip.log](evidence/logs/run-extensions-probe-diff-unicode-clip.log)。

原始条目：`EX-06`。

## CJTUI-090

**P2 · 静态确认 · 入门和测试文档引用不存在的事件脚本路径**

位置：[docs/getting-started.md:87](../../../docs/getting-started.md#L87)、[docs/testing.md:77](../../../docs/testing.md#L77)。

**原因：** 文档仍使用 tests/events 路径，实际事件文件位于 packages/core/tests/events。

**观察：** tests/events/basic.events 与 scenario.events 不存在，实际文件在 packages/core/tests/events。

**影响：** 用户照文档运行入门验证步骤会立即失败。

**建议：** 更新相对路径，并在文档检查中验证引用文件存在。

**兼容性：** 仅文档。

证据：。

原始条目：`DOC-02`。

## CJTUI-091

**P2 · 静态确认 · Step 0.5 记录哈希的二进制与实际采样 candidate 未绑定**

位置：[scripts/architecture_proof_step05_pty.py:245](../../../scripts/architecture_proof_step05_pty.py#L245)、[scripts/architecture_proof_step05_pty.py:273](../../../scripts/architecture_proof_step05_pty.py#L273)。

**原因：** 脚本对 args.binary 计算哈希，却执行独立的 args.candidate，没有路径或哈希一致性校验。

**观察：** 源码存在两个可独立设置的路径，记录身份与执行对象之间没有断言；本轮未重跑 Step 0.5。

**影响：** A/B 结果可能被标记为另一个二进制的身份。

**建议：** 规范化一次 candidate 路径，对同一文件计算哈希并执行；如保留两参数则启动前强制相等。

**兼容性：** 证据 schema 可保持；命令行双路径用法会被约束。

证据：。

原始条目：`DOC-07`。

## CJTUI-092

**P2 · 已复现 · CI SDK PATH 未包含仓库要求的 tools/bin/cjpm**

位置：[scripts/resolve_nightly_sdk.py:197](../../../scripts/resolve_nightly_sdk.py#L197)、[.github/workflows/ci.yml:34](../../../.github/workflows/ci.yml#L34)、[scripts/check_sdk.sh:19](../../../scripts/check_sdk.sh#L19)。

**原因：** resolve_nightly_sdk 只把 sdk/bin 写入 GITHUB_PATH，而 check_sdk 还要求 sdk/tools/bin/cjpm。

**观察：** canonical mock 布局的隔离 PATH 中 cjc 可找到、cjpm 不可找到，Verify SDK rc=1。

**影响：** 新的 runner 若没有其他 cjpm，会在 release gate 前失败。

**建议：** 同时写入 sdk/bin 与 sdk/tools/bin，并用 canonical layout fixture 验证 cjc/cjpm 都可解析。

**兼容性：** 只改 CI 环境接线。

**证据限制：** 隔离 PATH fixture 已复现；没有核实当前托管 runner 是否恰好从其他路径提供 cjpm。

证据：[tooling/probe-env-output.json](evidence/tooling/probe-env-output.json)。

原始条目：`TOOL-04`。
