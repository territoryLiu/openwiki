---
name: wiki
description: Generating comprehensive wiki-style documentation for any codebase. This skill can be used when 1. Generating documentation for a new project, 2. Update existing documentation after code changes, 3. Create or refine a wiki TOC for a codebase, 4. Obtain a comprehensive overview of an unfamiliar project.
---

**Your response MUST be written in the language specified by the locale code (default: en-US). This is crucial.**

# Wiki Document Generator

This skill provides a complete workflow for generating and updating wiki-style documentation for any codebase, with evidence-based citations and Mermaid diagram validation.

## Native Tools

This skill uses standard AI assistant tools - **no external dependencies required**:

| Tool | Claude Code | Purpose |
|------|-------------|---------|
| File Read | `Read` | Read files with line numbers for citations |
| File Search | `Glob` | Find files matching patterns |
| File Write | `Write` | Generate documentation files |
| File Edit | `Edit` | Update existing documentation |
| Shell | `Bash` | Git operations (diff, log, rev-parse) |

**Fallback for `tree` command** (if not available):
```bash
# Cross-platform (git)
git ls-files

# Unix/Mac
find . -type f -name "*.py" | head -100

# Windows PowerShell
Get-ChildItem -Recurse -File | Select-Object -First 100
```

## Workflow

**Fully execute this workflow until completion. Do not ask for user confirmation.**

**IMPORTANT: If subagent is supported, spawn `deepwiki:workflow-runner` subagent with the corresponding `Phase_id` to execute each phase according to execution mode, otherwise read each phase spec file and reference file to understand the requirement and execute sequentially.**

### Workflow Phase Definitions

| Phase | Phase_id | Phase_spec | Purpose |
|-------|---------|-----------|---------|
| 1 | `repo-scan` | `/references/workflow/repo-scan.md` | Scan repository to get context for toc design |
| 2 | `toc-design` | `/references/workflow/toc-design.md` | Design TOC structure |
| 3 | `doc-write` | `/references/workflow/doc-write.md` | Generate documentation pages |
| 4 | `validate-docs` | `/references/workflow/validate-docs.md` | Validate diagrams and structure |
| 5 | `doc-summary` | `/references/workflow/doc-summary.md` | Generate SUMMARY.md report |
| 6 | `incremental-sync` | `/references/workflow/incremental-sync.md` | Detect TOC and source changes |

### Execution Modes and Phases

| Mode | Phases | Description |
|------|--------|-------------|
| **Automatic** | 1 → 2 → 3 → 4 → 5 | Full pipeline for new documentation |
| **Structure-only** | 1 → 2 | Generate TOC only, stop before docs |
| **TOC-based** | 3 → 4 → 5 | Generate docs from existing `toc.yaml` |
| **Incremental** | 6 → 3 → 4 → 5 | Update docs after code changes |

### Subagent Invocation

**This section is available only when subagent is supported**

When spawning subagent, pass the required inputs:

```
subagent: deepwiki:workflow-runner
inputs:
  phase_id: "{phase_id}"
  phase_spec: "absolute path of {phase_spec}"
  repo_path: "{repo_path}"
  output_dir: "{output_dir}"
  toc_file: "{toc_file}"
  page_id: "{page_id}"
  language: "{language}"
```

### Parallel Execution for doc-write (Phase 3)

**This section is available only when subagent is supported**

If subagent is supported, the `doc-write` phase should be executed parallelly to improve performance. Spawn multiple subagents in **foreground** - one per page:

```
# Parse toc.yaml to get list of pages
pages = parse_toc("{toc_file}")

# Spawn one subagent per page IN PARALLEL
for each page in pages:
  spawn subagent: deepwiki:workflow-runner
    inputs:
      phase_id: "doc-write"
      phase_spec: "/references/workflow/doc-write.md"
      repo_path: "{repo_path}"
      output_dir: "{output_dir}"
      toc_file: "{toc_file}"
      page_id: "{page.id}"
      language: "{language}"

# Wait for all subagents to complete
# Then proceed to phase 4 (validate-docs)
```

**Parallel Execution Rules**:
- Each subagent generates exactly one page (specified by `page_id`)
- All subagents should run at foreground, NOT background
- Wait for ALL page subagents to complete before proceeding to phase 4
- If any subagent fails, re-spawn a new subagent to finish the page generation

## Output Structure

After successful generation, the output directory will contain:

