param(
    [string]$RootDir = ".",
    [string]$DocDir = "docs/openwiki",
    [string]$ReadmePath = "README.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runScript = Join-Path $scriptRoot "openwiki-run.ps1"

if (-not (Test-Path -LiteralPath $runScript)) {
    throw "缺少脚本：$runScript"
}

Write-Host "smoke-test: START"
& $runScript -RootDir $RootDir -DocDir $DocDir -ReadmePath $ReadmePath -DoctorFirst -MigrateMarkers -DryRun -FailOnError
Write-Host "smoke-test: PASS"
