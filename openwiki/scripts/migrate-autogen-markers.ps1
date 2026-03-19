param(
    [string]$WikiDir = "docs/openwiki/wiki",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-AutogenIds {
    param(
        [string]$Content,
        [string]$PageId
    )

    $expected = @(
        "${PageId}_overview",
        "${PageId}_implementation",
        "${PageId}_interfaces"
    )

    $beginMatches = [regex]::Matches($Content, '(?m)^<!--\s*BEGIN:AUTOGEN\s+([A-Za-z0-9_\-\.]+)\s*-->')
    $beginIds = New-Object System.Collections.Generic.List[string]
    foreach ($m in $beginMatches) {
        $id = $m.Groups[1].Value
        if (-not $beginIds.Contains($id)) {
            $beginIds.Add($id)
        }
    }

    if ($beginIds.Count -eq 0) {
        return [pscustomobject]@{
            content = $Content
            changed = $false
            mapping = @{}
        }
    }

    $mapping = @{}
    for ($i = 0; $i -lt [Math]::Min(3, $beginIds.Count); $i++) {
        $old = $beginIds[$i]
        $new = $expected[$i]
        if ($old -ne $new) {
            $mapping[$old] = $new
        }
    }

    if ($mapping.Count -eq 0) {
        return [pscustomobject]@{
            content = $Content
            changed = $false
            mapping = @{}
        }
    }

    $result = $Content
    foreach ($old in $mapping.Keys) {
        $new = $mapping[$old]
        $result = [regex]::Replace($result, "(?m)^<!--\s*BEGIN:AUTOGEN\s+$([regex]::Escape($old))\s*-->\s*$", "<!-- BEGIN:AUTOGEN $new -->")
        $result = [regex]::Replace($result, "(?m)^<!--\s*END:AUTOGEN\s+$([regex]::Escape($old))\s*-->\s*$", "<!-- END:AUTOGEN $new -->")
    }

    return [pscustomobject]@{
        content = $result
        changed = $true
        mapping = $mapping
    }
}

if (-not (Test-Path -LiteralPath $WikiDir)) {
    throw "wiki 目录不存在：$WikiDir"
}

$files = Get-ChildItem -LiteralPath $WikiDir -Filter *.md -File | Sort-Object Name
$changedFiles = 0
$changedMarkers = 0

foreach ($f in $files) {
    $content = Get-Content -Raw -LiteralPath $f.FullName
    if (-not ($content -match '(?m)^<!--\s*PAGE_ID:\s*([A-Za-z0-9_\-\.]+)\s*-->')) {
        continue
    }
    $pageId = $Matches[1]
    $norm = Normalize-AutogenIds -Content $content -PageId $pageId
    if (-not $norm.changed) {
        continue
    }

    $changedFiles++
    $changedMarkers += $norm.mapping.Count

    if (-not $DryRun) {
        [System.IO.File]::WriteAllText($f.FullName, $norm.content, [System.Text.UTF8Encoding]::new($false))
    }

    $pairs = @()
    foreach ($k in $norm.mapping.Keys) {
        $pairs += "$k -> $($norm.mapping[$k])"
    }
    Write-Host "$($f.Name): $($pairs -join ', ')"
}

Write-Host "migrate-autogen-markers: PASS"
Write-Host "wiki_dir=$WikiDir, files_changed=$changedFiles, markers_changed=$changedMarkers"
if ($DryRun) {
    Write-Host "mode=dry-run"
}
