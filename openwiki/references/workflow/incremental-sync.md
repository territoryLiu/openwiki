# Phase: incremental-sync (Phase 6)

## Goal

Collect the context needed to update existing docs safely after changes:
- Phase A: detect TOC structure changes
- Phase B: detect source code changes relevant to the TOC mappings

This step does not rewrite docs; it produces change context that `doc-write` uses to regenerate only affected pages/sections.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repo_path` | Yes | - | Absolute repository path |
| `output_dir` | No | `docs/wiki` | Documentation output directory |
| `doc_dir` | No | `{output_dir}` | Documentation directory containing existing `.md` |
| `toc_file` | No | `{output_dir}/toc.yaml` | Existing TOC |
| `target_commit` | No | `HEAD` | Target commit for change detection |
| `include_diff` | No | `false` | Whether to include patch data in update context |
| `diff_context` | No | `0` | Diff context lines when `include_diff=true` |

## Outputs

| Path | Description |
|------|-------------|
| `{output_dir}/_context/sync_context.json` | TOC sync result (Phase A) |
| `{output_dir}/_context/update_context.json` | Source update context (Phase B) |

## References

- `../references/doc_update_policy.md`

## Native Tools

Use AI assistant native tools - no external dependencies required:

### Phase A: TOC Sync

1. **Read TOC file**: Read `{toc_file}`
2. **List existing markdown files**: Search for `*.md` in `{doc_dir}`
3. **Read each markdown file**: Check PAGE_ID and section markers
4. **AI compares** TOC expectations vs actual files

### Phase B: Source Update Context

1. **Get changed files**: Run shell command `git diff --name-status`
2. **Get commit hash**: Run shell command `git rev-parse HEAD`
3. **Read TOC file**: Read `{toc_file}` to map files to pages/sections
4. **Get detailed diff** (optional): Run shell command `git diff`
5. **AI maps** changes to affected pages/sections

## Workflow

### Phase A: TOC Structure Sync

0. Read `/references/doc_update_policy.md` to understand document update requirement.

1. **Read TOC file** using file read tool:
   ```
   Read file at path: "{toc_file}"
   ```
   - Extract all page definitions with their page_ids
   - Extract all section definitions with their section_ids

2. **List existing markdown files** using file search tool:
   ```
   Search for files matching: "*.md" in path: "{doc_dir}"
   ```

3. **Read each markdown file** and check:
   - PAGE_ID marker at the top
   - BEGIN:AUTOGEN / END:AUTOGEN markers for each section

4. **Compare TOC vs actual files**:
   - **Added pages**: Pages in TOC but no corresponding .md file
   - **Removed pages**: .md files with no matching TOC entry
   - **Modified pages**: Files where PAGE_ID exists but section markers differ from TOC
   - **Added sections**: Sections in TOC but no AUTOGEN marker in file
   - **Removed sections**: AUTOGEN markers in file but no TOC entry

5. **Determine sync status**:
   - `up_to_date`: No changes detected
   - `sync_needed`: Some pages/sections need update
   - `full_rebuild_needed`: Major structural changes (e.g., missing TOC file, many pages missing)

6. **Write sync context** to `{output_dir}/_context/sync_context.json`:
   ```json
   {
     "status": "sync_needed|up_to_date|full_rebuild_needed",
     "changes": {
       "added_pages": ["04_new_page"],
       "removed_pages": ["03_old_page"],
       "modified_pages": ["01_overview"],
       "added_sections": [{"page": "01_overview", "section": "new_section"}],
       "removed_sections": []
     },
     "recommendation": "Regenerate modified pages and added pages"
   }
   ```

### Phase B: Source Code Change Detection

1. **Get base commit from TOC**:
   - Read TOC file and extract `ref_commit_hash`
   - If not present, use initial commit or ask user

2. **Get changed files** using shell commands:
   ```bash
   # Get list of changed files with status
   git -C "{repo_path}" diff --name-status {base_commit} {target_commit}

   # Get current commit hash
   git -C "{repo_path}" rev-parse HEAD
   ```

3. **Parse change status**:
   - `A` = Added
   - `M` = Modified
   - `D` = Deleted
   - `R` = Renamed

4. **Map changes to TOC pages/sections**:
   - Read TOC file to get `source_files` mappings
   - For each changed file, find which page/section references it
   - Build affected_pages list

5. **Get detailed diff** (if `include_diff=true`) using Bash:
   ```bash
   git -C "{repo_path}" diff -U{diff_context} {base_commit} {target_commit} -- {file_path}
   ```

6. **Write update context** to `{output_dir}/_context/update_context.json`:
   ```json
   {
     "base_commit": "abc123",
     "target_commit": "def456",
     "affected_pages": [
       {
         "page_id": "myapp_01_overview",
         "filename": "01_overview.md",
         "affected_sections": ["myapp_01_overview_intro"],
         "changed_files": ["src/main.ts"],
         "change_details": {
           "src/main.ts": {
             "status": "modified",
             "diff": "..."
           }
         }
       }
     ],
     "unaffected_pages": ["myapp_02_architecture"]
   }
   ```

### Optional: Section-Specific Diff

For detailed section updates, get focused diffs for specific files:

```bash
# Get diff for specific files
git -C "{repo_path}" diff -U3 {base_commit} {target_commit} -- path/to/a path/to/b
```

## Decision Flow

1. Run Phase A (TOC sync):
   - If status is `full_rebuild_needed`, stop and recommend rerunning full generation
   - If status is `up_to_date` and no code changes, no action needed

2. Run Phase B (Source update) if:
   - Phase A shows `sync_needed`, OR
   - User explicitly requested code change detection

3. Hand off to `doc-write`:
   - Regenerate only affected pages/sections
   - Do not touch manual sections or content outside AUTOGEN markers

## Validation

- `{output_dir}/_context/sync_context.json` exists and is valid JSON
- `{output_dir}/_context/update_context.json` exists and is valid JSON
- Each output explicitly lists changes or states "no changes"
