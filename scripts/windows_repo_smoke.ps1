param(
    [string]$Cases,
    [string]$Out,
    [string]$Cjc
)

$ErrorActionPreference = "Stop"

$RepoName = "cj_tui" # CJ_TUI_STAGE_NAME_PLACEHOLDER
$Repo = Join-Path $Cases $RepoName
$Log = Join-Path $Out "cj_tui-smoke.log"
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Add-Log {
    param([string]$Text)
    [System.IO.File]::AppendAllText($Log, $Text + [Environment]::NewLine, $Utf8)
    Write-Output $Text
}

function Invoke-CjpmPackage {
    param(
        [string]$Package,
        [string[]]$CjpmArgs
    )

    if (!(Test-Path $Package)) {
        Add-Log "Missing package: $Package"
        exit 2
    }

    Add-Log "Package=$Package"
    Add-Log "COMMAND: $Cjpm $($CjpmArgs -join ' ')"

    Push-Location $Package
    try {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $runOut = & $Cjpm @CjpmArgs 2>&1
            $rc = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }
        foreach ($line in $runOut) {
            Add-Log ([string]$line)
        }
    } finally {
        Pop-Location
    }

    Add-Log "ExitCode=$rc"
    if ($rc -ne 0) {
        exit $rc
    }
}

$Cjpm = $null
$cmd = Get-Command cjpm.exe -ErrorAction SilentlyContinue
if ($cmd) {
    $Cjpm = $cmd.Source
} elseif ($Cjc) {
    $candidate = Join-Path (Split-Path $Cjc -Parent) "cjpm.exe"
    if (Test-Path $candidate) {
        $Cjpm = $candidate
    }
}

if (!$Cjpm) {
    Add-Log "cjpm.exe not found"
    exit 3
}

$env:NO_COLOR = "1"
Add-Log "Repo=$Repo"
Add-Log "Cjc=$Cjc"
Add-Log "Cjpm=$Cjpm"

Invoke-CjpmPackage (Join-Path $Repo "packages\example_smoke") @("run")
Invoke-CjpmPackage (Join-Path $Repo "examples\game_pressure_suite") @("build")

exit 0
