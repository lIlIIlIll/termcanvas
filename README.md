# termcanvas

> 用 Cangjie 构建终端应用的即时模式 TUI 库。
[![CI](https://github.com/lIlIIlIll/termcanvas/actions/workflows/ci.yml/badge.svg)](https://github.com/lIlIIlIll/termcanvas/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/lIlIIlIll/termcanvas)](LICENSE) [![codecov](https://codecov.io/gh/lIlIIlIll/termcanvas/branch/main/graph/badge.svg)](https://codecov.io/gh/lIlIIlIll/termcanvas)

`termcanvas` 以 Linux/glibc 为首要验证平台。应用持有自己的状态，在一个
`App` 更新循环中处理 `Event`，通过 `Command` 返回副作用，再由即时模式
`Widget` 把状态渲染到终端。

<p align="center">
  <a href="docs/getting-started.md">快速开始</a> ·
  <a href="docs/examples.md">示例目录</a> ·
  <a href="docs/api.md">API 总览</a> ·
  <a href="docs/versioning.md">版本与兼容性</a>
</p>

## 核心模型

```text
应用状态
   ↓
App / update / Event / Command
   ↓
有序、run-to-completion 的运行时
   ↓
DirtyRects 与帧合并
   ↓
即时 Widget 渲染
   ↓
Frame / Buffer / Backend
```

这条路径有三个明确边界：

- 应用负责业务状态、交互策略、选择状态和相关 ID。
- `update` 是应用状态的唯一更新入口。后台任务只返回不可变的完成事件。
- `Widget` 负责当前状态的渲染，不负责第二套生命周期或事件循环。

## 主要能力

| 方向 | 能力 |
| --- | --- |
| 运行时 | 有序命令、消息、定时器、异步任务、PTY 数据事件、区域重绘 |
| 渲染 | 即时 Widget、布局、样式、主题、`Frame`、`Buffer`、差分刷新 |
| 输入 | 键盘、鼠标、粘贴、焦点、终端能力探测、窗口大小变化 |
| 内容 | 富文档、Markdown 适配、文本编辑、Unicode 字素与终端单元格宽度 |
| 扩展 | ANSI 终端输出、统一 diff、媒体、游戏和无头测试工具 |
| 验证 | 事件脚本、快照、示例 smoke、API 契约、压力场景和发布闸门 |

## 5 分钟运行第一个应用

### 前置条件

- 已检出本仓库。
- 本地安装 Cangjie SDK，并设置 `CANGJIE_SDK_ROOT`。
- 使用可运行交互式终端应用的终端。

仓库脚本会检查 SDK 版本并设置编译、运行时和动态库路径。包清单声明的
语言兼容版本是 `cjc-version = "1.1.0"`；发布验证使用的精确工具链见
[版本与兼容性](docs/versioning.md)。

### 运行基础模板

基础模板位于 [`templates/basic_app`](templates/basic_app)。从仓库根目录执行：

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh templates/basic_app cjpm build

CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh templates/basic_app cjpm run
```

运行后按 `+` 增加计数，按 `q` 或 `Ctrl-C` 退出。完整步骤和事件脚本验证
见[快速开始](docs/getting-started.md)。

### 最小渲染路径

下面的程序只渲染一个即时 Widget，适合先确认 API 入口：

```cangjie
import core.*

main(): Int64 {
    runAppWithCommands(
        { frame =>
            frame.renderWidget(
                Paragraph("Hello, termcanvas", block: Block(title: "Demo")),
                frame.area
            )
        },
        { _ => UpdateResult.next() }
    )
    0
}
```

需要保存状态、处理输入或执行副作用时，使用
`App(...).runWithCommands(...)`，让 `update` 处理事件，让 `render` 根据当前
状态绘制界面。

## 从示例开始

先运行 [`taskpad`](examples/taskpad/)，再按目标选择示例：

| 目标 | 示例 |
| --- | --- |
| 表单与焦点 | [`form_studio`](examples/form_studio/) |
| 定时器、异步任务与命令 | [`command_center`](examples/command_center/) |
| 大数据集与文件浏览 | [`data_browser`](examples/data_browser/) |
| Markdown 编辑与预览 | [`markdown_studio`](examples/markdown_studio/) |
| 终端能力与诊断 | [`debug_lab`](examples/debug_lab/) |
| PTY、终端转录与 diff | [`terminal_lab`](examples/terminal_lab/) |
| 媒体协议与回退 | [`media_gallery`](examples/media_gallery/) |
| 压力与规模验证 | [`game_pressure_suite`](examples/game_pressure_suite/) |

完整目录包含 17 个示例：8 个推荐应用、2 个实验应用、6 个功能演示和 1 个
压力/证明工作负载。查看[示例目录](docs/examples.md)了解每个示例的用途。

从仓库根目录运行单个示例：

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/cangjie_cmd.sh examples/taskpad cjpm run
```

构建全部示例：

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie \
  scripts/build_examples.sh
```

## 包结构

| 包 | 用途 |
| --- | --- |
| `packages/core` | 运行时、事件、终端会话、布局、Widget、富文档和编辑原语 |
| `packages/cj_markdown` | 独立 Markdown 解析器，不依赖 `termcanvas` |
| `packages/markdown` | 把 Markdown AST 转换为 `core.Document` |
| `packages/terminal` | ANSI 输出解析、终端转录和 `TerminalView` |
| `packages/diff` | 统一 diff 解析和 `DiffView` |
| `packages/media` | Kitty、Sixel、文本回退和 ffmpeg ASCII 动画 |
| `packages/game` | 实体、组件存储、物理、TileMap、精灵和相机 |
| `packages/example_smoke` | 核心组件组合的无头验证 |

`packages/editor`、`packages/document` 以及旧的高级 editor shell 已退役。编辑
和文档能力直接使用 `core` 中的同名稳定原语；格式解析仍由扩展包负责。

## API 稳定性

项目处于 `0.1.x`、pre-1.0 阶段。每个公开声明属于以下四个等级之一：

| 等级 | 含义 |
| --- | --- |
| `STABLE` | 面向应用的兼容性承诺 |
| `EXPERIMENTAL` | 可用于评估和扩展，形状或行为可能变化 |
| `INTERNAL` | 实现或维护者边界，不是普通构造入口 |
| `TEST_ONLY` | 仅供仓库测试、快照或发布闸门使用 |

完整成员、所有者、签名和等级以生成的
[`docs/api-inventory.json`](docs/api-inventory.json) 为准。先看
[API 总览](docs/api.md)，再看[版本与兼容性](docs/versioning.md)。

## 平台与限制

- Linux/glibc 是当前完整验证的终端目标。
- macOS 和 Windows 有原生代码路径，但在纳入对应回归矩阵前仍属于实验支持。
- Windows 默认 waiter 支持提供 `waitHandle()` 的 `EventSource`；只有 POSIX
  文件描述符的 source 需要自定义 waiter。
- `TerminalSession` 负责恢复 raw mode、光标和终端输入模式。raw mode 失败时，
  检查 `TerminalSession.rawModeEnabled` 和 `TerminalMode.lastError()`。
- 终端渲染基于单元格，不提供 GPU 渲染器或内嵌浏览器。
- 大文件、无限日志和大表格应使用虚拟行提供器、环形缓冲区或分页模型。

详见[平台支持](docs/platforms.md)和[限制](docs/limitations.md)。

## 验证与发布

针对事件脚本的快速检查：

```bash
scripts/run_event_script.sh \
  packages/core/tests/events/basic.events \
  packages/core/tests/events/scenario.events
```

在准备分享或发布构建前，从仓库根目录运行完整发布闸门：

```bash
scripts/release_gate.sh
```

发布闸门会运行包测试、事件脚本、快照检查、API 契约和 Unicode 数据检查、示例
构建与 smoke、脚本化工作流以及压力场景。
Codecov 覆盖率目标为：生产包行覆盖率 90%、分支覆盖率 80%；示例仍在覆盖率命令中执行，但其演示和操作系统终端生命周期代码不计入汇总。测试层级与执行命令见[测试文档](docs/testing.md)。

## 许可证

本项目使用 Apache License 2.0，完整条款见 [`LICENSE`](LICENSE)。

## 文档导航

| 文档 | 内容 |
| --- | --- |
| [快速开始](docs/getting-started.md) | 构建并运行第一个应用 |
| [App Runtime](docs/app-runtime.md) | 命令、事件、定时器、异步任务和关闭 |
| [架构](docs/architecture.md) | 状态所有权、更新边界和渲染路径 |
| [Widgets](docs/widgets.md) | Widget 选择、状态和编辑能力 |
| [Layout](docs/layout.md) | 约束、间距、Grid 和 Flex 布局 |
| [Events](docs/events.md) | 键盘、鼠标、粘贴、焦点和终端事件 |
| [Extensions](docs/extensions.md) | Markdown、终端、diff、媒体和游戏扩展 |
| [Testing](docs/testing.md) | 测试工具、快照、性能和发布验证 |
| [Examples](docs/examples.md) | 17 个示例的分类和运行命令 |
| [API Overview](docs/api.md) | 面向应用的 API 地图 |
| [Versioning](docs/versioning.md) | 稳定性等级与兼容性规则 |
