param(
    [string]$DocDir = "docs/openwiki",
    [string]$FactsPath = "",
    [string]$TocPath = "",
    [string]$ReadmePath = "README.md",
    [string]$TemplatesDir = "",
    [switch]$OverwriteExisting,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FactsPath)) {
    $FactsPath = Join-Path $DocDir "facts.json"
}
if ([string]::IsNullOrWhiteSpace($TocPath)) {
    $TocPath = Join-Path $DocDir "toc.yaml"
}
if ([string]::IsNullOrWhiteSpace($TemplatesDir)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $TemplatesDir = Join-Path $scriptRoot "..\templates"
}

function Normalize-PathToken {
    param([string]$PathText)
    return (($PathText -replace "\\", "/").Trim())
}

function To-PlatformPath {
    param([string]$PathText)
    if ([string]::IsNullOrWhiteSpace($PathText)) { return $PathText }
    return ($PathText -replace "/", [IO.Path]::DirectorySeparatorChar)
}

function Ensure-DirForFile {
    param([string]$FilePath)
    $parent = Split-Path -Parent $FilePath
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    if ($DryRun) {
        return
    }
    Ensure-DirForFile -FilePath $Path
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Load-Json {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "facts 文件不存在：$Path"
    }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Load-Template {
    param([string]$FileName)
    $path = Join-Path $TemplatesDir $FileName
    if (-not (Test-Path -LiteralPath $path)) {
        throw "模板文件不存在：$path"
    }
    return (Get-Content -Raw -LiteralPath $path)
}

function Parse-TocPages {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "toc 文件不存在：$Path"
    }

    $pages = @()
    $current = @{}
    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        if ($line -match '^\s*-\s*id:\s*(.+?)\s*$') {
            if ($current.ContainsKey("id") -and $current.ContainsKey("title") -and $current.ContainsKey("file")) {
                $pages += [pscustomobject]@{
                    id = $current["id"]
                    title = $current["title"]
                    file = $current["file"]
                }
            }
            $current = @{}
            $current["id"] = $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*id:\s*(.+?)\s*$') {
            $current["id"] = $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*title:\s*(.+?)\s*$') {
            $current["title"] = $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }
        if ($line -match '^\s*file:\s*(.+?)\s*$') {
            $current["file"] = $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }
    }

    if ($current.ContainsKey("id") -and $current.ContainsKey("title") -and $current.ContainsKey("file")) {
        $pages += [pscustomobject]@{
            id = $current["id"]
            title = $current["title"]
            file = $current["file"]
        }
    }
    return @($pages)
}

function Safe-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return $Value }
    return @($Value)
}

function Join-Top {
    param(
        [string[]]$Items,
        [int]$Max = 3,
        [string]$Fallback = "待补充"
    )
    $vals = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    if ($vals.Count -eq 0) { return $Fallback }
    return (($vals | Select-Object -First $Max) -join " / ")
}

function Build-ProjectPitch {
    param($Facts)
    $languages = @(Safe-Array $Facts.stack.languages) | Sort-Object file_count -Descending
    $frameworks = @(Safe-Array $Facts.stack.frameworks)
    $apiCount = @(Safe-Array $Facts.api_endpoints).Count
    $confidence = 0
    $level = "unknown"
    if ($null -ne $Facts.quality) {
        if ($null -ne $Facts.quality.parse_confidence) { $confidence = [int]$Facts.quality.parse_confidence }
        if ($null -ne $Facts.quality.confidence_level) { $level = [string]$Facts.quality.confidence_level }
    }

    $langNames = @($languages | ForEach-Object { $_.language })
    $langText = Join-Top -Items $langNames -Max 3 -Fallback "多语言"
    $frameworkText = Join-Top -Items $frameworks -Max 3 -Fallback "通用工程栈"
    return "该项目以 $langText 为主，识别到 $frameworkText，当前抽取到 $apiCount 条接口线索，解析置信度 $confidence/$level，可快速生成结构化协作文档。"
}

