# 验证记录

本次结果对应提交 `ab76bc1b39ed3a9261487beb71b4d1967accc2a2`。完整身份和机器可读结果见 [validation.json](validation.json)。

| 项目 | 结果 | 证据与范围 |
| --- | --- | --- |
| 完整 `scripts/release_gate.sh` | PASS | [日志](evidence/logs/release-gate.log)，退出 0，437.26 秒 |
| 不同包测试用例 | PASS，586 项 | core 528、cj_markdown 15、markdown 18、terminal 5、diff 3、media 9、game 8；压力阶段重复运行的 core 测试不再次计数 |
| 示例构建 | PASS，17 个 | 同一 gate 日志；另执行 btm_clone、media_gallery、game_demo 的 headless smoke 和 example_smoke |
| API 与架构检查 | PASS | 2449 个生产声明，未分类 0；顶层声明 383：stable 212、experimental 123、internal 34、test_only 14 |
| API 提取器测试 | PASS，14 项 | 同一 gate 日志 |
| Unicode 生成一致性 | PASS | 同一 gate 日志 |
| basic_app 模板构建 | PASS | [模板日志](evidence/logs/template-build.log) |
| 独立复现源编译 | PASS，11 份 | [编译记录](evidence/compile-results.json)，保留源码和二进制 SHA-256 |
| 独立复现场景 | 已运行 75 个 | [运行记录](evidence/run-results.json)，并非“75 个正确性测试通过” |
| 干净 tracked archive 架构检查 | FAIL，退出 1 | [原始失败日志](evidence/logs/clean-archive-architecture.log)，两个必需 manifest 不存在 |
| 临时 archive 补入两个 manifest 后 | PASS，退出 0 | [对照日志](evidence/logs/clean-archive-control.log)，只复查架构检查 |
| 交付复现脚本试跑 | PASS | [记录](evidence/replay-smoke/run-results.json)，在新临时目录重新编译 11 份源并运行 `render-probe-cut` |

首次完整 gate 在受限执行环境中因 unittest 创建本地 socket 返回 `Operation not permitted` 而退出，原始记录保留在 [首次日志](evidence/logs/release-gate-sandbox.log)。相同命令在获准的本地执行环境中通过；首次结果不归因于产品代码。

复现场景各自使用独立进程会话，禁用 core 文件，并设置 15 秒期限、10/12 秒 CPU 限额和 256 MiB RSS 监测阈值；只有 `fds-*` 场景另设 128 个 FD 限额。监测采样有间隔，因此峰值可能略超过阈值。程序退出结果先记录，再清理该场景的残留进程。

两个 ANSI 场景由 RSS 阈值停止，`stop_reason=rss_limit_256MiB`；无效 PTY 命令场景退出 `-9`，`stop_reason=null`，不能与监测停止混为一谈。诊断程序通常以退出 0 打印观察值，这不表示观察值正确。具体对照、部分复现及未执行路径见各组 `runtime_verification.json`。

macOS 的常量问题来自源码及系统头文件，未在 macOS 上运行。Windows/macOS 工具检查使用临时目录和模拟工具，不是原生平台或托管 CI 的通过/失败证明。光标恢复使用记录型后端，媒体参数使用有限输出替身，没有据此声称真实终端或视频画面已验收。

未执行长期性能矩阵、原生 macOS/Windows、远端 CI、真实终端外观验收。本次未修改产品源码、测试、原有基线或两个未跟踪 manifest；未创建提交或推送。
