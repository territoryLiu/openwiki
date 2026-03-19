---
name: openwiki
description: 轻量 Wiki 文档生成 skill。使用 rg 扫描代码事实，快速生成 README、quickstart 与 wiki 页面。适用于在 Claude Code 或 Codex 中为新仓库补齐文档、按 toc 结构产出文档、或在迭代后快速刷新文档。
---

# OpenWiki（轻量增强版）

目标：用最少工具在任意仓库快速产出三套文档。

1. 根目录 `README.md`
2. `docs/openwiki/quickstart.md`
3. `docs/openwiki/facts.json`
4. `docs/openwiki/wiki/*.md`（按 `toc.yaml`）

## 执行规则

- 优先使用 `rg` / `rg --files` 抽取事实
- 只写已确认事实，缺失内容标记“待补充”
- 先保证可用，再优化细节

## 兼容性

- Codex：支持（`pwsh` + `rg` 环境）
- Claude Code：支持（`pwsh` + `rg` 环境）
- 推荐统一使用 `openwiki/scripts/openwiki-run.ps1` 执行完整流水线
- 可选 CI：`.github/workflows/openwiki-cross-platform.yml`（Ubuntu + Windows）

## 输出结构

```text
docs/openwiki/
├── toc.yaml
├── facts.json
├── quickstart.md
├── SUMMARY.md
└── wiki/
    ├── 01-overview.md
    ├── 02-architecture.md
    ├── 03-dataflow-standards.md
    ├── 04-api-contract.md
    ├── 05-config-devops.md
    └── 06-qa-troubleshooting.md
```

## 借鉴 openwiki-old 的轻量增强

### 1) 增量友好标记

为每个 wiki 页面添加稳定标记：

```markdown
<!-- PAGE_ID: {{page_id}} -->
<!-- BEGIN:AUTOGEN {{page_id}}_section -->
...
<!-- END:AUTOGEN {{page_id}}_section -->
```

规则：

- `PAGE_ID` 必须位于文件第一段
- 仅覆盖 `BEGIN/END:AUTOGEN` 之间内容
- 手动区块放在 AUTOGEN 外，更新时保留

### 2) 轻量证据引用

- 每个 H2/H3 区块至少包含 1 条源码路径引用
- 关键结论尽量带行号（如 `src/api/user.ts:20-48`）
- 不确定内容写“待补充”，不要猜测

### 3) 低成本校验

生成后至少检查：

- 页面都包含 `PAGE_ID`
- AUTOGEN 标记成对出现
- README 中 quickstart/wiki 路径可访问
- `toc.yaml` 页面路径与实际文件一致

## 固定流程（4+1）

### Step 0: doctor（建议）

```bash
pwsh -NoProfile -File openwiki/scripts/openwiki-doctor.ps1 -RootDir . -DocDir docs/openwiki
```

### 推荐一键执行

```bash
pwsh -NoProfile -File openwiki/scripts/openwiki-run.ps1 -RootDir . -DocDir docs/openwiki -ReadmePath README.md -DoctorFirst -MigrateMarkers
```

### Step 1: repo-scan

按需执行：

```bash
pwsh -NoProfile -File openwiki/scripts/repo-scan.ps1 -RootDir . -OutputPath docs/openwiki/facts.json
```

`repo-scan.ps1` 至少提取 6 类事实：

- 入口（后端/前端）
- API 与模块边界
- 配置项与环境变量
- 技术栈与框架识别
- 多语言依赖清单
- 模块目录分布

### Step 2: toc-design

- 默认使用本目录的 `toc.yaml`
- 仅在项目结构明显不匹配时调整页面清单

### Step 2.5: marker-migrate（可选）

若旧页面 AUTOGEN 命名不符合 `<page_id>_overview/implementation/interfaces`，先迁移：

```bash
pwsh -NoProfile -File openwiki/scripts/migrate-autogen-markers.ps1 -WikiDir docs/openwiki/wiki
```

### Step 3: doc-write

先自动生成初稿，再人工补充：

```bash
pwsh -NoProfile -File openwiki/scripts/generate-from-facts.ps1 -DocDir docs/openwiki -FactsPath docs/openwiki/facts.json -TocPath docs/openwiki/toc.yaml -ReadmePath README.md
```

- 默认安全模式：不覆盖已有 README/quickstart，且仅更新标准 AUTOGEN 区块
- 强制覆盖模式：追加 `-OverwriteExisting`

### Step 4: manual-refine

- 人工补充业务语义、架构权衡、风险边界
- 不确定结论标记“待补充”

### Step 5: validate-lite

- 校验结构与链接，不做重型流水线
- 发现问题后就地修正并覆盖写回
- 执行命令：

```bash
pwsh -NoProfile -File openwiki/scripts/validate-lite.ps1 -DocDir docs/openwiki -ReadmePath README.md
```

- 输出：`docs/openwiki/SUMMARY.md`

### Step 6: smoke-test（建议）

```bash
pwsh -NoProfile -File openwiki/scripts/smoke-test.ps1 -RootDir . -DocDir docs/openwiki -ReadmePath README.md
```

## 轻量质量门槛

- 每页至少 1 条源码路径引用
- Quickstart 必须覆盖：准备、配置、启动、验证、常见问题
- README 必须覆盖：项目介绍、功能、架构、快速开始入口

## 触发示例

- Claude Code（claudecoe）：`请使用 openwiki skill 为当前仓库生成文档`
- Codex：`Use $openwiki to generate docs for this repository`
