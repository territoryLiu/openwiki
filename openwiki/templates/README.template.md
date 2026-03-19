# {{project_name}}

> 一句话电梯演讲：{{project_pitch}}

## 核心能力

- 能力 1：...
- 能力 2：...
- 能力 3：...

## 技术栈（来自 facts）

- 主要语言：`{{primary_languages}}`
- 框架识别：`{{frameworks}}`
- 关键入口：`{{entry_points}}`

参考：`docs/openwiki/facts.json`

## 快速开始

完整步骤见：[quickstart](docs/openwiki/quickstart.md)

Ubuntu 环境准备（示例）：

```bash
sudo apt-get update
sudo apt-get install -y ripgrep
sudo snap install powershell --classic
pwsh --version
rg --version
```

一键文档初稿命令（可选）：

```powershell
pwsh -NoProfile -File openwiki/scripts/generate-from-facts.ps1 -DocDir docs/openwiki -FactsPath docs/openwiki/facts.json -TocPath docs/openwiki/toc.yaml -ReadmePath README.md
```

推荐完整流水线命令（Claude/Codex 通用）：

```powershell
pwsh -NoProfile -File openwiki/scripts/openwiki-run.ps1 -RootDir . -DocDir docs/openwiki -ReadmePath README.md -DoctorFirst -MigrateMarkers
```

## 文档导航

- [项目门面与总览](docs/openwiki/wiki/01-overview.md)
- [系统架构与设计决策](docs/openwiki/wiki/02-architecture.md)
- [数据流与开发规范](docs/openwiki/wiki/03-dataflow-standards.md)
- [API 与接口契约](docs/openwiki/wiki/04-api-contract.md)
- [配置与 DevOps](docs/openwiki/wiki/05-config-devops.md)
- [测试与故障排查](docs/openwiki/wiki/06-qa-troubleshooting.md)

## 解析产物

- 项目事实数据：`docs/openwiki/facts.json`
- 校验摘要：`docs/openwiki/SUMMARY.md`
- 跨平台 CI：`.github/workflows/openwiki-cross-platform.yml`

## 许可证

根据仓库 `LICENSE` 填写。
