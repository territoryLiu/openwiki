param(
    [string]$RootDir = ".",
    [string]$DocDir = "docs/openwiki",
    [string]$ReadmePath = "README.md",
    [string]$FactsPath = "",
    [string]$TocPath = "",
    [switch]$DoctorFirst,
    [switch]$MigrateMarkers,
    [switch]$OverwriteExisting,
    [switch]$FailOnError,
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

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoScanScript = Join-Path $scriptRoot "repo-scan.ps1"
$migrateScript = Join-Path $scriptRoot "migrate-autogen-markers.ps1"
$generateScript = Join-Path $scriptRoot "generate-from-facts.ps1"
$validateScript = Join-Path $scriptRoot "validate-lite.ps1"
$doctorScript = Join-Path $scriptRoot "openwiki-doctor.ps1"

foreach ($f in @($repoScanScript, $migrateScript, $generateScript, $validateScript, $doctorScript)) {
    if (-not (Test-Path -LiteralPath $f)) {
        throw "缺少脚本：$f"
    }
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "==> $Name"
    & $Action
}

if (-not (Test-Path -LiteralPath $RootDir)) {
    throw "RootDir 不存在：$RootDir"
}

$rootResolved = (Resolve-Path -LiteralPath $RootDir).Path

Push-Location $rootResolved
try {
    if ($DoctorFirst) {
        Invoke-Step -Name "Step 0/4 doctor" -Action {
            & $doctorScript -RootDir "." -DocDir $DocDir
        }
    }

    Invoke-Step -Name "Step 1/4 repo-scan" -Action {
        & $repoScanScript -RootDir "." -OutputPath $FactsPath
    }

    if ($MigrateMarkers) {
        Invoke-Step -Name "Step 2/4 marker-migrate" -Action {
            $wikiDir = Join-Path $DocDir "wiki"
            if ($DryRun) {
                & $migrateScript -WikiDir $wikiDir -DryRun
            }
            else {
                & $migrateScript -WikiDir $wikiDir
            }
        }
    }

    Invoke-Step -Name "Step 3/4 generate-from-facts" -Action {
        if ($DryRun) {
            & $generateScript -DocDir $DocDir -FactsPath $FactsPath -TocPath $TocPath -ReadmePath $ReadmePath -OverwriteExisting:$OverwriteExisting -DryRun
        }
        else {
            & $generateScript -DocDir $DocDir -FactsPath $FactsPath -TocPath $TocPath -ReadmePath $ReadmePath -OverwriteExisting:$OverwriteExisting
        }
    }

    Invoke-Step -Name "Step 4/4 validate-lite" -Action {
        & $validateScript -DocDir $DocDir -ReadmePath $ReadmePath -TocPath $TocPath -FailOnError:$FailOnError
    }

    Write-Host "openwiki-run: PASS"
    Write-Host "root=$rootResolved"
    Write-Host "doc_dir=$DocDir, facts=$FactsPath"
    Write-Host "doctor_first=$DoctorFirst, migrate_markers=$MigrateMarkers, overwrite_existing=$OverwriteExisting, dry_run=$DryRun"
}
finally {
    Pop-Location
}
