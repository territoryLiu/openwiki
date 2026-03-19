param(
    [string]$RootDir = ".",
    [string]$DocDir = "docs/openwiki"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Name,
        [string]$Status,
        [string]$Message
    )
    $List.Add([pscustomobject]@{
        name = $Name
        status = $Status
        message = $Message
    }) | Out-Null
}

$checks = [System.Collections.Generic.List[object]]::new()

if (-not (Test-Path -LiteralPath $RootDir)) {
    Add-Check -List $checks -Name "root_dir" -Status "fail" -Message "RootDir 不存在：$RootDir"
}
else {
    Add-Check -List $checks -Name "root_dir" -Status "pass" -Message "RootDir 可访问：$RootDir"
}

if ($PSVersionTable.PSVersion.Major -ge 5) {
    Add-Check -List $checks -Name "powershell_version" -Status "pass" -Message "PowerShell 版本：$($PSVersionTable.PSVersion)"
}
else {
    Add-Check -List $checks -Name "powershell_version" -Status "warn" -Message "PowerShell 版本较低：$($PSVersionTable.PSVersion)"
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    Add-Check -List $checks -Name "ripgrep" -Status "fail" -Message "未检测到 rg，请先安装 ripgrep。"
}
else {
    Add-Check -List $checks -Name "ripgrep" -Status "pass" -Message "rg 可用：$($rg.Source)"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$requiredScripts = @(
    "repo-scan.ps1",
    "generate-from-facts.ps1",
    "migrate-autogen-markers.ps1",
    "validate-lite.ps1",
    "openwiki-run.ps1",
    "smoke-test.ps1"
)
foreach ($s in $requiredScripts) {
    $path = Join-Path $scriptRoot $s
    if (Test-Path -LiteralPath $path) {
        Add-Check -List $checks -Name "script:$s" -Status "pass" -Message "存在"
    }
    else {
        Add-Check -List $checks -Name "script:$s" -Status "fail" -Message "缺失：$path"
    }
}

$rootResolved = if (Test-Path -LiteralPath $RootDir) { (Resolve-Path -LiteralPath $RootDir).Path } else { "" }
if (-not [string]::IsNullOrWhiteSpace($rootResolved)) {
    $docPath = if ([IO.Path]::IsPathRooted($DocDir)) { $DocDir } else { Join-Path $rootResolved $DocDir }
    if (Test-Path -LiteralPath $docPath) {
        Add-Check -List $checks -Name "doc_dir" -Status "pass" -Message "文档目录存在：$docPath"
        $toc = Join-Path $docPath "toc.yaml"
        if (Test-Path -LiteralPath $toc) {
            Add-Check -List $checks -Name "toc" -Status "pass" -Message "toc 存在：$toc"
        }
        else {
            Add-Check -List $checks -Name "toc" -Status "warn" -Message "toc 不存在：$toc（首次运行可忽略）"
        }
    }
    else {
        Add-Check -List $checks -Name "doc_dir" -Status "warn" -Message "文档目录不存在：$docPath（首次运行可忽略）"
    }
}

$failCount = @($checks | Where-Object { $_.status -eq "fail" }).Count
$warnCount = @($checks | Where-Object { $_.status -eq "warn" }).Count
$overall = if ($failCount -gt 0) { "FAIL" } elseif ($warnCount -gt 0) { "WARN" } else { "PASS" }

Write-Host "openwiki-doctor: $overall"
Write-Host "fail=$failCount, warn=$warnCount, checks=$($checks.Count)"
foreach ($c in $checks) {
    Write-Host "[$($c.status)] $($c.name): $($c.message)"
}
