param(
    [string]$RootDir = ".",
    [string]$OutputPath = "openwiki/facts.json",
    [int]$MaxApiEndpoints = 200,
    [int]$MaxConfigKeys = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-RipGrep {
    $cmd = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw "未检测到 rg（ripgrep）。请先安装 rg 后再执行 repo-scan。"
    }
}

function Get-NormalizedPath {
    param([string]$Path)
    return ($Path -replace "\\", "/")
}

function Normalize-RepoRelativePath {
    param([string]$Path)
    $p = Get-NormalizedPath -Path $Path
    $p = $p -replace "^\./", ""
    return $p
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )
    $baseResolved = (Resolve-Path -LiteralPath $BasePath).Path
    $targetResolved = (Resolve-Path -LiteralPath $TargetPath).Path
    $sep = [IO.Path]::DirectorySeparatorChar
    $baseWithSep = $baseResolved.TrimEnd('\', '/') + $sep
    $uriBase = [System.Uri]::new($baseWithSep)
    $uriTarget = [System.Uri]::new($targetResolved)
    $relative = $uriBase.MakeRelativeUri($uriTarget).ToString()
    return [System.Uri]::UnescapeDataString($relative)
}

function To-PlatformPath {
    param([string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return $PathText }
    return ($PathText -replace "/", [IO.Path]::DirectorySeparatorChar)
}

function Get-CommonExcludes {
    return @(
        "-g", "!**/.git/**",
        "-g", "!**/node_modules/**",
        "-g", "!**/dist/**",
        "-g", "!**/build/**",
        "-g", "!**/.next/**",
        "-g", "!**/.venv/**",
        "-g", "!**/venv/**"
    )
}

function Get-RepoFiles {
    param([string]$SearchRoot)
    $args = @("--files", "--hidden") + (Get-CommonExcludes) + @($SearchRoot)
    $raw = & rg @args 2>$null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
        throw "执行 rg --files 失败，exit code=$LASTEXITCODE"
    }
    $files = @()
    foreach ($line in $raw) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $files += (Normalize-RepoRelativePath -Path $line.Trim())
        }
    }
    return $files
}

function Invoke-RgMatchLines {
    param(
        [string]$Pattern,
        [string]$SearchRoot,
        [string[]]$Globs = @()
    )
    $args = @("--json", "--line-number", "--hidden", "--color", "never") + (Get-CommonExcludes)
    foreach ($g in $Globs) {
        $args += @("-g", $g)
    }
    $args += @("--", $Pattern, $SearchRoot)

    $raw = & rg @args 2>$null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
        throw "执行 rg 匹配失败，pattern=$Pattern, exit code=$LASTEXITCODE"
    }

    $results = @()
    foreach ($line in $raw) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $obj = $line | ConvertFrom-Json -Depth 20
            if ($obj.type -ne "match") {
                continue
            }
            $results += [pscustomobject]@{
                file = (Normalize-RepoRelativePath -Path $obj.data.path.text)
                line = [int]$obj.data.line_number
                text = ($obj.data.lines.text -replace "(\r|\n)+$", "")
            }
        }
        catch {
            continue
        }
    }
    return $results
}

function Add-Unique {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string]$Value
    )
    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        [void]$Set.Add($Value.Trim())
    }
}

function Safe-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return $Value }
    return @($Value)
}

function Detect-Languages {
    param([string[]]$Files)
    $extMap = @{
        ".ps1" = "PowerShell"
        ".py" = "Python"
        ".ts" = "TypeScript"
        ".tsx" = "TypeScript"
        ".js" = "JavaScript"
        ".jsx" = "JavaScript"
        ".cs" = "C#"
        ".go" = "Go"
        ".java" = "Java"
        ".cpp" = "C++"
        ".cc" = "C++"
        ".cxx" = "C++"
        ".c" = "C/C++"
        ".h" = "C/C++"
        ".hpp" = "C/C++"
        ".rs" = "Rust"
        ".rb" = "Ruby"
        ".php" = "PHP"
        ".kt" = "Kotlin"
        ".swift" = "Swift"
    }
    $counter = @{}
    foreach ($f in $Files) {
        $ext = [IO.Path]::GetExtension($f).ToLowerInvariant()
        if ($extMap.ContainsKey($ext)) {
            $lang = $extMap[$ext]
            if (-not $counter.ContainsKey($lang)) {
                $counter[$lang] = 0
            }
            $counter[$lang]++
        }
    }
    $results = @()
    foreach ($k in ($counter.Keys | Sort-Object)) {
        $results += [pscustomobject]@{
            language = $k
            file_count = $counter[$k]
        }
    }
    return $results
}

