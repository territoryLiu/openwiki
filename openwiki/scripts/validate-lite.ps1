param(
    [string]$DocDir = "docs/openwiki",
    [string]$ReadmePath = "README.md",
    [string]$TocPath = "",
    [string]$SummaryPath = "",
    [switch]$FailOnError
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TocPath)) {
    $TocPath = Join-Path $DocDir "toc.yaml"
}
if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
    $SummaryPath = Join-Path $DocDir "SUMMARY.md"
}

function Add-Issue {
    param(
        [ref]$Issues,
        [string]$Severity,
        [string]$Category,
        [string]$Message
    )
    $Issues.Value += [pscustomobject]@{
        severity = $Severity
        category = $Category
        message  = $Message
    }
}

function Get-RelativePathsFromReadmeLinks {
    param(
        [string]$ReadmeFile
    )
    if (-not (Test-Path -LiteralPath $ReadmeFile)) {
        return @()
    }

    $content = Get-Content -LiteralPath $ReadmeFile -Raw
    $dir = Split-Path -Parent $ReadmeFile
    if ([string]::IsNullOrWhiteSpace($dir)) {
        $dir = "."
    }

    $pattern = '\[[^\]]+\]\(([^)]+)\)'
    $matches = [regex]::Matches($content, $pattern)
    $results = @()
    foreach ($m in $matches) {
        $rawTarget = $m.Groups[1].Value.Trim()
        if ($rawTarget -match '^(https?:|mailto:|#)') {
            continue
        }
        $pathOnly = $rawTarget.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly)) {
            continue
        }
        $normalized = $pathOnly -replace '/', [IO.Path]::DirectorySeparatorChar
        $results += (Join-Path $dir $normalized)
    }
    return $results
}

function Parse-TocFiles {
    param(
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }
    $lines = Get-Content -LiteralPath $Path
    $files = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*file:\s*(.+?)\s*$') {
            $files += $matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $files
}

function Test-AutogenMarkers {
    param(
        [string]$FilePath
    )
    $result = [pscustomobject]@{
        beginCount = 0
        endCount = 0
        ok = $true
        errors = @()
    }

    $lines = Get-Content -LiteralPath $FilePath
    $stack = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNo = $i + 1
        $line = $lines[$i]

        if ($line -match '^\s*<!--\s*BEGIN:AUTOGEN\s+([A-Za-z0-9_\-\.]+)\s*-->\s*$') {
            $id = $matches[1]
            $stack.Add([pscustomobject]@{ id = $id; line = $lineNo })
            $result.beginCount++
            continue
        }

        if ($line -match '^\s*<!--\s*END:AUTOGEN\s+([A-Za-z0-9_\-\.]+)\s*-->\s*$') {
            $id = $matches[1]
            $result.endCount++
            if ($stack.Count -eq 0) {
                $result.ok = $false
                $result.errors += "第 $lineNo 行 END:AUTOGEN $id 无对应 BEGIN。"
                continue
            }
            $top = $stack[$stack.Count - 1]
            $stack.RemoveAt($stack.Count - 1)
            if ($top.id -ne $id) {
                $result.ok = $false
                $result.errors += "第 $lineNo 行 END:AUTOGEN $id 与 BEGIN:AUTOGEN $($top.id) 不匹配（BEGIN 在第 $($top.line) 行）。"
            }
        }
    }

    if ($stack.Count -gt 0) {
        $result.ok = $false
        foreach ($item in $stack) {
            $result.errors += "第 $($item.line) 行 BEGIN:AUTOGEN $($item.id) 无对应 END。"
        }
    }

    if ($result.beginCount -ne $result.endCount) {
        $result.ok = $false
        $result.errors += "BEGIN/END 数量不一致：BEGIN=$($result.beginCount), END=$($result.endCount)。"
    }

    return $result
}

$issues = @()
$warnings = @()

$wikiDir = Join-Path $DocDir "wiki"
$pagesChecked = 0
$pageIdMissing = 0
$autogenPairs = 0
$autogenFilesWithError = 0

if (-not (Test-Path -LiteralPath $wikiDir)) {
    Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "structure" -Message "未找到 wiki 目录：$wikiDir"
}

if (-not (Test-Path -LiteralPath $TocPath)) {
    Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "structure" -Message "未找到 toc 文件：$TocPath"
}

$wikiFiles = @()
if (Test-Path -LiteralPath $wikiDir) {
    $wikiFiles = Get-ChildItem -LiteralPath $wikiDir -Filter *.md -File | Sort-Object Name
}

