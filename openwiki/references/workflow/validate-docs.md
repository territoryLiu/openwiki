# Step: validate-docs (Phase 4)

## Goal

Validate the generated documentation and apply safe fixes:
- Mermaid diagrams have valid syntax (validated by LLM)
- Document structure is consistent (PAGE_ID markers, AUTOGEN markers, no overlaps)

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `doc_dir` | No | `{output_dir}` | Directory containing generated `.md` docs |
| `output_dir` | No | `docs/wiki` | Base output dir (for `_reports/`) |
| `toc_file` | No | `{output_dir}/toc.yaml` | TOC file used to validate expected pages/sections |
| `repo_path` | No | `.` | Repository root path |

## Outputs

| Path | Description |
|------|-------------|
| `{output_dir}/_reports/mermaid_invalid.json` | Invalid Mermaid blocks report |
| `{output_dir}/_reports/structure_validation.json` | Document structure validation report |
| `{doc_dir}/*.md` | In-place fixes (Mermaid blocks and/or missing structural markers only) |

## Native Tools

Use AI assistant native tools - no external dependencies required:

### Document Structure Validation

Use file read tool to read files and AI to validate:

1. **Read TOC file**: Read `{toc_file}`
2. **Read all markdown files**: Search for `*.md` in `{doc_dir}`, then read each file
3. **AI validates**:
   - PAGE_ID markers present and correct
   - AUTOGEN markers present and matching
   - Internal links valid
   - TOC alignment (expected pages exist)

### Mermaid Validation

Use file read tool to extract Mermaid blocks and AI to validate syntax:

1. **Read markdown files**: Search for `*.md` in `{doc_dir}`, then read each file
2. **Extract Mermaid blocks**: AI identifies ` ```mermaid ` code blocks
3. **AI validates** Mermaid syntax for common issues:
   - Unclosed brackets
   - Invalid arrow syntax
   - Unknown diagram types
   - Missing quotes around special characters

## Workflow

### 1. Document Structure Validation

1) **Read TOC file** using file read tool:
   - Parse TOC to extract expected page_ids and section_ids
   - List all expected pages and their sections

2) **Read all markdown files** using file search + file read:
   ```
   Search for files matching: "*.md" in path: "{doc_dir}"
   Read each file found
   ```

3) **Validate each file** against TOC:

   **Check PAGE_ID**:
   - Every .md file should start with `<!-- PAGE_ID: {expected_id} -->`
   - PAGE_ID should match the filename mapping in TOC
   - Report: missing, incorrect, or duplicate PAGE_IDs

   **Check AUTOGEN markers**:
   - Each autogen section should have `<!-- BEGIN:AUTOGEN {section_id} -->`
   - Each autogen section should have matching `<!-- END:AUTOGEN {section_id} -->`
   - Report: missing BEGIN, missing END, mismatched, or orphaned markers

   **Check internal links**:
   - All `[text](#anchor)` links should point to existing headings
   - All `[text](page.md#anchor)` links should resolve
   - Report: broken internal links

   **Check TOC alignment**:
   - All pages in TOC should have corresponding .md files
   - All .md files should be listed in TOC
   - Report: missing pages, extra files

4) **Fix issues** where possible:
   - Add missing PAGE_ID markers
   - Add missing AUTOGEN markers
   - Fix mismatched section_id to match TOC
   - Do NOT rewrite page content

5) **Generate validation report** and write to `{output_dir}/_reports/structure_validation.json`:

   ```json
   {
     "summary": {
       "pages_validated": 5,
       "pages_missing": 0,
       "sections_validated": 20,
       "sections_missing": 2,
       "total_errors": 3,
       "total_warnings": 1,
       "is_valid": false
     },
     "errors": [
       {
         "file": "01_overview.md",
         "line": 1,
         "severity": "error",
         "category": "page_id",
         "message": "Missing PAGE_ID marker",
         "fix_hint": "Add <!-- PAGE_ID: project_01_overview --> at the start"
       }
     ],
     "warnings": []
   }
   ```

**Issue Categories**:

| Category | Description |
|----------|-------------|
| `page_id` | PAGE_ID marker missing or incorrect |
| `autogen` | AUTOGEN marker issues (missing, mismatched, orphaned) |
| `structure` | Basic structure issues (H1 headings, file size) |
| `link` | Internal link issues (broken or undefined targets) |
| `toc` | TOC alignment issues (missing pages, extra files) |

### 2. Mermaid Diagram Validation

1) **Extract Mermaid blocks** from markdown files:
   - Read each .md file
   - Find all ` ```mermaid ` code blocks
   - Record file path, start line, end line, and code content

2) **Validate each diagram** using AI analysis:
   - Check for valid diagram type (graph, sequenceDiagram, classDiagram, etc.)
   - Check for syntax errors:
     - Unclosed brackets `[`, `(`, `{`
     - Invalid arrow syntax
     - Missing quotes around node text with special characters
     - Invalid keywords

3) **For invalid diagrams** (max 3 fix attempts per diagram):
   - Use `mermaid_policy.md` to understand correct syntax
   - Fix the diagram and write updated file
   - Re-validate

4) **If still invalid after 3 attempts**:
   - Comment out the diagram block
   - Add TODO comment noting the error

5) **Generate validation report** and write to `{output_dir}/_reports/mermaid_invalid.json`:

   ```json
   {
     "invalid_blocks": [
       {
         "file_path": "01_overview.md",
         "code": "graph TD\n    A[User] --> B",
         "start_line": 45,
         "end_line": 55,
         "error_message": "Parse error on line 2",
         "error_type": "syntax_error",
         "error_line": 2,
         "fix_hint": "Add quotes around node text: A[\"User\"]"
       }
     ],
     "total_invalid": 2,
     "total_scanned": 10,
     "files_affected": 1
   }
   ```

**Error Types**:

| Type | Description | Common Fix |
|------|-------------|------------|
| `lexical_error` | Unrecognized text/characters | Quote node text with special characters |
| `syntax_error` | General syntax issues | Check diagram type and arrow syntax |
| `node_error` | Node definition problems | Balance brackets, quote labels |
| `edge_error` | Arrow/edge problems | Use valid arrows (-->, ---) |

**Safe auto-fixes allowed**:
  - Add missing PAGE_ID/AUTOGEN markers
  - Fix mismatched section_id to match TOC
  - Fix Mermaid syntax issues
  - Do NOT rewrite page content
