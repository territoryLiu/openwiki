# OpenWiki Skill

`openwiki` 是面向 Claude Code 与 Codex 的轻量文档生成 skill，目标是用最少工具快速产出三套文档：根 `README.md`、`docs/openwiki/quickstart.md`、`docs/openwiki/wiki/*.md`。  
参考：`openwiki/SKILL.md:8`、`openwiki/SKILL.md:11`、`openwiki/SKILL.md:12`

## 功能概览

- `repo-scan`：优先用 `rg` 抽取仓库事实。参考：`openwiki/SKILL.md:16`、`openwiki/SKILL.md:72`
- `toc-design`：默认采用 `openwiki/toc.yaml` 的页面清单。参考：`openwiki/SKILL.md:93`
- `doc-write`：按模板生成 README、quickstart、wiki 页面。参考：`openwiki/SKILL.md:100`
- `validate-lite`：检查 `PAGE_ID`、AUTOGEN 标记、README 链接与 toc 文件映射。参考：`openwiki/SKILL.md:104`、`openwiki/scripts/validate-lite.ps1:172`

## 架构速览

- 规范与流程：`openwiki/SKILL.md`
- 页面目录定义：`openwiki/toc.yaml`
- 文档模板：`openwiki/templates/README.template.md`、`openwiki/templates/quickstart.template.md`、`openwiki/templates/wiki-page.template.md`
- 校验脚本：`openwiki/scripts/validate-lite.ps1`

## 快速开始

完整步骤见：[quickstart](docs/openwiki/quickstart.md)。

## 文档导航

- [项目总览](docs/openwiki/wiki/01-overview.md)
- [架构设计](docs/openwiki/wiki/02-architecture.md)
- [后端与 API](docs/openwiki/wiki/03-backend-api.md)
- [前端结构](docs/openwiki/wiki/04-frontend.md)
- [部署与运行](docs/openwiki/wiki/05-deployment.md)
- [配置说明](docs/openwiki/wiki/06-configuration.md)
- [校验摘要](docs/openwiki/SUMMARY.md)

## 许可证

MIT
