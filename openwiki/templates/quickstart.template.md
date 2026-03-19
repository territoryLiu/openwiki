# Quickstart

## 1. 前置条件

- `PowerShell 7.2+`
- `rg 13+`
- 可访问目标项目源码

Ubuntu 安装示例：

```bash
sudo apt-get update
sudo apt-get install -y ripgrep
sudo snap install powershell --classic
pwsh --version
rg --version
```

## 2. 克隆仓库

```bash
git clone <your-repo-url>
cd <repo-dir>
```

## 3. 解析项目事实

```bash
pwsh -NoProfile -File openwiki/scripts/repo-scan.ps1 -RootDir . -OutputPath docs/openwiki/facts.json
```

产物：`docs/openwiki/facts.json`

推荐使用一键流水线（Claude/Codex 通用）：

```bash
pwsh -NoProfile -File openwiki/scripts/openwiki-run.ps1 -RootDir . -DocDir docs/openwiki -ReadmePath README.md -DoctorFirst -MigrateMarkers
```

如需持续校验 Ubuntu/Windows，可启用 `.github/workflows/openwiki-cross-platform.yml`。

## 4. 自动生成文档初稿

```bash
pwsh -NoProfile -File openwiki/scripts/generate-from-facts.ps1 -DocDir docs/openwiki -FactsPath docs/openwiki/facts.json -TocPath docs/openwiki/toc.yaml -ReadmePath README.md
```

- 默认不覆盖已有手写内容
- 如需强制覆盖可追加 `-OverwriteExisting`
- 若旧页面无法自动更新，可先执行：
  `pwsh -NoProfile -File openwiki/scripts/migrate-autogen-markers.ps1 -WikiDir docs/openwiki/wiki`

## 5. 人工补充与修订

- 按 `docs/openwiki/toc.yaml` 维护页面清单
- 依托 `facts.json` 填充 README、quickstart 与 wiki 页面
- 不确定内容写“待补充”

## 6. 执行文档校验

```bash
pwsh -NoProfile -File openwiki/scripts/validate-lite.ps1 -DocDir docs/openwiki -ReadmePath README.md
```

## 7. 常见问题

- `repo-scan` 失败：确认已安装 `rg`
- 运行前可先执行：`pwsh -NoProfile -File openwiki/scripts/openwiki-doctor.ps1 -RootDir . -DocDir docs/openwiki`
- 大改后可执行：`pwsh -NoProfile -File openwiki/scripts/smoke-test.ps1 -RootDir . -DocDir docs/openwiki -ReadmePath README.md`
- `generate-from-facts` 未更新页面：检查页面是否包含标准 AUTOGEN 标记，或使用 `-OverwriteExisting`
- `README 链接目标不存在`：修复 README 的相对路径
- `toc 页面路径不存在`：同步 `toc.yaml` 与 `wiki/*.md`
