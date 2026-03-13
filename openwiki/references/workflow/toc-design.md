# Phase: toc-design (Phase 2)

## Goal

Design a logical, comprehensive Table of Contents (TOC) structure based on project analysis.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repo_path` | Yes | - | Absolute repository path |
| `output_dir` | No | `docs/wiki` | Documentation output directory |
| `context_pack` | No | `{output_dir}/_context/context_pack.json` | Context JSON from `repo-scan` |
| `language` | No | `en-US` | Output language/locale |
| `existing_docs` | No | - | Paths to existing documentation to consider |

## Outputs

| Path | Description |
|------|-------------|
| `{output_dir}/toc.yaml` | TOC definition following schema |

## Native Tools

Use AI assistant native tools - no external dependencies required:

### File Read Tool
Read source files directly. Most AI assistants show line numbers in output.

### File Search/Glob Tool
Expand glob patterns to find files.

## Workflow

### Step 1: Analyze Context Pack

Read and analyze `{output_dir}/_context/context_pack.json`:

```json
{
  "structure": {
    "tree": "...",
    "file_count": 42,
    "languages": {"Python": 25, "TypeScript": 10}
  },
  "readme": {
    "content": "..."
  },
  "git": {
    "remote_url": "https://github.com/...",
    "commit_hash": "abc123..."
  }
}
```

Extract:
- **Project type**: Web app, library, CLI tool, data pipeline, etc.
- **Primary languages**: Python, TypeScript, etc.
- **Project name**: From README or git remote
- **Key features**: From README description

### Step 2: Identify Source Directories

Analyze directory structure to identify main source directories:

```
repo/
├── src/           → Main source code
├── lib/           → Library code
├── core/          → Core business logic
├── api/           → API endpoints
├── components/    → UI components
├── services/      → Service layer
├── models/        → Data models
├── utils/         → Utilities
└── config/        → Configuration
```

### Step 3: Read Representative Files

For each main directory, read 2-3 representative files to understand:
- What classes/modules exist
- What they do
- How they relate to each other

**DO NOT** simply map folder names to pages. Instead, understand logical groupings.

Example logical groupings:
- `Engine.cs`, `Renderer.cs`, `Physics.cs` → "Core Systems" page
- `Button.tsx`, `Toggle.tsx`, `Slider.tsx` → "UI Components" page
- `api/users.ts`, `api/products.ts` → "API Reference" page

### Step 4: Check Existing Documentation

If `existing_docs` parameter provided or existing docs found in `docs/`:

1. Read existing documentation files
2. Extract unique content not covered by auto-generation:
   - Manual notes and tips
   - Deployment guides
   - Troubleshooting information
   - Usage examples
3. Design TOC to incorporate or reference existing content
4. Note what content should be preserved vs regenerated

### Step 5: Design Page Structure

Based on project type and analysis, design pages:

| Project Type | Recommended Pages |
|--------------|-------------------|
| Web App (Full-stack) | Overview, Architecture, Frontend, Backend/API, Data Model, Configuration |
| Web App (Frontend) | Overview, Architecture, Components, State Management, Routing, Testing |
| CLI Tool | Overview, Installation, Commands, Configuration, Development |
| Library/SDK | Overview, Quick Start, API Reference, Examples, Contributing |
| Data Pipeline | Overview, Architecture, Data Sources, Processing, Storage, Configuration |
| Microservices | Overview, Architecture, Services, API Contracts, Deployment |
| AI/ML Project | Overview, Architecture, Models, Training, Inference, Configuration |
| Game Engine | Overview, Architecture, Core Systems, Rendering, Physics, Scripting |

### Step 6: Design Section Structure

For each page, design 3-4 sections:

```
Page: Architecture
├── Section: Overview (architecture overview)
├── Section: Components (component diagram, relationships)
├── Section: Data Flow (sequence diagrams)
└── Section: Design Decisions (key architectural choices)
```

Section design guidelines:
- Each section should focus on ONE aspect
- Add `diagrams_needed: true` where visual representation helps
- Use `description` field to guide content generation
- Set `autogen: true` for auto-generated sections

### Step 7: Map Source Files to Pages

For each page, map relevant source files:

```yaml
source_files:
  - "src/core/*.py"          # Core module
  - "src/api/**/*.ts"        # All API files
  - "README.md"              # Project readme
