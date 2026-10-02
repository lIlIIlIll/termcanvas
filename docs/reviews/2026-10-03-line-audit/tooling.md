# SDK 与验证脚本审计

基线 `e30b1c5`。根审计覆盖 `scripts/` 中除 `architecture_proof_*.py`（见 examples.md）之外的全部当前脚本、脚本测试和 `.github/workflows/ci.yml`，包括 SDK 固定策略、API 抽取/分类、Unicode 生成、示例生成、平台 smoke、发布与覆盖率流程。未修改 SDK 固定版本、性能基线或覆盖率阈值。

## 确认问题

| 编号 | 基线位置 | 复现与影响 | 修复 |
| --- | --- | --- | --- |
| TOOL-01 / P1 | `scripts/coverage.sh:5–17` | 在临时隔离仓库运行 `coverage.sh .` 会删除仓库本身；指定已有非覆盖率目录也会删除其中用户文件。3 个隔离回归证明旧实现删除 sentinel。 | 拒绝仓库根/祖先/最终路径符号链接；非空目录必须有本脚本写入的所有权标记才允许清理。未标记旧报告需选空目录。 |
| TOOL-02 / P1 | `scripts/resolve_nightly_sdk.py:205–220` | `startswith` 把 `install-sibling` 当作 `install` 子路径；tar 中 `../install-sibling/escaped` 越界。另 `link -> ../outside` 后 `link/escaped` 能越界写，因为预检时链接尚未建立。 | 使用路径组件级 `is_relative_to`；tar 启用 Python `data` 过滤，在提取每项时检查链接与特殊文件。安全相对 SDK symlink 保留。没有 `tarfile.data_filter` 的旧 Python 明确拒绝 tar 安装。 |
| TOOL-03 / P2 | `scripts/resolve_nightly_sdk.py:130,157` | 清单同时存在相同版本的 `linux-x64-1.1.3` 与 `linux-x64-ohos-1.1.3` 时，宽泛前缀与倒序排序会误选交叉 SDK。 | 原生 SDK 要求架构后紧接数字版本；清单和 DevRepo 共用匹配规则。 |
| TOOL-04 / P2 | `scripts/resolve_nightly_sdk.py:228–249,272–275` | 官方归档含 `cangjie/` 顶层目录，但安装后从目标根查 `bin/cjc`；导出的运行库路径也遗漏 `runtime/lib/linux_x86_64_cjnative` 与 `tools/lib`，后续工具不能启动。 | 安装返回实际 SDK 根，支持扁平和 `cangjie/` 两种布局；导出实际 native runtime 目录与 tools/lib。 |

ZIP 的路径前缀检查也不正确，但 Python ZipFile 会自行清理 `..`，因此未声称该 ZIP 用例已证明越界写；真实越界写证据来自 tar。SDK 风险需要安装者选择的归档含恶意成员，并非远程无交互攻击。

## 回归结果

- `test_resolve_nightly_sdk.py` 原有 6 例保留，新增 7 例。第一轮 4 FAIL（tar traversal、tar symlink、ZIP 验证、原生 SDK 选择），安全相对 symlink 用例为正向对照；补充布局/环境 2 FAIL。修复后 **13/13 PASS**。
- `test_coverage_output.py` 新增 3 例：无关目录保护、仓库保护、自己生成的报告可重复运行。修复前 3 FAIL，修复后 **4/4 PASS**（独立复核另补输出与构建目录重叠保护）。均使用临时目录和故意失败的假测试 runner，不操作真实用户目录。
- `python3 -m unittest discover -s scripts -p 'test_*.py'`：**44/44 PASS**（包括 examples 审计补充的长运行 gate 回归）。

## 工具链

实际使用 Linux x86_64 的官方 Cangjie 1.1.3，与 CI 一致：

- SDK 归档 SHA256：`2b68905afc466e665ae181595c63f96c18d75fd2c1fb6c6f0cb64e179c28d61a`
- cjc SHA256：`bf2536ea4dbb266ecca660decedad40bdcc373f4090a9eb70ded03bca52b4aae`
- runtime SHA256：`6ac1c91488100ef87c273bd9ab5015f712bc91f566f3bac74150a4485d2adc36`

SDK resolver 网络选择使用本地 mock 清单测试；没有访问私有 DevRepo 账号。Windows/macOS 原生终端路径本轮仅静态审查，未以 Linux 结果冒充原生验收。
