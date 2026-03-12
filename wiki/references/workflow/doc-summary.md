# Step: doc-summary (Phase 5)

## Goal

Generate documentation summary report (`SUMMARY.md`) with:
- Generation status (pages/sections completion)
- Citation statistics and source coverage
- Diagram count summary
- Issues from validation reports (if available)

## Native Tools

Use AI assistant native tools - no external dependencies required:

### Required Operations

1. **Read TOC file**: Read `{toc_file}` to enumerate expected pages and sections
2. **List markdown files**: Search for `*.md` in `{doc_dir}` to find generated pages
3. **Read each markdown file**: Read each .md file to extract:
   - PAGE_ID markers
   - Section markers (BEGIN:AUTOGEN / END:AUTOGEN)
   - Citations (format: `[text](path:line)`)
   - Mermaid diagrams (```mermaid blocks)
4. **Read validation reports** (if present):
   - Read `{output_dir}/_reports/structure_validation.json`
   - Read `{output_dir}/_reports/mermaid_invalid.json`

## Workflow

### 1. Collect Data

**Parse TOC** using file read tool:
```
Read file at path: "{toc_file}"
```
- Extract all page definitions with page_id
- Extract all section definitions with section_id
- Extract ref_commit_hash (if present)

**Scan generated docs** using file search + file read:
```
Search for files matching: "*.md" in path: "{doc_dir}"
Read each file found
```

For each markdown file, extract:
- PAGE_ID from top marker
- Section count from AUTOGEN markers
- Citations using pattern: `[text](source:line)` or `[text](source)`
- Mermaid diagrams from ` ```mermaid ` blocks

**Read validation reports** (optional):
```
Read file at path: "{output_dir}/_reports/structure_validation.json"
Read file at path: "{output_dir}/_reports/mermaid_invalid.json"
```

### 2. Generate Statistics

Calculate:
- **Pages**: Expected vs Actual count
- **Sections**: Expected vs Actual per page
- **Citations**: Total count, files cited
- **Diagrams**: Total count, valid count (if mermaid report exists)
- **Source Coverage**: Files in TOC vs files actually cited

### 3. Write SUMMARY.md

Generate the report at `{output_dir}/_reports/SUMMARY.md`:

```markdown
# Wiki Documentation Summary

Generated: {timestamp}
Repository: {repo_name}
Commit: `{ref_commit_hash}`

## Generation Status

**Overall Status**: ✅ Complete / ⚠️ Incomplete / ❌ Has Errors

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Pages | {n} | {n} | ✅/❌ |
| Sections | {n} | {n} | ✅/⚠️ |
| Citations | - | {n} | ✅/⚠️ |
| Diagrams | {n} | {valid} valid | ✅/⚠️ |

## Page Details

| Page | Title | Sections | Citations | Diagrams | Status |
|------|-------|----------|-----------|----------|--------|
| 01_overview.md | Overview | 4/4 | 49 | 2 | ✅ |
| ... | ... | ... | ... | ... | ... |

## Source Coverage

### Covered Files
- `src/main.ts` - cited in 01_overview.md, 02_architecture.md

### Uncovered Files
- `src/utils/helper.ts` - in TOC but never cited

## Issues

### Errors (Must Fix)
- **{file}**: {error_message}

### Warnings
- **{file}**: {warning_message}

### Recommendations
- {recommendation}
```

### 4. Review Summary

Check the generated `SUMMARY.md` for:
- **Overall Status**: Should be "✅ Complete" for successful generation
- **Page Details**: All pages should show expected sections count
- **Source Coverage**: Review uncovered files for potential gaps
- **Issues**: Address any errors before considering documentation complete

## Status Indicators

| Status | Meaning |
|--------|---------|
| ✅ Complete | All pages/sections generated, no errors |
| ⚠️ Incomplete | Some sections missing or has warnings |
| ❌ Has Errors | Validation errors present |

## Error Handling

- **Missing toc_file**: Report error in SUMMARY.md
- **Missing doc_dir**: Report error in SUMMARY.md
- **Missing validation reports**: Continue without error/warning data
- **Missing pages**: Report in Page Details with ❌ status