foreach ($file in $wikiFiles) {
    $pagesChecked++
    $lines = Get-Content -LiteralPath $file.FullName
    $firstMeaningful = $null
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $firstMeaningful = $line.Trim()
            break
        }
    }

    if ($null -eq $firstMeaningful -or $firstMeaningful -notmatch '^<!--\s*PAGE_ID:\s*([A-Za-z0-9_\-\.]+)\s*-->$') {
        $pageIdMissing++
        Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "page_id" -Message "$($file.Name) 缺少首段 PAGE_ID 标记。"
    }

    $markerResult = Test-AutogenMarkers -FilePath $file.FullName
    $autogenPairs += $markerResult.beginCount
    if (-not $markerResult.ok) {
        $autogenFilesWithError++
        foreach ($e in $markerResult.errors) {
            Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "autogen" -Message "$($file.Name): $e"
        }
    }
}

# README 链接校验
$readmeLinks = @(Get-RelativePathsFromReadmeLinks -ReadmeFile $ReadmePath)
if ($readmeLinks.Count -eq 0) {
    $warnings += [pscustomobject]@{
        severity = "warning"
        category = "readme_link"
        message  = "README 未发现可校验的相对路径链接。"
    }
}
foreach ($target in $readmeLinks) {
    if (-not (Test-Path -LiteralPath $target)) {
        Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "readme_link" -Message "README 链接目标不存在：$target"
    }
}

# toc 路径校验
$tocFiles = @(Parse-TocFiles -Path $TocPath)
foreach ($entry in $tocFiles) {
    $normalized = $entry -replace '/', [IO.Path]::DirectorySeparatorChar
    $fullPath = Join-Path $DocDir $normalized
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Add-Issue -Issues ([ref]$issues) -Severity "error" -Category "toc_file" -Message "toc 页面路径不存在：$entry（期望：$fullPath）"
    }
}

$totalErrors = @($issues | Where-Object { $_.severity -eq "error" }).Count
$totalWarnings = $warnings.Count
$overall = if ($totalErrors -eq 0) { "PASS" } else { "FAIL" }

if (-not (Test-Path -LiteralPath $DocDir)) {
    New-Item -Path $DocDir -ItemType Directory -Force | Out-Null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatePath = Join-Path $scriptRoot "..\templates\SUMMARY.template.md"
$issueLines = @()
if ($issues.Count -eq 0) {
    $issueLines += "- 无错误。"
} else {
    foreach ($item in $issues) {
        $issueLines += "- [$($item.category)] $($item.message)"
    }
}

$warningLines = @()
if ($warnings.Count -eq 0) {
    $warningLines += "- 无警告。"
} else {
    foreach ($item in $warnings) {
        $warningLines += "- [$($item.category)] $($item.message)"
    }
}

$reportBody = ""
if (Test-Path -LiteralPath $templatePath) {
    $reportBody = Get-Content -LiteralPath $templatePath -Raw
} else {
    $reportBody = @"
# OpenWiki Summary

生成时间：{{generated_at}}
状态：{{overall_status}}

## 统计

- Pages checked: {{pages_checked}}
- PAGE_ID missing: {{page_id_missing}}
- AUTOGEN pairs: {{autogen_pairs}}
- Files with AUTOGEN errors: {{autogen_files_with_error}}
- Errors: {{error_count}}
- Warnings: {{warning_count}}

## Errors

{{issues_block}}

## Warnings

{{warnings_block}}
"@
}

$reportBody = $reportBody.Replace("{{generated_at}}", (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
$reportBody = $reportBody.Replace("{{overall_status}}", $overall)
$reportBody = $reportBody.Replace("{{doc_dir}}", $DocDir)
$reportBody = $reportBody.Replace("{{toc_path}}", $TocPath)
$reportBody = $reportBody.Replace("{{readme_path}}", $ReadmePath)
$reportBody = $reportBody.Replace("{{pages_checked}}", [string]$pagesChecked)
$reportBody = $reportBody.Replace("{{page_id_missing}}", [string]$pageIdMissing)
$reportBody = $reportBody.Replace("{{autogen_pairs}}", [string]$autogenPairs)
$reportBody = $reportBody.Replace("{{autogen_files_with_error}}", [string]$autogenFilesWithError)
$reportBody = $reportBody.Replace("{{error_count}}", [string]$totalErrors)
$reportBody = $reportBody.Replace("{{warning_count}}", [string]$totalWarnings)
$reportBody = $reportBody.Replace("{{issues_block}}", ($issueLines -join [Environment]::NewLine))
$reportBody = $reportBody.Replace("{{warnings_block}}", ($warningLines -join [Environment]::NewLine))

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$summaryDir = Split-Path -Parent $SummaryPath
if (-not [string]::IsNullOrWhiteSpace($summaryDir) -and -not (Test-Path -LiteralPath $summaryDir)) {
    New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
}
[System.IO.File]::WriteAllText($SummaryPath, $reportBody, $utf8NoBom)

Write-Host "validate-lite: $overall"
Write-Host "pages=$pagesChecked, errors=$totalErrors, warnings=$totalWarnings"
Write-Host "summary=$SummaryPath"

if ($FailOnError -and $totalErrors -gt 0) {
    exit 1
}