```

Guidelines:
- Use glob patterns for flexibility
- Include related test files for development guides
- Include configuration files for setup sections
- Don't include too many files (max 10-15 per page)

### Step 8: Generate TOC YAML

Read `/references/toc_schema.md` for schema, then generate:

```yaml
project:
  name: "ProjectName"
  description: "Brief description from README"
  repo_base_url: "https://github.com/owner/repo/blob"
  ref_commit_hash: "abc123..."  # From context_pack
  language: "zh-CN"  # Set based on project or parameter
  updated_at: "2024-01-15"

pages:
  - id: project_01_overview
    title: "Overview"
    filename: "01_overview.md"
    description: "Project introduction and key features"
    source_files:
      - "README.md"
      - "package.json"
      - "pyproject.toml"
    sections:
      - id: project_01_overview_intro
        title: "Introduction"
        autogen: true
        diagrams_needed: false
        diagram_types: []
      - id: project_01_overview_features
        title: "Key Features"
        autogen: true
        diagrams_needed: true
        diagram_types: ["flowchart"]
    related_pages:
      - project_02_architecture
```

## Validation Rules

Before writing TOC, validate:

- [ ] All page IDs are unique
- [ ] All section IDs are unique
- [ ] Each page has at least 1 `source_files` entry
- [ ] Nesting depth is at most 3 levels
- [ ] `ref_commit_hash` is present
- [ ] `language` is set appropriately

## Language Guidelines

Based on `language` parameter:

| Language Code | Output Language | Section Titles |
|---------------|-----------------|----------------|
| `en-US` | English | Introduction, Features, Architecture |
| `zh-CN` | Chinese (Simplified) | 概述, 功能特性, 系统架构 |
| `ja-JP` | Japanese | 概要, 機能, アーキテクチャ |

All generated content (section titles, descriptions, diagram labels) follows the specified language.

## Best Practices

### DO:
- Understand the codebase before designing pages
- Group related functionality logically
- Use descriptive section IDs: `project_01_overview_features` not `s1`
- Add `description` field for sections needing guidance
- Consider diagrams for architecture, data flow, API sequences
- Include configuration files in relevant pages

### DON'T:
- Simply map folder names to pages
- Create too many pages (keep under 15 for most projects)
- Create too few sections per page (aim for 3-4)
- Overlap source files between pages unnecessarily
- Skip the `related_pages` field

## Example TOC Designs

### Example 1: Full-stack Web App

```yaml
project:
  name: "Greater"
  description: "AI-powered stock analysis platform with multi-LLM support"
  language: "zh-CN"
  repo_base_url: "https://github.com/territoryLiu/greater/blob"
  ref_commit_hash: "abc123..."

pages:
  - id: greater_01_overview
    title: "项目概述"
    filename: "01_overview.md"
    source_files:
      - "README.md"
      - "main.py"
      - "docs/README.md"
    sections:
      - id: greater_01_overview_intro
        title: "项目简介"
        autogen: true
        diagrams_needed: true
        diagram_types: ["flowchart"]
      - id: greater_01_overview_features
        title: "核心特性"
        autogen: true
        diagrams_needed: false
      - id: greater_01_overview_tech
        title: "技术栈"
        autogen: true
        diagrams_needed: false
      - id: greater_01_overview_structure
        title: "项目结构"
        autogen: true
        diagrams_needed: false
    related_pages:
      - greater_02_architecture
      - greater_06_api_reference

  - id: greater_02_architecture
    title: "系统架构"
    filename: "02_architecture.md"
    source_files:
      - "greater/core/*.py"
      - "greater/agent/*.py"
      - "greater/api/app.py"
    sections:
      - id: greater_02_arch_overview
        title: "架构概览"
        autogen: true
        diagrams_needed: true
        diagram_types: ["flowchart"]
      - id: greater_02_arch_layers
        title: "架构分层"
        autogen: true
        diagrams_needed: true
        diagram_types: ["flowchart"]
    related_pages:
      - greater_01_overview
      - greater_03_agent_system
```

### Example 2: Python Library

```yaml
project:
  name: "MyLib"
  description: "A Python library for data processing"
  language: "en-US"
  repo_base_url: "https://github.com/user/mylib/blob"
  ref_commit_hash: "def456..."

pages:
  - id: mylib_01_overview
    title: "Overview"
    filename: "01_overview.md"
    source_files:
      - "README.md"
      - "pyproject.toml"
      - "src/mylib/__init__.py"
    sections:
      - id: mylib_01_overview_intro
        title: "Introduction"
        autogen: true
        diagrams_needed: false
      - id: mylib_01_overview_installation
        title: "Installation"
        autogen: true
        diagrams_needed: false
```
