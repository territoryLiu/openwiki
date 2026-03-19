# Quickstart

## 1. 前置条件

- 安装 `PowerShell 7.2+`。
- 安装 `rg 13+` 用于代码扫描。
- 准备一个包含源码的目标仓库。

Ubuntu 安装示例：

```bash
sudo apt-get update
sudo apt-get install -y ripgrep
sudo snap install powershell --classic
pwsh --version
rg --version
```

参考：`openwiki/SKILL.md`（“执行规则”与 “Step 1: repo-scan”）

## 2. 获取项目

```powershell
git clone <your-repo-url>
cd openwiki
```

参考：`README.md`

## 3. 准备文档结构

- 编辑 `openwiki/toc.yaml`，定义 wiki 页面顺序与文件映射。
- 按 `openwiki/wiki/*.md` 组织页面内容，首行必须包含 `PAGE_ID`。

参考：`openwiki/toc.yaml`、`openwiki/templates/wiki-page.template.md`

## 4. 解析项目事实

```powershell
pwsh -NoProfile -File openwiki/scripts/repo-scan.ps1 -RootDir . -OutputPath openwiki/facts.json
```

- 产物位于 `openwiki/facts.json`。
- 建议写文档时优先引用该文件中的已确认事实。

参考：`openwiki/scripts/repo-scan.ps1`

推荐 Claude/Codex 通用一键命令：

```powershell
pwsh -NoProfile -File openwiki/scripts/openwiki-run.ps1 -RootDir . -DocDir openwiki -ReadmePath README.md -DoctorFirst -MigrateMarkers
```

参考：`openwiki/scripts/openwiki-run.ps1`

如需持续校验 Ubuntu/Windows，可启用 `.github/workflows/openwiki-cross-platform.yml`。

## 5. 自动生成文档初稿

```powershell
pwsh -NoProfile -File openwiki/scripts/generate-from-facts.ps1 -DocDir openwiki -FactsPath openwiki/facts.json -TocPath openwiki/toc.yaml -ReadmePath README.md
```

- 默认不覆盖已有 README、quickstart 和非标准 AUTOGEN 页面。
- 如需覆盖可追加 `-OverwriteExisting`。
- 若旧页面未命中自动区块，可先执行：
  `pwsh -NoProfile -File openwiki/scripts/migrate-autogen-markers.ps1 -WikiDir openwiki/wiki`

参考：`openwiki/scripts/generate-from-facts.ps1`

## 6. 执行校验

```powershell
pwsh -NoProfile -File openwiki/scripts/validate-lite.ps1 -DocDir openwiki -ReadmePath README.md
```

参考：`openwiki/scripts/validate-lite.ps1:1-6`、`openwiki/scripts/validate-lite.ps1:216-276`

## 7. 验证结果

- 终端应输出 `validate-lite: PASS`。
- 校验摘要产物位于 `openwiki/SUMMARY.md`。

参考：`openwiki/scripts/validate-lite.ps1:283-286`

## 8. 常见问题（速查）

- `未找到 wiki 目录`：确认 `-DocDir` 参数与目录结构一致。
- `repo-scan` 失败：确认已安装 `rg`，并能在终端直接执行 `rg --version`。
- 运行前可先执行：`pwsh -NoProfile -File openwiki/scripts/openwiki-doctor.ps1 -RootDir . -DocDir openwiki`。
- 大改后可执行：`pwsh -NoProfile -File openwiki/scripts/smoke-test.ps1 -RootDir . -DocDir openwiki -ReadmePath README.md`。
- `generate-from-facts` 未更新页面：当前页面没有标准 `{{page_id}}_overview/implementation/interfaces` 标记，可使用 `-OverwriteExisting` 追加自动区块。
- `README 链接目标不存在`：修复 README 中相对路径链接。
- `BEGIN/END 数量不一致`：检查 AUTOGEN 标记是否成对。

参考：`openwiki/scripts/repo-scan.ps1`、`openwiki/scripts/generate-from-facts.ps1`、`openwiki/scripts/validate-lite.ps1:148-150`、`openwiki/scripts/validate-lite.ps1:198`、`openwiki/scripts/validate-lite.ps1:132-135`