function Get-EntryText {
    param($Facts)
    $backend = @(Safe-Array $Facts.entry_points.backend) | ForEach-Object { $_.path }
    $frontend = @(Safe-Array $Facts.entry_points.frontend) | ForEach-Object { $_.path }
    $workers = @(Safe-Array $Facts.entry_points.workers) | ForEach-Object { $_.path }
    return Join-Top -Items @($backend + $frontend + $workers) -Max 5 -Fallback "待补充"
}

function Replace-Tokens {
    param(
        [string]$Template,
        [hashtable]$Map
    )
    $result = $Template
    foreach ($key in $Map.Keys) {
        $result = $result.Replace("{{${key}}}", [string]$Map[$key])
    }
    return $result
}

function Get-PageKind {
    param(
        [string]$PageId,
        [string]$Title
    )
    $key = ($PageId + " " + $Title).ToLowerInvariant()
    if ($key -match "api|contract|接口") { return "api" }
    if ($key -match "config|deploy|devops|配置|部署|运维") { return "config" }
    if ($key -match "qa|test|troubleshoot|排查|故障|测试") { return "qa" }
    if ($key -match "architecture|架构|设计") { return "architecture" }
    if ($key -match "dataflow|flow|standard|规范|流程") { return "dataflow" }
    return "overview"
}

function Get-ScoredSources {
    param(
        [string]$PageKind,
        $Facts
    )
    $scoreMap = @{}
    function Add-Score {
        param(
            [hashtable]$Map,
            [string]$Path,
            [int]$Score
        )
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        $p = Normalize-PathToken -PathText $Path
        if (-not $Map.ContainsKey($p)) {
            $Map[$p] = 0
        }
        $Map[$p] += $Score
    }

    foreach ($f in @(Safe-Array $Facts.evidence.key_files)) {
        Add-Score -Map $scoreMap -Path $f -Score 1
    }
    foreach ($e in @(Safe-Array $Facts.entry_points.backend)) {
        Add-Score -Map $scoreMap -Path $e.path -Score 8
    }
    foreach ($e in @(Safe-Array $Facts.entry_points.frontend)) {
        Add-Score -Map $scoreMap -Path $e.path -Score 6
    }
    foreach ($e in @(Safe-Array $Facts.entry_points.workers)) {
        Add-Score -Map $scoreMap -Path $e.path -Score 4
    }
    foreach ($a in @(Safe-Array $Facts.api_endpoints)) {
        Add-Score -Map $scoreMap -Path $a.file -Score 7
    }
    foreach ($c in @(Safe-Array $Facts.configuration.files)) {
        Add-Score -Map $scoreMap -Path $c -Score 7
    }
    foreach ($k in @(Safe-Array $Facts.configuration.keys)) {
        Add-Score -Map $scoreMap -Path $k.file -Score 4
    }

    switch ($PageKind) {
        "api" {
            foreach ($a in @(Safe-Array $Facts.api_endpoints)) { Add-Score -Map $scoreMap -Path $a.file -Score 30 }
        }
        "config" {
            foreach ($c in @(Safe-Array $Facts.configuration.files)) { Add-Score -Map $scoreMap -Path $c -Score 30 }
            foreach ($k in @(Safe-Array $Facts.configuration.keys)) { Add-Score -Map $scoreMap -Path $k.file -Score 10 }
        }
        "qa" {
            foreach ($f in @(Safe-Array $Facts.evidence.key_files)) {
                if ($f -match "scripts/|test|spec") { Add-Score -Map $scoreMap -Path $f -Score 20 }
            }
        }
        "architecture" {
            foreach ($e in @(Safe-Array $Facts.entry_points.backend)) { Add-Score -Map $scoreMap -Path $e.path -Score 25 }
            foreach ($e in @(Safe-Array $Facts.entry_points.frontend)) { Add-Score -Map $scoreMap -Path $e.path -Score 20 }
        }
        "dataflow" {
            foreach ($e in @(Safe-Array $Facts.entry_points.backend)) { Add-Score -Map $scoreMap -Path $e.path -Score 20 }
            foreach ($a in @(Safe-Array $Facts.api_endpoints)) { Add-Score -Map $scoreMap -Path $a.file -Score 20 }
            foreach ($c in @(Safe-Array $Facts.configuration.files)) { Add-Score -Map $scoreMap -Path $c -Score 10 }
        }
        Default {
            foreach ($f in @(Safe-Array $Facts.evidence.key_files)) {
                if ($f -match "README|SKILL|toc\.yaml") { Add-Score -Map $scoreMap -Path $f -Score 15 }
            }
        }
    }

    $ranked = @($scoreMap.GetEnumerator() | Sort-Object Name | Sort-Object Value -Descending | ForEach-Object { $_.Name })
    if ($ranked.Count -eq 0) {
        return @("README.md", "docs/openwiki/toc.yaml", "docs/openwiki/facts.json")
    }
    return @($ranked | Select-Object -First 3)
}