function Detect-Frameworks {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($Files -contains "package.json") {
        try {
            $pkg = Get-Content -Raw -LiteralPath (Join-Path $SearchRoot "package.json") | ConvertFrom-Json -Depth 20
            $deps = @{}
            if ($null -ne $pkg.dependencies) {
                $pkg.dependencies.psobject.Properties | ForEach-Object { $deps[$_.Name] = $true }
            }
            if ($null -ne $pkg.devDependencies) {
                $pkg.devDependencies.psobject.Properties | ForEach-Object { $deps[$_.Name] = $true }
            }
            if ($deps.ContainsKey("next")) { Add-Unique -Set $set -Value "Next.js" }
            if ($deps.ContainsKey("react")) { Add-Unique -Set $set -Value "React" }
            if ($deps.ContainsKey("vue")) { Add-Unique -Set $set -Value "Vue" }
            if ($deps.ContainsKey("nuxt")) { Add-Unique -Set $set -Value "Nuxt" }
            if ($deps.ContainsKey("express")) { Add-Unique -Set $set -Value "Express" }
            if ($deps.ContainsKey("@nestjs/core")) { Add-Unique -Set $set -Value "NestJS" }
        }
        catch { }
    }

    if (@($Files | Where-Object { $_ -like "*.csproj" }).Count -gt 0) {
        $asp = Invoke-RgMatchLines -Pattern "Microsoft\.NET\.Sdk\.Web|WebApplication\.CreateBuilder|Map(Get|Post|Put|Delete|Patch)\(" -SearchRoot $SearchRoot -Globs @("*.cs", "*.csproj")
        if ($asp.Count -gt 0) {
            Add-Unique -Set $set -Value "ASP.NET Core"
        }
    }

    $pyWeb = Invoke-RgMatchLines -Pattern "from\s+fastapi\s+import|FastAPI\(|from\s+flask\s+import|Flask\(|django" -SearchRoot $SearchRoot -Globs @("*.py")
    foreach ($m in $pyWeb) {
        if ($m.text -match "FastAPI|fastapi") { Add-Unique -Set $set -Value "FastAPI" }
        if ($m.text -match "Flask|flask") { Add-Unique -Set $set -Value "Flask" }
        if ($m.text -match "django|Django") { Add-Unique -Set $set -Value "Django" }
    }

    $goWeb = Invoke-RgMatchLines -Pattern "gin\.Default\(|echo\.New\(|fiber\.New\(" -SearchRoot $SearchRoot -Globs @("*.go")
    foreach ($m in $goWeb) {
        if ($m.text -match "gin\.Default") { Add-Unique -Set $set -Value "Gin" }
        if ($m.text -match "echo\.New") { Add-Unique -Set $set -Value "Echo" }
        if ($m.text -match "fiber\.New") { Add-Unique -Set $set -Value "Fiber" }
    }

    return @($set | Sort-Object)
}

function Detect-EntryPoints {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $backend = [System.Collections.Generic.List[object]]::new()
    $frontend = [System.Collections.Generic.List[object]]::new()
    $worker = [System.Collections.Generic.List[object]]::new()

    $entryPatterns = @(
        "Program.cs",
        "main.py",
        "app.py",
        "server.py",
        "main.go",
        "main.rs",
        "src/main.ts",
        "src/main.tsx",
        "src/main.js",
        "src/main.jsx",
        "index.js",
        "server.js"
    )

    foreach ($f in $Files) {
        $normalized = Get-NormalizedPath -Path $f
        foreach ($name in $entryPatterns) {
            if ($normalized.EndsWith($name, [System.StringComparison]::OrdinalIgnoreCase)) {
                $type = if ($normalized -match "\.py$|\.go$|\.cs$|server\.js$|main\.rs$") { "backend" } else { "frontend" }
                $item = [pscustomobject]@{
                    path = $normalized
                    kind = if ($type -eq "backend") { "application_entry" } else { "ui_entry" }
                }
                if ($type -eq "backend") { $backend.Add($item) } else { $frontend.Add($item) }
                break
            }
        }
        if ($normalized -match "(worker|job|scheduler|queue)") {
            $worker.Add([pscustomobject]@{
                path = $normalized
                kind = "worker_or_job"
            })
        }
    }

    # Next.js app router hints
    foreach ($f in $Files) {
        if ($f -match "app/(layout|page)\.(tsx|ts|jsx|js)$") {
            $frontend.Add([pscustomobject]@{
                path = (Get-NormalizedPath -Path $f)
                kind = "next_app_router_entry"
            })
        }
    }

    return [pscustomobject]@{
        backend = @($backend | Sort-Object path -Unique)
        frontend = @($frontend | Sort-Object path -Unique)
        workers = @($worker | Sort-Object path -Unique | Select-Object -First 30)
    }
}

