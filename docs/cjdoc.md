# 生成中文 API 参考

使用 cjdoc 生成 Termcanvas 生产包的 API 站点。生成器按 Linux、macOS 和 Windows 的条件编译配置分别生成页面，并保留 API 分类清单。当前页面和示例仍在补全，生成成功不代表全部应用 API 已有说明或通过示例验收。

## 准备工具

安装 Cangjie STS 1.2.0，将 `CANGJIE_SDK_ROOT` 设置为 SDK 目录，并启用 SDK 环境。生成器会核对编译器和包管理器版本，隔离 SDK 动态库路径，并在输出标记中记录工具与运行时的摘要。下载 [cjdoc 0.7.7 正式发行包](https://github.com/lIlIIlIll/cjdoc/releases/tag/v0.7.7)，使用同名 `.sha256` 文件核对下载内容，然后解压。生成器验证可执行文件的 SHA-256，不接受只具有相同版本号的其他二进制。

Linux x86-64 示例：

```bash
sha256sum -c cjdoc-0.7.7-linux-x64.tar.gz.sha256
tar -xzf cjdoc-0.7.7-linux-x64.tar.gz
export PATH="$PWD/cjdoc-0.7.7:$PATH"
```

确认 PATH 中的 `cjdoc` 指向解压得到的可执行文件。项目中验证过的组合是 Linux x86-64 上的 cjdoc 0.7.7 与 Cangjie STS 1.2.0。macOS ARM64 和 Windows x86-64 发行文件的哈希也已固定；这不代表本地已经验证这两种环境的文档生成。

## 生成站点

从仓库根目录执行：

```bash
python3 scripts/generate_cjdoc.py
```

成功后，入口位于 `target/doc/index.html`；各包和平台的 HTML、Doc IR 以及覆盖报告位于 `target/doc/packages/`。`api-inventory.json` 包含项目的稳定性分类。站点上的 cjdoc 语言可见性与项目的稳定性分类是两个不同维度。

使用 `--cjdoc` 指定可执行文件路径，使用 `--output` 指定输出位置。脚本只会替换由它创建并带有有效标记的输出目录；不受管理的已有目录会被保留。生成失败时会保留旧站点，不会将半成品替换为成功产物。

开发期间可选择部分包和平台。例如：

```bash
python3 scripts/generate_cjdoc.py --package testing --platform linux --output target/cjdoc-testing
```

可重复传入 `--package` 或 `--platform`。选择部分目标时，入口页面和输出标记会注明范围；这类输出不能用于完整文档验收。

生成离线 ZIP 时，选择一个尚不存在、且不在站点目录内的路径：

```bash
python3 scripts/bundle_cjdoc.py target/doc --output target/termcanvas-api-docs.zip
```

命令会先检查源码身份和本地链接，再输出 ZIP 的 SHA-256。压缩包保留站点范围和示例验证状态；部分站点的压缩包仍然是部分产物。

## 核对与限制

生成器先检查已提交的 API 清单是否与源码一致，之后核对 cjdoc 读取的生产文件集合。如果源码或分类清单在生成期间发生变化，命令会失败。

`coverage/coverage.json` 记录 cjdoc 对公开声明的说明、参数和示例统计。报告不会证明示例已经运行，也不等同于项目的稳定性分类。运行以下检查，查看应用声明的中文说明、直接示例和共享示例链接情况，并核对本地页面链接：

```bash
python3 scripts/audit_cjdoc.py target/doc
python3 scripts/check_cjdoc_links.py target/doc
```

共享示例与声明签名的对应关系保存在 `docs/api-examples/manifest.json`。以下命令在当前系统上将适用示例编译为独立消费方并运行；目标报告文件必须不存在：

```bash
python3 scripts/run_cjdoc_examples.py --report target/cjdoc-example-results.json
```

报告包含源码和 SDK 摘要。一个平台的结果不能证明其他平台通过；审计中的示例链接数量也不代表示例已经执行。下游测试包的两个已有示例可通过以下命令从源码注释中提取，并作为独立应用编译运行：

```bash
python3 scripts/test_cjdoc_examples.py
```

该命令需要 `CANGJIE_SDK_ROOT` 指向可用的 SDK，且只验证这两个示例。其余应用 API、跨平台示例、完整站点的浏览器展示和线上发布仍需分别验收。