function Build-OverviewBlock {
    param(
        [string]$PageId,
        [string]$PageTitle,
        [string]$PageKind,
        $Facts,
        [string]$PrimarySource
    )
    $apiCount = @(Safe-Array $Facts.api_endpoints).Count
    $configCount = @(Safe-Array $Facts.configuration.keys).Count
    $langCount = @(Safe-Array $Facts.stack.languages).Count
    $confidence = 0
    if ($null -ne $Facts.quality -and $null -ne $Facts.quality.parse_confidence) {
        $confidence = [int]$Facts.quality.parse_confidence
    }
    $gapHint = ""
    if ($null -ne $Facts.quality -and $null -ne $Facts.quality.gaps -and @(Safe-Array $Facts.quality.gaps).Count -gt 0) {
        $gapHint = [string](Safe-Array $Facts.quality.gaps | Select-Object -First 1)
    }
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("## 页面目标")
    [void]$lines.Add("")
    [void]$lines.Add("- 覆盖主题：$PageTitle（$PageId）。")
    [void]$lines.Add("- 本页类型：$PageKind，优先基于 facts.json 的可验证事实生成。")
    [void]$lines.Add("- 当前事实快照：语言 $langCount 类、接口线索 $apiCount 条、配置键 $configCount 个、置信度 $confidence。")
    if (-not [string]::IsNullOrWhiteSpace($gapHint)) {
        [void]$lines.Add("- 当前主要解析缺口：$gapHint")
    }
    [void]$lines.Add("")
    [void]$lines.Add("参考：$PrimarySource")
    return ($lines -join "`n")
}