function Parse-NodeDependencies {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    if (-not ($Files -contains "package.json")) {
        return @()
    }
    try {
        $pkg = Get-Content -Raw -LiteralPath (Join-Path $SearchRoot "package.json") | ConvertFrom-Json -Depth 20
        $deps = [System.Collections.Generic.List[object]]::new()
        if ($null -ne $pkg.dependencies) {
            foreach ($p in $pkg.dependencies.psobject.Properties) {
                $deps.Add([pscustomobject]@{ name = $p.Name; version = [string]$p.Value; scope = "dependencies" })
            }
        }
        if ($null -ne $pkg.devDependencies) {
            foreach ($p in $pkg.devDependencies.psobject.Properties) {
                $deps.Add([pscustomobject]@{ name = $p.Name; version = [string]$p.Value; scope = "devDependencies" })
            }
        }
        return @($deps | Sort-Object name | Select-Object -First 150)
    }
    catch {
        return @()
    }
}

function Parse-PythonDependencies {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $deps = [System.Collections.Generic.List[object]]::new()

    $reqFiles = $Files | Where-Object { $_ -match "(^|/)requirements.*\.txt$" }
    foreach ($rf in $reqFiles) {
        $full = Join-Path $SearchRoot (To-PlatformPath -PathText $rf)
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $lines = Get-Content -LiteralPath $full
        foreach ($line in $lines) {
            $v = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($v) -or $v.StartsWith("#")) { continue }
            if ($v -match "^(?<name>[A-Za-z0-9_\-\.]+)(?<ver>(==|>=|<=|~=|>|<).+)?$") {
                $deps.Add([pscustomobject]@{
                    name = $matches["name"]
                    version = if ($matches["ver"]) { $matches["ver"] } else { "" }
                    source = $rf
                })
            }
        }
    }

    if ($Files -contains "pyproject.toml") {
        $full = Join-Path $SearchRoot "pyproject.toml"
        $pyprojectLines = Invoke-RgMatchLines -Pattern '^\s*"?[A-Za-z0-9_\-\.]+"?\s*(=|>=|<=|~=|>|<)' -SearchRoot $full
        foreach ($m in $pyprojectLines) {
            $line = $m.text.Trim()
            if ($line -match '^(?<name>"?[A-Za-z0-9_\-\.]+"?)\s*(=|>=|<=|~=|>|<)\s*(?<ver>.+)$') {
                $deps.Add([pscustomobject]@{
                    name = $Matches["name"].Trim('"')
                    version = $Matches["ver"].Trim()
                    source = "pyproject.toml"
                })
            }
        }
    }

    return @($deps | Sort-Object name -Unique | Select-Object -First 150)
}

function Parse-DotNetDependencies {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $deps = [System.Collections.Generic.List[object]]::new()
    $projFiles = $Files | Where-Object { $_ -like "*.csproj" }
    foreach ($pf in $projFiles) {
        $full = Join-Path $SearchRoot (To-PlatformPath -PathText $pf)
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $packageLines = Invoke-RgMatchLines -Pattern '<PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)"' -SearchRoot $full
        foreach ($m in $packageLines) {
            if ($m.text -match '<PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)"') {
                $deps.Add([pscustomobject]@{
                    name = $Matches[1]
                    version = $Matches[2]
                    source = $pf
                })
            }
        }
    }
    return @($deps | Sort-Object name -Unique | Select-Object -First 150)
}

function Parse-GoDependencies {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    if (-not ($Files -contains "go.mod")) {
        return @()
    }
    $deps = [System.Collections.Generic.List[object]]::new()
    $full = Join-Path $SearchRoot "go.mod"
    $goLines = Invoke-RgMatchLines -Pattern '^\s*[A-Za-z0-9\.\-/]+\s+v[0-9]+\.[0-9]+\.[0-9]+' -SearchRoot $full
    foreach ($m in $goLines) {
        if ($m.text -match '^\s*([A-Za-z0-9\.\-/]+)\s+(v[0-9]+\.[0-9]+\.[0-9][^\s]*)') {
            $deps.Add([pscustomobject]@{
                name = $Matches[1]
                version = $Matches[2]
                source = "go.mod"
            })
        }
    }
    return @($deps | Sort-Object name -Unique | Select-Object -First 150)
}

