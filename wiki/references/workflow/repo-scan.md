# Phase: repo-scan (Phase 1)

## Goal

Collect project context needed for TOC design and documentation generation.

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `repo_path` | Yes | - | Absolute path to the target repository (git repo root preferred) |
| `output_dir` | No | `docs/wiki` | Documentation output directory |
| `include` | No | - | Include patterns (glob patterns) |
| `exclude` | No | - | Exclude patterns (glob patterns) |
| `max_depth` | No | `10` | Max scan depth |

## Outputs

| Path | Description |
|------|-------------|
| `{output_dir}/_context/context_pack.json` | Project context JSON for `toc-design` |

## Native Tools

Use AI assistant native tools - no external dependencies required:

### 1. Directory Structure

**Preferred**: Use `tree` command if available:
```bash
tree -L {max_depth} --dirsfirst -I "{exclude_patterns}" "{repo_path}"
```

**Fallback** (cross-platform alternatives):
```bash
# Using git (works everywhere with git)
git -C "{repo_path}" ls-files | head -200

# Using find (Unix/Mac/Linux)
find "{repo_path}" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" | head -200

# Using PowerShell (Windows)
Get-ChildItem -Path "{repo_path}" -Recurse -File | Where-Object { $_.FullName -notmatch "node_modules|\.git" } | Select-Object -First 200
```

### 2. File Type Statistics: File Search

Use file search/glob to count files by extension:
- `**/*.py` - Python files
- `**/*.ts` - TypeScript files
- `**/*.js` - JavaScript files
- `**/*.java` - Java files
- `**/*.go` - Go files
- etc.

### 3. README Content: File Read

Read README.md directly using the file read tool.

### 4. Git Metadata: Shell

```bash
git -C "{repo_path}" rev-parse --show-toplevel  # Repo root
git -C "{repo_path}" remote get-url origin       # Repo URL (if available)
git -C "{repo_path}" rev-parse HEAD              # Commit hash
```

## Workflow

1. **Validate repository**:
   - Verify `repo_path` exists and is a directory
   - Check if it's a git repository (has `.git` folder)

2. **Collect git metadata** using Bash:
   ```bash
   git rev-parse --show-toplevel  # Repo root
   git remote get-url origin       # Repo URL (if available)
   git rev-parse HEAD              # Commit hash
   ```

3. **Collect directory structure** using shell commands:
   ```bash
   # Try tree first, fallback to git ls-files
   tree -L 10 --dirsfirst -I "node_modules|.git|__pycache__|*.pyc" "{repo_path}" 2>/dev/null || git -C "{repo_path}" ls-files | head -200
   ```

4. **Collect file type statistics** using file search/glob:
   - Use glob patterns like `**/*.py`, `**/*.ts`, etc.
   - Count results to determine language distribution

5. **Read README** using file read tool:
   - Read `README.md` or `readme.md` if exists

6. **Generate context_pack.json**:
   Combine all collected data into the output JSON structure:

   ```json
   {
     "structure": {
       "tree": "...",
       "file_count": 42,
       "directory_count": 8,
       "total_size": 156300,
       "total_size_formatted": "152.6 KB",
       "languages": {"Python": 25, "JavaScript": 10}
     },
     "readme": {
       "content": "...",
       "path": "README.md",
       "encoding": "utf-8"
     },
     "git": {
       "root": "/path/to/repo",
       "remote_url": "https://github.com/...",
       "commit_hash": "abc123..."
     },
     "metadata": {
       "repo_path": "/path/to/repo",
       "has_readme": true,
       "structure_truncated": false,
       "readme_truncated": false
     }
   }
   ```

7. **Write output** to `{output_dir}/_context/context_pack.json`

## Validation

- [ ] `{output_dir}/_context/` directory exists
- [ ] `{output_dir}/_context/context_pack.json` is valid JSON