function Build-ImplementationBlock {
    param(
        [string]$PageKind,
        $Facts,
        [string[]]$Sources
    )
    $src1 = $Sources[0]
    $src2 = if ($Sources.Count -gt 1) { $Sources[1] } else { $Sources[0] }
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("## 关键实现")
    [void]$lines.Add("")

    switch ($PageKind) {
        "api" {
            $apis = @(Safe-Array $Facts.api_endpoints | Select-Object -First 8)
            [void]$lines.Add("- 自动识别接口线索（Top 8）：")
            if ($apis.Count -eq 0) {
                [void]$lines.Add("- 待补充：当前未识别到明确路由声明。")
            } else {
                foreach ($a in $apis) {
                    [void]$lines.Add("- $($a.method) $($a.path) -> $($a.file):$($a.line)")
                }
            }
        }
        "config" {
            $cfgFiles = @(Safe-Array $Facts.configuration.files | Select-Object -First 8)
            $cfgKeys = @(Safe-Array $Facts.configuration.keys | Select-Object -First 8)
            [void]$lines.Add("- 配置文件线索：")
            if ($cfgFiles.Count -eq 0) {
                [void]$lines.Add("- 待补充：未识别到配置文件。")
            } else {
                foreach ($f in $cfgFiles) { [void]$lines.Add("- $f") }
            }
            [void]$lines.Add("")
            [void]$lines.Add("- 关键配置键（Top 8）：")
            if ($cfgKeys.Count -eq 0) {
                [void]$lines.Add("- 待补充：未识别到明确配置键。")
            } else {
                foreach ($k in $cfgKeys) {
                    [void]$lines.Add("- $($k.key)（$($k.file):$($k.line)）")
                }
            }
        }
        "architecture" {
            $backend = @(Safe-Array $Facts.entry_points.backend | Select-Object -First 5)
            $frontend = @(Safe-Array $Facts.entry_points.frontend | Select-Object -First 5)
            [void]$lines.Add("- 后端入口候选：")
            if ($backend.Count -eq 0) {
                [void]$lines.Add("- 待补充：未识别到后端入口。")
            } else {
                foreach ($e in $backend) { [void]$lines.Add("- $($e.path)") }
            }
            [void]$lines.Add("")
            [void]$lines.Add("- 前端入口候选：")
            if ($frontend.Count -eq 0) {
                [void]$lines.Add("- 待补充：未识别到前端入口。")
            } else {
                foreach ($e in $frontend) { [void]$lines.Add("- $($e.path)") }
            }
        }
        "dataflow" {
            [void]$lines.Add("1. 从入口点识别应用边界（backend/frontend/worker）。")
            [void]$lines.Add("2. 从路由声明提取接口线索并定位源码位置。")
            [void]$lines.Add("3. 从配置文件抽取环境键，补齐运行参数上下文。")
            [void]$lines.Add("4. 结合依赖清单与模块目录，形成可追溯的文档证据链。")
        }
        "qa" {
            [void]$lines.Add("- 优先验证：文档结构、标记完整性、链接可达性。")
            [void]$lines.Add("- 建议验证：接口识别是否遗漏、配置键是否覆盖 Dev/Test/Prod。")
            [void]$lines.Add("- 故障定位：先读校验摘要，再回溯对应源码证据。")
        }
        Default {
            $mods = @(Safe-Array $Facts.project.top_modules | Select-Object -First 6)
            [void]$lines.Add("- 模块分布（Top 6）：")
            if ($mods.Count -eq 0) {
                [void]$lines.Add("- 待补充：未识别到模块目录信息。")
            } else {
                foreach ($m in $mods) {
                    [void]$lines.Add("- $($m.name)（$($m.file_count) files）")
                }
            }
        }
    }

    [void]$lines.Add("")
    [void]$lines.Add("参考：$src1、$src2")
    return ($lines -join "`n")
}

function Build-InterfacesBlock {
    param(
        [string]$PageKind,
        $Facts,
        [string]$Source
    )
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("## 关键配置（如有）")
    [void]$lines.Add("")
    [void]$lines.Add("| 配置项 | 作用 | 默认值 | 来源 |")
    [void]$lines.Add("|---|---|---|---|")

    $keys = @(Safe-Array $Facts.configuration.keys | Select-Object -First 5)
    if ($keys.Count -eq 0) {
        [void]$lines.Add("| 待补充 | 待补充 | 待补充 | facts.json |")
    } else {
        foreach ($k in $keys) {
            [void]$lines.Add("| $($k.key) | 待补充 | 待补充 | $($k.file):$($k.line) |")
        }
    }

    [void]$lines.Add("")
    [void]$lines.Add("## API/接口（如有）")
    [void]$lines.Add("")
    $apis = @(Safe-Array $Facts.api_endpoints | Select-Object -First 5)
    if ($apis.Count -eq 0) {
        [void]$lines.Add("- 待补充：未识别到明确接口声明。")
    } else {
        foreach ($a in $apis) {
            [void]$lines.Add("- $($a.method) $($a.path)（$($a.file):$($a.line)）")
        }
    }

    if ($PageKind -eq "api") {
        [void]$lines.Add("")
        [void]$lines.Add("### Mock 响应示例")
        [void]$lines.Add("")
        [void]$lines.Add('```json')
        [void]$lines.Add('{')
        [void]$lines.Add('  "code": 0,')
        [void]$lines.Add('  "message": "OK",')
        [void]$lines.Add('  "data": {}')
        [void]$lines.Add('}')
        [void]$lines.Add('```')
    }

    [void]$lines.Add("")
    [void]$lines.Add("参考：$Source")
    return ($lines -join "`n")
}

