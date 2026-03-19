# OpenWiki

> 一句话电梯演讲：OpenWiki 用最轻量的方式把“代码事实”快速沉淀为可维护、可增量更新的项目文档体系。

## 核心能力

- 模板化产出：内置 `README`、`quickstart`、`wiki` 页面模板，统一文档骨架。
- 项目解析：`repo-scan.ps1` 自动抽取入口点、依赖、API 线索、配置键并输出 `facts.json`。
- 增量友好：通过 `PAGE_ID` + `BEGIN/END:AUTOGEN` 标记实现“自动区与手写区”隔离。
- 低成本校验：脚本自动检查目录结构、TOC 一致性、README 链接和 AUTOGEN 配对。
- 面向协作：通过 `toc.yaml` 统一导航，降低跨角色协作成本。

## 快速启动（Quick Start）

### 依赖环境

- `PowerShell 7.2+`（建议；`Windows PowerShell 5.1` 亦可运行基础流程）
- `Git 2.30+`
- `ripgrep (rg) 13+`（用于仓库事实扫描）

### Ubuntu 快速准备

```bash
# 安装 ripgrep
sudo apt-get update
sudo apt-get install -y ripgrep

# 安装 PowerShell（推荐 Snap 方式）
sudo snap install powershell --classic

# 验证
pwsh --version
rg --version
```

### 极简命令

```powershell
git clone <your-repo-url>
cd openwiki
pwsh -NoProfile -File openwiki/scripts/openwiki-run.ps1 -RootDir . -DocDir openwiki -ReadmePath README.md -DoctorFirst -MigrateMarkers
```

### 兼容性

- `Codex`：支持（`pwsh` + `rg`）
- `Claude Code`：支持（`pwsh` + `rg`）

## 目录导航

- 快速上手：[openwiki/quickstart.md](openwiki/quickstart.md)
- TOC 配置：[openwiki/toc.yaml](openwiki/toc.yaml)
- 解析产物：[openwiki/facts.json](openwiki/facts.json)
- 自动初稿脚本：[openwiki/scripts/generate-from-facts.ps1](openwiki/scripts/generate-from-facts.ps1)
- 一键流水线脚本：[openwiki/scripts/openwiki-run.ps1](openwiki/scripts/openwiki-run.ps1)
- 健康检查脚本：[openwiki/scripts/openwiki-doctor.ps1](openwiki/scripts/openwiki-doctor.ps1)
- 冒烟回归脚本：[openwiki/scripts/smoke-test.ps1](openwiki/scripts/smoke-test.ps1)
- 跨平台 CI 工作流：`.github/workflows/openwiki-cross-platform.yml`
- 系统全景：[openwiki/wiki/02-architecture.md](openwiki/wiki/02-architecture.md)
- 数据流与规范：[openwiki/wiki/03-dataflow-standards.md](openwiki/wiki/03-dataflow-standards.md)
- 接口契约：[openwiki/wiki/04-api-contract.md](openwiki/wiki/04-api-contract.md)
- 运维部署：[openwiki/wiki/05-config-devops.md](openwiki/wiki/05-config-devops.md)
- 测试排障：[openwiki/wiki/06-qa-troubleshooting.md](openwiki/wiki/06-qa-troubleshooting.md)

## 适用场景

- 新仓库冷启动：先有可用文档，再渐进细化。
- 旧仓库补文档：先抽事实，再映射到标准 wiki 结构。
- 迭代后刷新：仅更新 AUTOGEN 区块，保留人工维护内容。