function Parse-JavaDependencies {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $deps = [System.Collections.Generic.List[object]]::new()
    $pomFiles = $Files | Where-Object { $_ -like "*pom.xml" }
    foreach ($pf in $pomFiles) {
        $full = Join-Path $SearchRoot (To-PlatformPath -PathText $pf)
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $groupMatches = Invoke-RgMatchLines -Pattern "<groupId>[^<]+</groupId>" -SearchRoot $full
        $artifactMatches = Invoke-RgMatchLines -Pattern "<artifactId>[^<]+</artifactId>" -SearchRoot $full
        $versionMatches = Invoke-RgMatchLines -Pattern "<version>[^<]+</version>" -SearchRoot $full

        $size = [Math]::Min($groupMatches.Count, [Math]::Min($artifactMatches.Count, $versionMatches.Count))
        for ($i = 0; $i -lt $size; $i++) {
            $group = ""
            $artifact = ""
            $version = ""
            if ($groupMatches[$i].text -match "<groupId>([^<]+)</groupId>") { $group = $matches[1] }
            if ($artifactMatches[$i].text -match "<artifactId>([^<]+)</artifactId>") { $artifact = $matches[1] }
            if ($versionMatches[$i].text -match "<version>([^<]+)</version>") { $version = $matches[1] }
            if (-not [string]::IsNullOrWhiteSpace($artifact)) {
                $deps.Add([pscustomobject]@{
                    name = if ([string]::IsNullOrWhiteSpace($group)) { $artifact } else { "$group`:$artifact" }
                    version = $version
                    source = $pf
                })
            }
        }
    }
    return @($deps | Sort-Object name -Unique | Select-Object -First 150)
}

function Detect-ApiEndpoints {
    param(
        [string]$SearchRoot,
        [int]$Limit
    )
    $hits = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $candidates = Invoke-RgMatchLines -Pattern "Map(Get|Post|Put|Delete|Patch)\(|@(?:app|router|bp)\.(get|post|put|delete|patch|route)\(|(?:app|router)\.(get|post|put|delete|patch)\(" -SearchRoot $SearchRoot -Globs @("*.cs", "*.py", "*.js", "*.jsx", "*.ts", "*.tsx")

    foreach ($m in $candidates) {
        $method = ""
        $path = ""
        $kind = ""

        if ($m.text -match 'Map(Get|Post|Put|Delete|Patch)\s*\(\s*"([^"]+)"') {
            $method = $Matches[1].ToUpperInvariant()
            $path = $Matches[2]
            $kind = "aspnet_map"
        }
        elseif ($m.text -match '@(?:app|router)\.(get|post|put|delete|patch)\(\s*["'']([^"'']+)["'']') {
            $method = $Matches[1].ToUpperInvariant()
            $path = $Matches[2]
            $kind = "python_decorator"
        }
        elseif ($m.text -match '@(?:app|bp|blueprint)\.route\(\s*["'']([^"'']+)["'']') {
            $method = "ANY"
            $path = $Matches[1]
            $kind = "flask_route"
        }
        elseif ($m.text -match '(?:app|router)\.(get|post|put|delete|patch)\(\s*["''`]([^"''`]+)["''`]') {
            $method = $Matches[1].ToUpperInvariant()
            $path = $Matches[2]
            $kind = "express_router"
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }
        $fingerprint = "$($m.file)|$($m.line)|$method|$path"
        if ($seen.Add($fingerprint)) {
            $hits.Add([pscustomobject]@{
                method = $method
                path = $path
                kind = $kind
                file = $m.file
                line = $m.line
                snippet = $m.text.Trim()
            })
        }
        if ($hits.Count -ge $Limit) {
            break
        }
    }
    return @($hits | Sort-Object file, line)
}