```
{output_dir}/
├── toc.yaml                        # Table of Contents definition
├── _context/
│   └── context_pack.json           # Project context (from repo-scan)
├── _reports/
│   ├── structure_validation.json   # Document structure validation
│   ├── mermaid_invalid.json        # Invalid Mermaid blocks (if any)
│   └── SUMMARY.md                  # Generation summary report
├── 01_overview.md                  # Page 1
├── 02_architecture.md              # Page 2
└── ...                             # More pages
```

## References

All reference documents are in the `/references` directory:

| File | Purpose |
|------|---------|
| `toc_schema.md` | TOC YAML schema specification |
| `page_template.md` | Page structure and marker conventions |
| `evidence_citation_policy.md` | Citation format and requirements |
| `mermaid_policy.md` | Mermaid diagram rules and best practices |
| `validation_policy.md` | Document validation rules |
| `output_structure.md` | Expected output structure |
| `doc_update_policy.md` | Incremental update algorithm |

## Key Principles

### 1. Evidence-Based Writing

Every major claim MUST be backed by citations from actual source files:

```markdown
The Button component accepts a `variant` prop that controls its appearance ([Button.tsx:15-20](url)).
```

**Rules**:
- Never guess or infer information
- Never make up line numbers
- Only describe functionality present in source code
- If information is missing, state it explicitly

### 2. Stable Markers

Every page MUST have stable markers for incremental updates:

```markdown
<!-- PAGE_ID: project_01_overview -->
...
<!-- BEGIN:AUTOGEN project_01_overview_section1 -->
{generated content}
<!-- END:AUTOGEN project_01_overview_section1 -->
```

### 3. Mermaid Diagram Rules

Always follow these rules for Mermaid diagrams:
- Use `graph TD` (top-down), never `graph LR`
- Quote ALL node text: `A["User Input"]`
- No special characters in subgraph names
- Never include source citations inside diagrams

### 4. Language Support

The skill respects the `language` field in TOC:
- Default: `en-US` (English)
- Set `language: zh-CN` for Chinese output
- All generated content follows the specified language

## Integration with Existing Docs

### Scenario 1: No Existing Docs

Create the full `{output_dir}/` structure with all pages.

### Scenario 2: Existing Wiki Docs

Use **Incremental Mode** to:
1. Detect changes in source files (via git diff)
2. Update only affected sections
3. Preserve manual content outside AUTOGEN markers

### Scenario 3: Consolidating Old Docs

When consolidating existing documentation:
1. Analyze existing documentation structure
2. Map old docs to new wiki pages
3. Extract unique content not covered by wiki
4. Merge into appropriate wiki pages or keep as separate reference docs

## Common Patterns

### Project Types and Recommended Pages

| Project Type | Recommended Pages |
|--------------|-------------------|
| Web App (Full-stack) | Overview, Architecture, Frontend, Backend/API, Data Model, Configuration |
| Web App (Frontend) | Overview, Architecture, Components, State Management, Routing, Testing |
| CLI Tool | Overview, Installation, Commands, Configuration, Development |
| Library/SDK | Overview, Quick Start, API Reference, Examples, Contributing |
| Data Pipeline | Overview, Architecture, Data Sources, Processing, Storage, Configuration |
| Microservices | Overview, Architecture, Services, API Contracts, Deployment |

### Section Design Guidelines

Each page should have 3-5 top-level sections:

1. **Overview Section**: Introduction, purpose, key features
2. **Core Sections**: Main functionality (2-3 sections with diagrams)
3. **Reference Section**: Configuration, API tables, examples

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| No PAGE_ID marker | Add `<!-- PAGE_ID: {id} -->` at file start |
| Missing AUTOGEN markers | Add `<!-- BEGIN:AUTOGEN {id} -->` and `<!-- END:AUTOGEN {id} -->` |
| Mermaid parse error | Quote all node text, check diagram type |
| Broken source links | Verify `repo_base_url` and `ref_commit_hash` |
| Outdated documentation | Run incremental update mode |

### Validation Errors

After generation, check `_reports/structure_validation.json`:
- `is_valid: true` → All checks passed
- `is_valid: false` → Review errors and fix

## Quick Start

To generate documentation for a project:

1. Invoke the skill with default mode (Automatic)
2. The skill will scan the repo, design TOC, generate pages, and validate
3. Review `SUMMARY.md` for generation status
4. Check individual pages for content quality

To update existing documentation:

1. Use Incremental mode to detect changes
2. Only affected sections will be regenerated
3. Manual content outside markers is preserved
