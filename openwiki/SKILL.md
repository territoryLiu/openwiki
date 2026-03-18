---
name: openwiki
description: 轻量 Wiki 文档生成 skill。使用 rg 扫描代码事实，快速生成 README、quickstart 与 wiki 页面。适用于在 Claude Code 或 Codex 中为新仓库补齐文档、按 toc 结构产出文档、或在迭代后快速刷新文档。
---

# OpenWiki（轻量增强版）

目标：用最少工具在任意仓库快速产出三套文档。

1. 根目录 `README.md`
2. `docs/openwiki/quickstart.md`
3. `docs/openwiki/wiki/*.md`（按 `toc.yaml`）

## 执行规则

- 优先使用 `rg` / `rg --files` 抽取事实
- 只写已确认事实，缺失内容标记“待补充”
- 先保证可用，再优化细节

## 输出结构

```text
docs/openwiki/
├── toc.yaml
├── quickstart.md
├── SUMMARY.md
└── wiki/
    ├── 01-overview.md
    ├── 02-architecture.md
    ├── 03-backend-api.md
    ├── 04-frontend.md
    ├── 05-deployment.md
    └── 06-configuration.md
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

## 固定流程（3+1）

### Step 1: repo-scan

按需执行：

```bash
rg --files
rg -n "MiniApi|Http(Get|Post|Put|Delete)|MapGet|MapPost" src
rg -n "AddDbContext|UseSqlite|UseNpgsql|ConnectionString|DB_TYPE|CONNECTION_STRING" src compose.yaml
rg -n "WIKI_|CHAT_|ENDPOINT|JWT_" compose.yaml src/OpenDeepWiki/appsettings*.json
rg -n "next|app/|components/|route.ts|page.tsx" web
```

提取 4 类事实：

- 入口（后端/前端）
- API 与模块边界
- 配置项与环境变量
- 启动与部署方式

### Step 2: toc-design

- 默认使用本目录的 `toc.yaml`
- 仅在项目结构明显不匹配时调整页面清单

### Step 3: doc-write

按模板写：

- 根 `README.md` -> `templates/README.template.md`
- `docs/openwiki/quickstart.md` -> `templates/quickstart.template.md`
- `docs/openwiki/wiki/*.md` -> `templates/wiki-page.template.md`

### Step 4: validate-lite

- 校验结构与链接，不做重型流水线
- 发现问题后就地修正并覆盖写回
- 执行命令：

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File openwiki/scripts/validate-lite.ps1 -DocDir docs/openwiki -ReadmePath README.md
```

- 输出：`docs/openwiki/SUMMARY.md`

## 轻量质量门槛

- 每页至少 1 条源码路径引用
- Quickstart 必须覆盖：准备、配置、启动、验证、常见问题
- README 必须覆盖：项目介绍、功能、架构、快速开始入口

## 触发示例

- Claude Code（claudecoe）：`请使用 openwiki skill 为当前仓库生成文档`
- Codex：`Use $openwiki to generate docs for this repository`
