# 用 cjdoc 生成 API 参考

使用已安装的 `cjdoc 0.7.2`，从本仓库七个生产源码包生成可离线浏览的声明说明、签名、Doc IR 和文档覆盖率报告。需要 Python 3、PATH 中的 `cjdoc`；运行 `cjdoc --version` 核对版本。以下命令以仓库根目录为当前目录，不需要构建 SDK、运行示例或下载第三方 Markdown 包。

安装时从 [v0.7.2 官方发布页](https://github.com/lIlIIlIll/cjdoc/releases/tag/v0.7.2) 取得与平台匹配的资产及 `.sha256` 校验文件，核对哈希后把可执行文件放入 PATH。Linux 版本还需要与其兼容的 Cangjie 运行库；版本号能正常输出不代表解析源码时一定兼容。生成脚本要求精确的 0.7.2 版本。

## 生成并浏览

```bash
python3 scripts/generate_cjdoc.py
```

命令成功退出后打开 `target/doc/index.html`。总入口链接八个站点：`core-1`、`core-2`、`diff`、`game`、`markdown_adapter`、`media`、`terminal`、`testing`。每站点的页面、结构化结果和计数分别位于 `target/doc/packages/<站点名>/html/index.html`、`target/doc/packages/<站点名>/docs.json` 和 `target/doc/packages/<站点名>/coverage/coverage.json`。若已有非脚本管理的 `target/doc`，脚本会拒绝覆盖；改用 `python3 scripts/generate_cjdoc.py --output target/cjdoc-generated`。相对输出路径以调用时的工作目录为基准；从仓库外运行仍读取脚本所在仓库的源码。

脚本按 [`architecture/api-classification.json`](../architecture/api-classification.json) 的 `source_roots` 和生产文件排除规则复制源码，保留各包的 `cjpm.toml`，再逐站点运行 `cjdoc generate`。包含 `core`、`diff`、`game`、`markdown_adapter`、`media`、`terminal`、`testing`；`testing` 是下游测试支持包，不包含仓库测试用例。测试、示例或外部 Markdown 源码不进入站点。禁用依赖源码包含和 source cache。此次配置为 Linux/x86_64、`external`、中文多页站点；不代表全平台解析。此站点不包含非公开声明，需要检索内部接口时请查看源码和 API 分类清单。各站点的类型拼写不能证明跨文件或跨包符号已由编译器解析。生成报告不替代 [`api-inventory.json`](api-inventory.json)：注释覆盖率不决定稳定等级；以 [API 总览](api.md) 和稳定性契约为准。

脚本在未显式设置 `cjHeapSize` 时为 cjdoc 子进程设置 `1GB`，默认 256 MiB 堆不足以解析完整 core。整合 0.0.1 能力后，core 单包 Doc IR 超过 cjdoc 0.7.2 的 32 MiB 限额，因此按完整源码文件的大小确定性地分为两个分片，每个生产文件只进入一个站点，不裁剪声明或注释。总入口的 `.termcanvas-cjdoc-output.json` 记录各站点包含的相对源码路径。已有声明说明随源码迁移，新增 API 的说明覆盖率以本次报告为准；参数标签尚未全面提供。非零退出后留下的部分站点不能视为成功产物。

各站点的 `coverage/coverage.json` 分别给出符号说明与参数说明覆盖率，不应把旧版本的 100% 符号覆盖率套用于新增 API。Doc IR、HTML 外部受众索引和 API inventory 的统计口径不同；平台条件也会排除其他系统的声明。各站点按源码 AST 生成，语义状态为 partial；重新生成后以实际报告为准。

站点可显示 `TerminalView` 的 `Widget` 继承关系和 `render` 的 `Rect`/`Buffer` 类型拼写，但无跨站点超链接；core 两个分片之间也不例外。需要查看定义时，从总入口进入相应站点搜索类型。

## 命令与输出

- `cjdoc generate` 扫描 `--project` 指定的 cjpm 包或 workspace，生成 Doc IR，再按 `--format` 写出站点或报告。默认格式仅为 `json`。
- `cjdoc check` 扫描并诊断源码，不写渲染站点；AST 预处理仍可能创建临时文件，使用缓存时还可能写缓存。它不接受 `--format`、`--output`、`--stdout` 或渲染参数。
- `cjdoc render --input docs.json` 从已有 Doc IR 重新渲染，不重新扫描源码；不接受 `--project`、`--cfg`、依赖与源码分析参数。
- `cjdoc schema list` 列出内置 schema，`cjdoc schema doc-ir` 等打印具体 schema。可选名称：`doc-ir`、`doc-ir-v6`、`doc-ir-v7`、`doc-ir-v8`、`diagnostics`、`cfg-matrix`、`search-index`、`api-surface`、`documentation-coverage`。本版本的 Doc IR 为 `cjdoc.doc-ir/8`，覆盖率为 `cjdoc.documentation-coverage/1`。

已安装的 0.7.2 CLI 使用下表参数；重复项表示可以多次传入。未列出的主分支功能不可假定在此发布版本存在。

| 参数 | 命令 | 默认值、约束与用途 |
| --- | --- | --- |
| `--project DIR` | generate、check | 当前目录；须有 `cjpm.toml`，纯 workspace 可用，成员路径必须在 workspace 根目录内。 |
| `--format json\|markdown\|html\|api-surface\|coverage` | generate、render | 默认 `json`；可重复选择多个文件产物。 |
| `--output DIR` / `--stdout` | generate、render | 互斥；标准输出只能选一个 JSON 类格式（`json`、`api-surface` 或 `coverage`），不可输出 HTML/Markdown。不要预创建或强占目标目录。 |
| `--audience external\|package\|all` | generate | 默认 `external`（public/protected）；`package` 和 `all` 扩大可见范围，不能代替项目的稳定性分类。 |
| `--lint-profile off\|standard\|strict` | generate、check | 默认 `standard`；strict 可检查更多缺失文档。 |
| `--jobs 1..64` | generate | 默认 1。 |
| `--cfg NAME=VALUE` | generate、check | 可重复；选择分析配置，本仓库生成时传入 `os=Linux` 和 `arch=x86_64`。 |
| `--include-path-dependencies` | generate、check | 分析已有相对路径依赖。 |
| `--include-cached-dependencies`、`--cjpm-cache DIR` | generate、check | 使用本地缓存依赖；显式 `--cjpm-cache` 必须搭配 `--include-cached-dependencies`，不会下载缺失依赖。 |
| `--dependency-source NAME=PATH` | generate、check | 可重复，显式指定依赖源码路径。 |
| `--cache-dir DIR` / `--no-cache` | generate、check | 互斥；前者指定 source cache，后者禁用。缓存路径与输出目录不可互相包含。 |
| `--force-owned` | generate、render | 仅用于工具已拥有的输出；不用于覆盖非受管文件。 |
| `--locale zh-CN\|en` | generate、render | 默认 `zh-CN`。 |
| `--markdown-layout site\|single` | generate、render | 默认 `site`；`single` 仅可搭配 `--locale en`。 |
| `--deny-warnings` | check | 把警告视为检查失败。 |
| `--api-surface-baseline FILE` | check | 对照现有 API surface 文件检查。 |
| `--min-symbol-coverage 0..100`、`--min-parameter-coverage 0..100` | check | 可选文档覆盖率下限；符号与参数分别计数。实际符号与参数覆盖率以生成报告为准；尚未覆盖的声明不代表已经完成文档。 |

正常退出码为 0，诊断/门禁失败为 1，参数或输入错误为 2。即使生成目录已有文件，退出非零也不能视为成功。[固定版本上游用法](https://github.com/lIlIIlIll/cjdoc/blob/v0.7.2/docs/usage.md)与[高级用法](https://github.com/lIlIIlIll/cjdoc/blob/v0.7.2/docs/advanced-usage.md)以及实际安装的 0.7.2 CLI 是本页依据；相邻源码仓库的后续开发功能不等于本次发布的功能。

## 写声明注释

将文档注释紧邻声明之前；普通 `//` 不作为该声明的完整文档说明。首段写 summary，空行后的段落写 description，再按需要标注参数、返回值和错误。

~~~~cangjie
/**
 * 返回输入值的两倍。
 *
 * 接受有符号整数，结果按整数乘法计算。
 *
 * @example 基本用法
 * ```cangjie
 * let result = double(3) // result == 6
 * ```
 *
 * @param value 待加倍的整数
 * @return 输入值乘以二的结果
 * @since 0.0.1
 */
public func double(value: Int64): Int64 {
    value * 2
}
~~~~

可按真实声明补充 `@throws`（确实抛出的异常）、`@see`（相关 API）、`@deprecated`（实际弃用信息）、`@author`、`@version`。不要给不存在的异常写 `@throws`，也不要把符号名批量填作 summary。生成签名不会自动填充缺失的说明；打开 `coverage/coverage.json` 查看实际符号与参数覆盖率。

下游测试包的 `TestScenario` 示例可从源码注释中提取，并在独立消费方项目中编译和运行：

```bash
CANGJIE_SDK_ROOT=/path/to/cangjie python3 scripts/test_cjdoc_examples.py
```

此检查只覆盖测试包中“检查渲染内容”和“组合任务状态与进度条”两个示例；它不表示所有 API 都已有示例或均经过执行。

cjdoc 0.7.2 支持结构化 `@example`：标签后可写标题和 Markdown 代码围栏，HTML 会单独渲染“示例”，Markdown 保留围栏。当前发布版本的 CLI **没有** `--check-examples`；示例仅展示，不会自动编译或运行。相邻开发分支中的示例指令和 doctest 功能不能套用到本版本。

## 单包检查与离线重渲染

检查较小的 diff 包的 Linux/x86_64 源码，不写站点：

```bash
cjHeapSize=1GB cjdoc check --project packages/diff --cfg os=Linux --cfg arch=x86_64 --lint-profile standard --no-cache
```

从已有 IR 输出另一个站点，输入文件可以在原临时源码快照消失后使用；目标目录应为新目录或 cjdoc 已拥有的目录：

```bash
cjdoc render --input target/doc/packages/core-1/docs.json --format html --format markdown --locale zh-CN --markdown-layout site --output target/doc-rerendered
```

需要评估门禁时，可先生成 `--format api-surface`，再按实际文档覆盖率逐步选择检查阈值（下例的 0 只是参数演示，不构成覆盖门禁）；不要把本项目的 `STABLE`/`EXPERIMENTAL` 契约误当作 cjdoc 的 API surface baseline：

```bash
cjHeapSize=1GB cjdoc generate --project packages/diff --format api-surface --output target/diff-api-surface --no-cache
cjHeapSize=1GB cjdoc check --project packages/diff --cfg os=Linux --cfg arch=x86_64 --no-cache --min-symbol-coverage 0 --min-parameter-coverage 0
```

详细 schema 可用 `cjdoc schema doc-ir` 与 `cjdoc schema documentation-coverage` 查看。`target/` 下产物为本地生成文件，不提交为第二份权威 API baseline。