function Set-AutogenBlock {
    param(
        [string]$Content,
        [string]$MarkerId,
        [string]$BodyContent,
        [bool]$CreateIfMissing
    )
    $begin = "<!-- BEGIN:AUTOGEN $MarkerId -->"
    $end = "<!-- END:AUTOGEN $MarkerId -->"
    $replacement = "$begin`n$BodyContent`n$end"
    $pattern = "(?s)<!--\s*BEGIN:AUTOGEN\s+$([Regex]::Escape($MarkerId))\s*-->.*?<!--\s*END:AUTOGEN\s+$([Regex]::Escape($MarkerId))\s*-->"
    if ($Content -match $pattern) {
        return [pscustomobject]@{
            content = [Regex]::Replace($Content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
            updated = $true
            inserted = $false
        }
    }

    if ($CreateIfMissing) {
        $newContent = $Content.TrimEnd() + "`n`n---`n`n" + $replacement + "`n"
        return [pscustomobject]@{
            content = $newContent
            updated = $true
            inserted = $true
        }
    }

    return [pscustomobject]@{
        content = $Content
        updated = $false
        inserted = $false
    }
}

function Ensure-PageIdHeader {
    param(
        [string]$Content,
        [string]$PageId
    )
    $lines = @($Content -split "`r?`n")
    $firstMeaningful = $null
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $firstMeaningful = $line.Trim()
            break
        }
    }
    $expected = "<!-- PAGE_ID: $PageId -->"
    if ($firstMeaningful -eq $expected) {
        return $Content
    }
    return "$expected`n`n" + $Content.TrimStart()
}

if (-not (Test-Path -LiteralPath $DocDir)) {
    throw "DocDir 不存在：$DocDir"
}

$facts = Load-Json -Path $FactsPath
$pages = @(Parse-TocPages -Path $TocPath)
if ($pages.Count -eq 0) {
    throw "toc 中未解析到页面条目：$TocPath"
}

$readmeTpl = Load-Template -FileName "README.template.md"
$quickstartTpl = Load-Template -FileName "quickstart.template.md"
$wikiTpl = Load-Template -FileName "wiki-page.template.md"

$docDirToken = Normalize-PathToken -PathText $DocDir
$projectName = if ($null -ne $facts.project.name -and -not [string]::IsNullOrWhiteSpace($facts.project.name)) { [string]$facts.project.name } else { "Project" }
$langItems = @(Safe-Array $facts.stack.languages) | Sort-Object file_count -Descending | ForEach-Object { $_.language }
$frameworkItems = @(Safe-Array $facts.stack.frameworks) | ForEach-Object { [string]$_ }

$readmeTokenMap = @{
    "project_name" = $projectName
    "project_pitch" = (Build-ProjectPitch -Facts $facts)
    "primary_languages" = (Join-Top -Items $langItems -Max 4 -Fallback "待补充")
    "frameworks" = (Join-Top -Items $frameworkItems -Max 5 -Fallback "待补充")
    "entry_points" = (Get-EntryText -Facts $facts)
}

$renderedReadme = Replace-Tokens -Template $readmeTpl -Map $readmeTokenMap
$renderedReadme = $renderedReadme.Replace("docs/openwiki", $docDirToken)

$readmeExists = Test-Path -LiteralPath $ReadmePath
$readmeWritten = $false
if (-not $readmeExists -or $OverwriteExisting) {
    Write-Utf8NoBom -Path $ReadmePath -Content $renderedReadme
    $readmeWritten = $true
}

$quickstartPath = Join-Path $DocDir "quickstart.md"
$renderedQuickstart = $quickstartTpl.Replace("docs/openwiki", $docDirToken)
$quickstartExists = Test-Path -LiteralPath $quickstartPath
$quickstartWritten = $false
if (-not $quickstartExists -or $OverwriteExisting) {
    Write-Utf8NoBom -Path $quickstartPath -Content $renderedQuickstart
    $quickstartWritten = $true
}

$createdPages = 0
$updatedPages = 0
$skippedPages = 0
$insertedBlocks = 0