function Detect-ConfigFacts {
    param(
        [string]$SearchRoot,
        [string[]]$Files,
        [int]$Limit
    )
    $configFiles = $Files | Where-Object {
        $_ -match "(^|/)\.env" -or
        $_ -match "(^|/)(appsettings.*\.json)$" -or
        $_ -match "(^|/)(docker-compose.*\.(yaml|yml)|compose.*\.(yaml|yml))$" -or
        $_ -match "(^|/).*(config|settings).*\.(json|yaml|yml|toml)$"
    }
    $configFiles = @($configFiles | Sort-Object -Unique)

    $keys = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($cf in $configFiles) {
        $full = Join-Path $SearchRoot (To-PlatformPath -PathText $cf)
        if (-not (Test-Path -LiteralPath $full)) {
            continue
        }

        $envMatches = Invoke-RgMatchLines -Pattern "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=" -SearchRoot $full
        foreach ($m in $envMatches) {
            if ($m.text -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=") {
                $k = $Matches[1]
                $id = "$cf|$k"
                if ($seen.Add($id)) {
                    $keys.Add([pscustomobject]@{
                        key = $k
                        file = $cf
                        line = $m.line
                        source = "env_assignment"
                    })
                }
            }
            if ($keys.Count -ge $Limit) { break }
        }
        if ($keys.Count -ge $Limit) { break }

        $yamlMatches = Invoke-RgMatchLines -Pattern "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*" -SearchRoot $full
        foreach ($m in $yamlMatches) {
            if ($m.text -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*") {
                $k = $Matches[1]
                if ($k -match "^[A-Z0-9_]+$") {
                    $id = "$cf|$k"
                    if ($seen.Add($id)) {
                        $keys.Add([pscustomobject]@{
                            key = $k
                            file = $cf
                            line = $m.line
                            source = "yaml_key"
                        })
                    }
                }
            }
            if ($keys.Count -ge $Limit) { break }
        }
        if ($keys.Count -ge $Limit) { break }
    }

    return [pscustomobject]@{
        files = @($configFiles | Select-Object -First 200)
        keys = @($keys | Sort-Object file, line, key)
    }
}

function Detect-TopModules {
    param([string[]]$Files)
    $map = @{}
    foreach ($f in $Files) {
        $parts = $f.Split("/")
        if ($parts.Count -ge 2) {
            $top = $parts[0]
        } else {
            $top = "(root)"
        }
        if (-not $map.ContainsKey($top)) {
            $map[$top] = 0
        }
        $map[$top]++
    }
    $modules = @()
    foreach ($k in ($map.Keys | Sort-Object)) {
        $modules += [pscustomobject]@{
            name = $k
            file_count = $map[$k]
        }
    }
    return @($modules | Sort-Object name | Sort-Object file_count -Descending | Select-Object -First 40)
}

