# Phase: doc-write (Phase 3)

## Goal

Generate evidence-based wiki pages from `{toc_file}` with:
- stable PAGE_ID markers
- AUTOGEN markers for all generated sections
- strict source citations with line numbers
- Mermaid diagrams where requested by the TOC

## References
- `../references/toc_schema.md`: schema of toc file for parsing
- `../references/page_template.md`: format of wiki page you shoud generate
- `../references/evidence_citation_policy.md`: citation requirement for generating wiki page
- `../references/mermaid_policy.md`: mermaid requirement for generating wiki page

## Native Tools

Use AI assistant native tools - no external dependencies required:

### File Read Tool

Read source files with line numbers for accurate citations. Most AI assistants show line numbers in file output.

**Usage**:
```
Read file at path: "{repo_path}/src/main.ts"
```

The output format shows line numbers like:
```
     1→import { App } from './app';
     2→...
```

### File Search/Glob Tool

Expand glob patterns to find matching files.

**Usage**:
```
Search for files matching: "src/**/*.ts" in path: "{repo_path}"
```

**Glob Pattern Support**:
- `*` matches any characters except `/`
- `**` matches any characters including `/` (recursive)
- `?` matches a single character
- Example: `src/**/*.cs` matches all `.cs` files under `src/` recursively

**Output**: Returns list of matching file paths, which can then be read with the file read tool.

## Workflow

For each page in toc.yaml, generate comprehensive Markdown documentation using project context and on-demand file loading.

**For each page:**
1. Parse TOC Structure and read page sections:
   - Read page definition from YAML
   - Extract page-level source_files (if defined)
   - Extract all sections with their titles, autogen flags, and optional source_files

2. Collect Evidence for each section (recursively):
Pseudo Code:
```
function process_page(page):
    # Get page-level source files (shared by all sections)
    page_source_files = page.get('source_files', [])

    for each section in page.sections:
        process_section(section, page_source_files, heading_level=2)

function process_section(section, page_source_files, heading_level):
    if section.autogen == true:
        # Merge page-level and section-level source files
        section_source_files = section.get('source_files', [])
        all_source_files = page_source_files + section_source_files

        # Resolve glob patterns using file search tool
        resolved_paths = []
        for pattern in all_source_files:
            if pattern contains '*' or '?':
                matches = search_files(pattern, repo_path)
                resolved_paths.extend(matches)
            else:
                resolved_paths.append(pattern)

        # Collect files for this section using file read tool
        # Line numbers are automatically included
        for file_path in resolved_paths:
            read_file(file_path)

        # **Note**:
        # source_files are the PRIMARY reference files. If you find that
        # understanding the code requires additional context (e.g., base classes,
        # interfaces, or referenced types), you MAY use file read tool
        # to read additional source files as needed.

    # Process nested sections recursively (pass page_source_files down)
    if section.sections exists:
        for each subsection in section.sections:
            process_section(subsection, page_source_files, heading_level + 1)
```

Generate section content based on the source files read:
- Add source citations strictly following `/references/evidence_citation_policy.md`
- Generate mermaid diagrams where `diagrams_needed: true`
- Repeat for nested sections

3. Generate Page Content

Combine all sections into the final page:
- Output format should strictly follow `/references/page_template.md`
- Ensure each section cites from its specific `source_files`
- Output Markdown files in `{output_dir}/`
