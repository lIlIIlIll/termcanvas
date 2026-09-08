# 复现说明

从仓库根目录运行。需要 Linux、Python 3、报告记录的 Cangjie SDK，以及各场景使用的常规本地工具。SDK 身份见 [验证记录](validation.json)。脚本先核对 443 个基线文件的 SHA-256；有差异时停止，防止将其他版本的结果归入本报告。

列出 75 个场景名称：

```bash
python3 docs/reviews/2026-09-08-full-audit/reproduce.py --list
```

使用本机 SDK 路径运行一个场景，例如窄宽度截断：

```bash
python3 docs/reviews/2026-09-08-full-audit/reproduce.py \
  --sdk /path/to/cangjie \
  --run render-probe-cut
```

运行全部场景时，把 `--run render-probe-cut` 换为 `--all`。这会实际启动 PTY 子命令、执行资源限额对照及媒体输出替身；每个场景的进程边界、限额与原始运行保持一致。结果写入打印出的新临时目录，不覆盖本报告。默认通过仓库 `scripts/cangjie_cmd.sh` 构建七个依赖包，再编译十一份诊断源。

已有同一源码和 SDK 的 canonical build 产物时，可传 `--targets /path/to/targets --skip-build`。目标目录按仓库现有 canonical 路径哈希规则组织；普通 `target/` 目录不能直接替代。交付脚本已使用本次 gate 产物在新的临时目录试跑 `render-probe-cut`，编译及场景退出均为 0。

预期窄宽度诊断包含 `budget=1 ... width=3 fits=false` 与 `budget=2 ... width=3 fits=false`。其他场景应比较 [原始运行日志](evidence/run-results.json) 和分组 `runtime_verification.json`，不能仅看退出码。

完整 gate 可使用仓库原命令重跑：

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie bash scripts/release_gate.sh
```

本报告的 gate 通过依赖当时工作目录中已有的两个未跟踪 manifest。干净基线副本运行 `python3 scripts/validate_architecture.py` 会报告缺失；这正是报告发现之一。对照只在临时副本补入两个原文件，未修复当前仓库。

`evidence/compile_probes.py`、`run_probes.py`、`run_gate.py` 保存原始运行脚本和路径。交付脚本在内存中替换工作目录、仓库和 SDK 路径，再执行相同编译/运行逻辑。`evidence/tooling/probe*.py` 是工具检查的原始临时夹具脚本，保留具体触发构造，未纳入上述 75 个 Cangjie 场景。示例诊断中的程序类来自基线源码拷贝，拷贝与入口替换说明见 [示例来源记录](evidence/widgets/example_probe_manifest.json)。