function Ensure-ParentDirectory {
    param([string]$FilePath)
    $parent = Split-Path -Parent $FilePath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Detect-PackageManagers {
    param([string[]]$Files)
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($Files -contains "package-lock.json") { [void]$set.Add("npm") }
    if ($Files -contains "pnpm-lock.yaml") { [void]$set.Add("pnpm") }
    if ($Files -contains "yarn.lock") { [void]$set.Add("yarn") }
    if ($Files -contains "bun.lockb" -or $Files -contains "bun.lock") { [void]$set.Add("bun") }
    if (@($Files | Where-Object { $_ -match "(^|/)requirements.*\.txt$" }).Count -gt 0) { [void]$set.Add("pip") }
    if ($Files -contains "poetry.lock") { [void]$set.Add("poetry") }
    if ($Files -contains "Pipfile.lock") { [void]$set.Add("pipenv") }
    if ($Files -contains "go.sum") { [void]$set.Add("go modules") }
    if (@($Files | Where-Object { $_ -like "*.csproj" -or $_ -like "*.sln" }).Count -gt 0) { [void]$set.Add("nuget") }
    if (@($Files | Where-Object { $_ -like "*pom.xml" -or $_ -like "*build.gradle*" }).Count -gt 0) { [void]$set.Add("maven/gradle") }
    if ($Files -contains "Cargo.lock") { [void]$set.Add("cargo") }
    return @($set | Sort-Object)
}

function Detect-CiCdFacts {
    param([string[]]$Files)
    $providers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $configs = [System.Collections.Generic.List[string]]::new()

    foreach ($f in $Files) {
        $n = Normalize-RepoRelativePath -Path $f
        if ($n -match "^\.github/workflows/.+\.(yml|yaml)$") {
            [void]$providers.Add("GitHub Actions")
            $configs.Add($n)
        }
        elseif ($n -ieq ".gitlab-ci.yml") {
            [void]$providers.Add("GitLab CI")
            $configs.Add($n)
        }
        elseif ($n -ieq "Jenkinsfile") {
            [void]$providers.Add("Jenkins")
            $configs.Add($n)
        }
        elseif ($n -ieq "azure-pipelines.yml" -or $n -ieq "azure-pipelines.yaml") {
            [void]$providers.Add("Azure Pipelines")
            $configs.Add($n)
        }
        elseif ($n -ieq ".circleci/config.yml") {
            [void]$providers.Add("CircleCI")
            $configs.Add($n)
        }
        elseif ($n -ieq ".travis.yml") {
            [void]$providers.Add("Travis CI")
            $configs.Add($n)
        }
    }

    return [pscustomobject]@{
        providers = @($providers | Sort-Object)
        config_files = @($configs | Sort-Object -Unique | Select-Object -First 80)
    }
}

function Detect-TestFacts {
    param(
        [string]$SearchRoot,
        [string[]]$Files
    )
    $testFiles = @($Files | Where-Object {
        $_ -match "(^|/)(test|tests|spec|specs|__tests__)(/|$)" -or
        $_ -match "(\.|_)(test|spec)\.(js|jsx|ts|tsx|py|cs|go|java|rb|php)$" -or
        $_ -match "_test\.go$"
    })

    $frameworkSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $hints = Invoke-RgMatchLines -Pattern "pytest|unittest|jest|vitest|mocha|xunit|nunit|mstest|go test|testing\.T|rspec|phpunit" -SearchRoot $SearchRoot -Globs @("*.py", "*.js", "*.jsx", "*.ts", "*.tsx", "*.cs", "*.go", "*.rb", "*.php")
    foreach ($m in $hints) {
        if ($m.text -match "pytest") { [void]$frameworkSet.Add("pytest") }
        if ($m.text -match "unittest") { [void]$frameworkSet.Add("unittest") }
        if ($m.text -match "jest") { [void]$frameworkSet.Add("jest") }
        if ($m.text -match "vitest") { [void]$frameworkSet.Add("vitest") }
        if ($m.text -match "mocha") { [void]$frameworkSet.Add("mocha") }
        if ($m.text -match "xunit|Xunit") { [void]$frameworkSet.Add("xUnit") }
        if ($m.text -match "nunit|NUnit") { [void]$frameworkSet.Add("NUnit") }
        if ($m.text -match "mstest|MSTest") { [void]$frameworkSet.Add("MSTest") }
        if ($m.text -match "testing\.T|go test") { [void]$frameworkSet.Add("go test") }
        if ($m.text -match "rspec") { [void]$frameworkSet.Add("rspec") }
        if ($m.text -match "phpunit") { [void]$frameworkSet.Add("phpunit") }
    }

    $coverageConfigs = @($Files | Where-Object {
        $_ -in @(".coveragerc", "coverage.xml", "jest.config.js", "jest.config.ts", "vitest.config.ts", "vitest.config.js", "nyc.config.js", "codecov.yml", "codecov.yaml")
    })

    return [pscustomobject]@{
        test_files_count = $testFiles.Count
        framework_hints = @($frameworkSet | Sort-Object)
        coverage_configs = @($coverageConfigs | Sort-Object -Unique | Select-Object -First 40)
        key_test_files = @($testFiles | Sort-Object | Select-Object -First 80)
    }
}

function Detect-RunProfiles {
    param(
        [string]$SearchRoot,
        [string[]]$Files,
        $EntryPoints
    )
    $commands = [System.Collections.Generic.List[object]]::new()

    if ($Files -contains "package.json") {
        try {
            $pkg = Get-Content -Raw -LiteralPath (Join-Path $SearchRoot "package.json") | ConvertFrom-Json -Depth 20
            if ($null -ne $pkg.scripts) {
                foreach ($s in $pkg.scripts.psobject.Properties) {
                    $commands.Add([pscustomobject]@{
                        name = "npm run $($s.Name)"
                        command = [string]$s.Value
                        source = "package.json"
                    })
                }
            }
        }
        catch { }
    }

    $composeFiles = @($Files | Where-Object { $_ -match "(^|/)(docker-compose.*\.(yml|yaml)|compose.*\.(yml|yaml))$" } | Select-Object -Unique)
    foreach ($cf in $composeFiles) {
        $commands.Add([pscustomobject]@{
            name = "docker compose up"
            command = "docker compose -f $cf up -d"
            source = $cf
        })
    }

    $makefiles = @($Files | Where-Object { $_ -match "(^|/)(Makefile|makefile|.+\.mk)$" } | Select-Object -Unique)
    foreach ($mf in $makefiles) {
        $full = Join-Path $SearchRoot (To-PlatformPath -PathText $mf)
        if (-not (Test-Path -LiteralPath $full)) { continue }
        $targets = Invoke-RgMatchLines -Pattern "^[A-Za-z0-9_.-]+:\s*($|##)" -SearchRoot $full
        foreach ($t in ($targets | Select-Object -First 8)) {
            if ($t.text -match "^([A-Za-z0-9_.-]+):") {
                $commands.Add([pscustomobject]@{
                    name = "make $($Matches[1])"
                    command = "make $($Matches[1])"
                    source = $mf
                })
            }
        }
    }

    foreach ($e in @(Safe-Array $EntryPoints.backend)) {
        if ($e.path -match "\.py$") {
            $commands.Add([pscustomobject]@{ name = "python $($e.path)"; command = "python $($e.path)"; source = $e.path })
        }
        elseif ($e.path -match "\.go$") {
            $commands.Add([pscustomobject]@{ name = "go run $($e.path)"; command = "go run $($e.path)"; source = $e.path })
        }
        elseif ($e.path -match "\.cs$") {
            $commands.Add([pscustomobject]@{ name = "dotnet run"; command = "dotnet run"; source = $e.path })
        }
    }

    return [pscustomobject]@{
        commands_count = $commands.Count
        suggested_commands = @($commands | Sort-Object name -Unique | Select-Object -First 40)
    }
}

function Build-QualityReport {
    param(
        [int]$FileCount,
        $Languages,
        $Frameworks,
        $ApiEndpoints,
        $ConfigFacts,
        $Dependencies,
        $CiCdFacts,
        $TestFacts,
        $RunProfiles
    )
    $depTotal = 0
    $depTotal += @(Safe-Array $Dependencies.node).Count
    $depTotal += @(Safe-Array $Dependencies.python).Count
    $depTotal += @(Safe-Array $Dependencies.dotnet).Count
    $depTotal += @(Safe-Array $Dependencies.go).Count
    $depTotal += @(Safe-Array $Dependencies.java).Count

    $apiCount = @(Safe-Array $ApiEndpoints).Count
    $cfgKeys = @(Safe-Array $ConfigFacts.keys).Count
    $langCount = @(Safe-Array $Languages).Count
    $frameworkCount = @(Safe-Array $Frameworks).Count
    $ciCount = @(Safe-Array $CiCdFacts.providers).Count
    $testFileCount = [int]$TestFacts.test_files_count
    $runCmdCount = [int]$RunProfiles.commands_count

    $score = 30
    $score += [Math]::Min(15, $langCount * 5)
    $score += [Math]::Min(10, $frameworkCount * 3)
    if ($apiCount -gt 0) { $score += [Math]::Min(15, [Math]::Ceiling($apiCount / 10.0) * 3) }
    if ($cfgKeys -gt 0) { $score += 10 }
    if ($depTotal -gt 0) { $score += 10 }
    if ($ciCount -gt 0) { $score += 5 }
    if ($testFileCount -gt 0) { $score += 5 }
    if ($runCmdCount -gt 0) { $score += 5 }
    if ($score -gt 100) { $score = 100 }

    $level = "low"
    if ($score -ge 85) {
        $level = "high"
    }
    elseif ($score -ge 65) {
        $level = "medium"
    }

    $gaps = @()
    if ($apiCount -eq 0) { $gaps += "未识别到 API 路由线索（可能是静态站点或路由写法未覆盖）。" }
    if ($cfgKeys -eq 0) { $gaps += "未识别到配置键（建议检查 .env / yaml / json）。" }
    if ($depTotal -eq 0) { $gaps += "未识别到依赖清单（可能缺少 lockfile/manifest）。" }
    if ($ciCount -eq 0) { $gaps += "未识别到 CI/CD 配置。" }
    if ($testFileCount -eq 0) { $gaps += "未识别到测试文件或测试框架线索。" }
    if ($runCmdCount -eq 0) { $gaps += "未识别到启动命令线索。" }

    return [pscustomobject]@{
        parse_confidence = [int]$score
        confidence_level = $level
        coverage = [pscustomobject]@{
            files_scanned = $FileCount
            languages_detected = $langCount
            frameworks_detected = $frameworkCount
            api_endpoints_detected = $apiCount
            config_keys_detected = $cfgKeys
            dependencies_detected = $depTotal
            ci_providers_detected = $ciCount
            test_files_detected = $testFileCount
            run_commands_detected = $runCmdCount
        }
        gaps = @($gaps)
    }
}

Assert-RipGrep

if (-not (Test-Path -LiteralPath $RootDir)) {
    throw "RootDir 不存在：$RootDir"
}

$rootResolved = (Resolve-Path -LiteralPath $RootDir).Path
$outputRelative = ""
if ([IO.Path]::IsPathRooted($OutputPath)) {
    $fullOutputCandidate = $OutputPath
    if ($fullOutputCandidate.StartsWith($rootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
        $outputRelative = Normalize-RepoRelativePath -Path (Get-RelativePath -BasePath $rootResolved -TargetPath $fullOutputCandidate)
    }
}
else {
    $outputRelative = Normalize-RepoRelativePath -Path $OutputPath
}

Push-Location $rootResolved
try {
    $repoFiles = @(Get-RepoFiles -SearchRoot ".")
    if (-not [string]::IsNullOrWhiteSpace($outputRelative)) {
        $repoFiles = @($repoFiles | Where-Object { $_ -ne $outputRelative })
    }
    $repoFileCount = $repoFiles.Count

    $languages = @(Detect-Languages -Files $repoFiles)
    $frameworks = @(Detect-Frameworks -SearchRoot "." -Files $repoFiles)
    $entryPoints = Detect-EntryPoints -SearchRoot "." -Files $repoFiles
    $apiEndpoints = @(Detect-ApiEndpoints -SearchRoot "." -Limit $MaxApiEndpoints)
    $configFacts = Detect-ConfigFacts -SearchRoot "." -Files $repoFiles -Limit $MaxConfigKeys
    $dependencies = [ordered]@{
        node = @(Parse-NodeDependencies -SearchRoot "." -Files $repoFiles)
        python = @(Parse-PythonDependencies -SearchRoot "." -Files $repoFiles)
        dotnet = @(Parse-DotNetDependencies -SearchRoot "." -Files $repoFiles)
        go = @(Parse-GoDependencies -SearchRoot "." -Files $repoFiles)
        java = @(Parse-JavaDependencies -SearchRoot "." -Files $repoFiles)
    }
    $packageManagers = @(Detect-PackageManagers -Files $repoFiles)
    $ciCdFacts = Detect-CiCdFacts -Files $repoFiles
    $testFacts = Detect-TestFacts -SearchRoot "." -Files $repoFiles
    $runProfiles = Detect-RunProfiles -SearchRoot "." -Files $repoFiles -EntryPoints $entryPoints
    $quality = Build-QualityReport -FileCount $repoFileCount -Languages $languages -Frameworks $frameworks -ApiEndpoints $apiEndpoints -ConfigFacts $configFacts -Dependencies $dependencies -CiCdFacts $ciCdFacts -TestFacts $testFacts -RunProfiles $runProfiles

    $result = [ordered]@{
        generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        root_dir = (Get-NormalizedPath -Path $rootResolved)
        engine = [ordered]@{
            name = "openwiki-repo-scan"
            version = "2.0"
        }
        compatibility = [ordered]@{
            targets = @("Claude Code", "Codex")
            requirements = @("PowerShell", "rg")
        }
        project = [ordered]@{
            name = (Split-Path -Leaf $rootResolved)
            file_count = $repoFileCount
            top_modules = @(Detect-TopModules -Files $repoFiles)
        }
        stack = [ordered]@{
            languages = $languages
            frameworks = $frameworks
        }
        entry_points = $entryPoints
        dependencies = $dependencies
        tooling = [ordered]@{
            package_managers = $packageManagers
            ci_cd = $ciCdFacts
            tests = $testFacts
            run_profiles = $runProfiles
        }
        api_endpoints = $apiEndpoints
        configuration = $configFacts
        quality = $quality
        evidence = [ordered]@{
            key_files = @($repoFiles | Select-Object -First 500)
        }
    }

    $outFull = if ([IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    } else {
        Join-Path $rootResolved $OutputPath
    }

    Ensure-ParentDirectory -FilePath $outFull

    $json = $result | ConvertTo-Json -Depth 20
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outFull, $json, $utf8NoBom)

    $relativeOutput = Get-RelativePath -BasePath $rootResolved -TargetPath $outFull
    Write-Host "repo-scan: PASS"
    Write-Host "files=$repoFileCount, languages=$($languages.Count), frameworks=$($frameworks.Count), apis=$($apiEndpoints.Count), config_keys=$($configFacts.keys.Count), confidence=$($quality.parse_confidence)"
    Write-Host "facts=$relativeOutput"
}
finally {
    Pop-Location
}
