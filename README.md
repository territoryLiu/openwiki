# Wiki 文档生成器 / Wiki Document Generator

[中文](#中文) | [English](#english)

---

<a name="中文"></a>

## 中文

### 概述

**Wiki 文档生成器** 是一个为 AI 助手（如 Claude Code、Codex、Cursor）设计的技能，用于为任何代码库生成全面的 wiki 风格文档。它使用基于证据的引用方式，引用实际源文件并提供行号，同时支持 Mermaid 图表验证。

### 核心特性

- **基于证据的引用**：每个声明都有实际源文件引用和行号作为支撑
- **Mermaid 图表支持**：生成和验证流程图、时序图、类图等
- **增量更新**：仅重新生成发生变化的文档部分
- **多语言支持**：支持生成不同语言的文档（默认：en-US）
- **零外部依赖**：仅使用 AI 助手原生工具（Read、Glob、Bash、Write）

### 工作流阶段

| 阶段 | ID | 描述 |
|------|-----|-------------|
| 1 | `repo-scan` | 扫描仓库，收集上下文用于 TOC 设计 |
| 2 | `toc-design` | 设计目录结构 |
| 3 | `doc-write` | 生成文档页面 |
| 4 | `validate-docs` | 验证图表和文档结构 |
| 5 | `doc-summary` | 生成 SUMMARY.md 报告 |
| 6 | `incremental-sync` | 检测变更并增量更新 |

### 执行模式

| 模式 | 阶段 | 使用场景 |
|------|------|----------|
| **Automatic** | 1 → 2 → 3 → 4 → 5 | 全新文档生成的完整流程 |
| **Structure-only** | 1 → 2 | 仅生成 TOC 结构，不生成文档 |
| **TOC-based** | 3 → 4 → 5 | 基于现有 `toc.yaml` 生成文档 |
| **Incremental** | 6 → 3 → 4 → 5 | 代码变更后增量更新文档 |

### 项目结构

```
wiki/
├── SKILL.md                      # 主技能定义文件
├── README.md                     # 本文件
├── references/                   # 参考文档
│   ├── toc_schema.md             # TOC YAML 架构规范
│   ├── evidence_citation_policy.md  # 引用规则和格式
│   ├── page_template.md          # 页面结构和标记
│   ├── mermaid_policy.md         # Mermaid 图表规则
│   ├── doc_update_policy.md      # 文档更新策略
│   ├── validation_policy.md      # 验证规则
│   └── workflow/                 # 各阶段指令
│       ├── repo-scan.md          # 阶段 1：仓库扫描
│       ├── toc-design.md         # 阶段 2：TOC 设计
│       ├── doc-write.md          # 阶段 3：文档生成
│       ├── validate-docs.md      # 阶段 4：验证
│       ├── doc-summary.md        # 阶段 5：摘要生成
│       └── incremental-sync.md   # 阶段 6：增量更新
└── templates/
    └── toc.yaml.template         # TOC YAML 模板
```

### 输出结构

生成的文档遵循以下结构：

```
docs/wiki/
├── toc.yaml                      # 目录定义文件
├── 01_overview.md                # 文档页面
├── 02_architecture.md
├── 03_api.md
├── ...
├── SUMMARY.md                    # 文档摘要报告
└── _context/
    └── context_pack.json         # 用于增量更新的项目上下文
```

### TOC YAML 架构

`toc.yaml` 文件定义文档结构：

```yaml
project:
  name: "项目名称"
  description: "项目简要描述"
  repo_base_url: "https://github.com/owner/repo/blob"
  ref_commit_hash: "abc123..."
  updated_at: "2024-01-15"

pages:
  - id: project_01_overview
    title: "概述"
    filename: "01_overview.md"
    source_files:
      - "README.md"
      - "package.json"
    sections:
      - id: project_01_overview_introduction
        title: "简介"
        autogen: true
        diagrams_needed: false
```

### 引用格式

所有声明都有源文件引用作为支撑：

```markdown
Button 组件接受一个 `variant` 属性用于控制外观（[Button.tsx:15-20](url)）。
```

### 页面标记

生成的页面使用标记来实现安全的增量更新：

```markdown
<!-- PAGE_ID: project_01_overview -->
<!-- BEGIN:AUTOGEN section_id -->
自动生成的内容...
<!-- END:AUTOGEN section_id -->
```

### 支持的图表类型

| 类型 | 用途 |
|------|------|
| `flowchart` | 流程图、决策树、数据流 |
| `sequence` | 交互序列、API 调用 |
| `class` | 类关系、继承结构 |
| `state` | 状态机、状态转换 |
| `er` | 实体关系、数据库模式 |
| `gantt` | 项目时间线 |

### 使用方法

在 Claude Code 中调用此技能：

```
/wiki
```

或者在提示词中描述你的需求：

```
为这个项目生成文档
```

---

<a name="english"></a>

## English

### Overview

**Wiki Document Generator** is a skill for AI assistants (like Claude Code, Codex, Cursor) that generates comprehensive wiki-style documentation for any codebase. It uses evidence-based citations with actual source file references and supports Mermaid diagram validation.

### Key Features

- **Evidence-Based Citations**: Every claim is backed by actual source file references with line numbers
- **Mermaid Diagram Support**: Generate and validate flowcharts, sequence diagrams, class diagrams, and more
- **Incremental Updates**: Only regenerate changed documentation sections
- **Multi-Language Support**: Generate documentation in different languages (default: en-US)
- **Zero External Dependencies**: Uses only native AI assistant tools (Read, Glob, Bash, Write)

### Workflow Phases

| Phase | ID | Description |
|-------|-----|-------------|
| 1 | `repo-scan` | Scan repository to gather context for TOC design |
| 2 | `toc-design` | Design the Table of Contents structure |
| 3 | `doc-write` | Generate documentation pages |
| 4 | `validate-docs` | Validate diagrams and document structure |
| 5 | `doc-summary` | Generate SUMMARY.md report |
| 6 | `incremental-sync` | Detect changes and update incrementally |

### Execution Modes

| Mode | Phases | Use Case |
|------|--------|----------|
| **Automatic** | 1 → 2 → 3 → 4 → 5 | Full pipeline for new documentation |
| **Structure-only** | 1 → 2 | Generate TOC only, stop before docs |
| **TOC-based** | 3 → 4 → 5 | Generate docs from existing `toc.yaml` |
| **Incremental** | 6 → 3 → 4 → 5 | Update docs after code changes |

### Project Structure

```
wiki/
├── SKILL.md                      # Main skill definition file
├── README.md                     # This file
├── references/                   # Reference documentation
│   ├── toc_schema.md             # TOC YAML schema specification
│   ├── evidence_citation_policy.md  # Citation rules and formats
│   ├── page_template.md          # Page structure and markers
│   ├── mermaid_policy.md         # Mermaid diagram rules
│   ├── doc_update_policy.md      # Documentation update policies
│   ├── validation_policy.md      # Validation rules
│   └── workflow/                 # Phase-specific instructions
│       ├── repo-scan.md          # Phase 1: Repository scanning
│       ├── toc-design.md         # Phase 2: TOC design
│       ├── doc-write.md          # Phase 3: Document generation
│       ├── validate-docs.md      # Phase 4: Validation
│       ├── doc-summary.md        # Phase 5: Summary generation
│       └── incremental-sync.md   # Phase 6: Incremental updates
└── templates/
    └── toc.yaml.template         # TOC YAML template
```

### Output Structure

The generated documentation follows this structure:

```
docs/wiki/
├── toc.yaml                      # Table of Contents definition
├── 01_overview.md                # Documentation pages
├── 02_architecture.md
├── 03_api.md
├── ...
├── SUMMARY.md                    # Documentation summary report
└── _context/
    └── context_pack.json         # Project context for incremental updates
```

### TOC YAML Schema

The `toc.yaml` file defines the documentation structure:

```yaml
project:
  name: "ProjectName"
  description: "Brief project description"
  repo_base_url: "https://github.com/owner/repo/blob"
  ref_commit_hash: "abc123..."
  updated_at: "2024-01-15"

pages:
  - id: project_01_overview
    title: "Overview"
    filename: "01_overview.md"
    source_files:
      - "README.md"
      - "package.json"
    sections:
      - id: project_01_overview_introduction
        title: "Introduction"
        autogen: true
        diagrams_needed: false
```

### Citation Format

All claims are backed by source citations:

```markdown
The Button component accepts a `variant` prop ([Button.tsx:15-20](url)).
```

### Page Markers

Generated pages use markers for safe incremental updates:

```markdown
<!-- PAGE_ID: project_01_overview -->
<!-- BEGIN:AUTOGEN section_id -->
Auto-generated content here...
<!-- END:AUTOGEN section_id -->
```

### Supported Diagram Types

| Type | Use Case |
|------|----------|
| `flowchart` | Process flows, decision trees, data flow |
| `sequence` | Interaction sequences, API calls |
| `class` | Class relationships, inheritance |
| `state` | State machines, status transitions |
| `er` | Entity relationships, database schema |
| `gantt` | Project timelines |

---

## License / 许可证

MIT License
