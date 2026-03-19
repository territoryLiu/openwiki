<!-- PAGE_ID: overview -->

<details>
<summary>参考源码</summary>

- `README.md`
- `openwiki/SKILL.md`
- `openwiki/toc.yaml`
- `openwiki/templates/README.template.md`

</details>

# 01 项目门面与总览

<!-- BEGIN:AUTOGEN overview_overview -->
## 电梯演讲（Elevator Pitch）

OpenWiki 是一个“先可用、再增强”的轻量文档引擎：通过模板、TOC 和低成本校验，把仓库事实快速沉淀成可导航、可维护、可增量更新的 Wiki。

参考：`openwiki/SKILL.md`
<!-- END:AUTOGEN overview_overview -->

---

<!-- BEGIN:AUTOGEN overview_implementation -->
## 核心能力（杀手锏）

1. 统一入口：`README + quickstart + wiki` 三层文档结构。
2. 增量机制：`PAGE_ID` 与 `AUTOGEN` 标记可避免覆盖手工内容。
3. 事实优先：强调 “只写已确认事实，不确定即待补充”。
4. 轻量闭环：`validate-lite.ps1` 覆盖结构、链接、标记和 TOC 一致性检查。

参考：`openwiki/SKILL.md`、`openwiki/scripts/validate-lite.ps1:142-213`
<!-- END:AUTOGEN overview_implementation -->

---

<!-- BEGIN:AUTOGEN overview_interfaces -->
## 快速启动与导航

- 快速上手：`openwiki/quickstart.md`
- 目录配置：`openwiki/toc.yaml`
- 架构全景：`openwiki/wiki/02-architecture.md`
- 数据流与规范：`openwiki/wiki/03-dataflow-standards.md`
- 接口契约：`openwiki/wiki/04-api-contract.md`
- 运维与部署：`openwiki/wiki/05-config-devops.md`
- 测试排障：`openwiki/wiki/06-qa-troubleshooting.md`

参考：`openwiki/toc.yaml`、`README.md`
<!-- END:AUTOGEN overview_interfaces -->

---

## 手动补充

- 可在此区块记录业务背景、目标用户、里程碑等长期信息。