foreach ($p in $pages) {
    $pageId = [string]$p.id
    $pageTitle = [string]$p.title
    $relative = Normalize-PathToken -PathText ([string]$p.file)
    $fullPath = Join-Path $DocDir (To-PlatformPath -PathText $relative)
    $exists = Test-Path -LiteralPath $fullPath
    $kind = Get-PageKind -PageId $pageId -Title $pageTitle
    $sources = @(Get-ScoredSources -PageKind $kind -Facts $facts)
    if ($sources.Count -lt 3) {
        $sources = @($sources + @("README.md", "$docDirToken/facts.json", "$docDirToken/toc.yaml"))
    }
    $src1 = $sources[0]
    $src2 = $sources[1]
    $src3 = $sources[2]

    if (-not $exists) {
        $content = $wikiTpl
        $content = $content.Replace("{{page_id}}", $pageId)
        $content = $content.Replace("{{page_title}}", $pageTitle)
        $content = $content.Replace("{{source_file_1}}", $src1)
        $content = $content.Replace("{{source_file_2}}", $src2)
        $content = $content.Replace("{{source_file_3}}", $src3)

        $block1 = Build-OverviewBlock -PageId $pageId -PageTitle $pageTitle -PageKind $kind -Facts $facts -PrimarySource $src1
        $block2 = Build-ImplementationBlock -PageKind $kind -Facts $facts -Sources @($src1, $src2, $src3)
        $block3 = Build-InterfacesBlock -PageKind $kind -Facts $facts -Source $src3

        $r1 = Set-AutogenBlock -Content $content -MarkerId "${pageId}_overview" -BodyContent $block1 -CreateIfMissing $true
        $r2 = Set-AutogenBlock -Content $r1.content -MarkerId "${pageId}_implementation" -BodyContent $block2 -CreateIfMissing $true
        $r3 = Set-AutogenBlock -Content $r2.content -MarkerId "${pageId}_interfaces" -BodyContent $block3 -CreateIfMissing $true

        $finalPage = Ensure-PageIdHeader -Content $r3.content -PageId $pageId
        Write-Utf8NoBom -Path $fullPath -Content $finalPage
        $createdPages++
        continue
    }

    $existing = Get-Content -Raw -LiteralPath $fullPath
    $existing = Ensure-PageIdHeader -Content $existing -PageId $pageId

    $block1 = Build-OverviewBlock -PageId $pageId -PageTitle $pageTitle -PageKind $kind -Facts $facts -PrimarySource $src1
    $block2 = Build-ImplementationBlock -PageKind $kind -Facts $facts -Sources @($src1, $src2, $src3)
    $block3 = Build-InterfacesBlock -PageKind $kind -Facts $facts -Source $src3

    $createMissing = [bool]$OverwriteExisting
    $u1 = Set-AutogenBlock -Content $existing -MarkerId "${pageId}_overview" -BodyContent $block1 -CreateIfMissing $createMissing
    $u2 = Set-AutogenBlock -Content $u1.content -MarkerId "${pageId}_implementation" -BodyContent $block2 -CreateIfMissing $createMissing
    $u3 = Set-AutogenBlock -Content $u2.content -MarkerId "${pageId}_interfaces" -BodyContent $block3 -CreateIfMissing $createMissing

    if ($u1.inserted) { $insertedBlocks++ }
    if ($u2.inserted) { $insertedBlocks++ }
    if ($u3.inserted) { $insertedBlocks++ }

    if ($u1.updated -or $u2.updated -or $u3.updated -or $createMissing) {
        if ($u1.updated -or $u2.updated -or $u3.updated) {
            Write-Utf8NoBom -Path $fullPath -Content $u3.content
            $updatedPages++
        } else {
            $skippedPages++
        }
    } else {
        $skippedPages++
    }
}

Write-Host "generate-from-facts: PASS"
Write-Host "doc_dir=$DocDir"
Write-Host "facts=$FactsPath"
Write-Host "readme_written=$readmeWritten, quickstart_written=$quickstartWritten"
Write-Host "pages_created=$createdPages, pages_updated=$updatedPages, pages_skipped=$skippedPages, autogen_blocks_inserted=$insertedBlocks"
if ($DryRun) {
    Write-Host "mode=dry-run"
}
