# publish.ps1 - mirror this folder into the GitHub repository
#
# Usage (run inside NyxianROM):
#     powershell -ExecutionPolicy Bypass -File .\tools\publish.ps1
#     powershell -ExecutionPolicy Bypass -File .\tools\publish.ps1 -DryRun
#     powershell -ExecutionPolicy Bypass -File .\tools\publish.ps1 -NoPush
#     powershell -ExecutionPolicy Bypass -File .\tools\publish.ps1 -Message "ui: match iOS layout"
#
# Requires Git:  winget install --id Git.Git -e --source winget
# The proxy is read from Windows Internet Settings and applied to git
# automatically; override with -ProxyUrl, disable with -NoProxy.

param(
    [string]$Repo = "https://github.com/gdufe-GMTech/nyxian-rom-builder.git",
    [string]$Work = "$env:USERPROFILE\GitHub\nyxian-rom-builder",
    [string]$Message = "update NyxianROM",
    [string]$UserName = "gdufe-GMTech",
    [string]$UserEmail = "gdufe-GMTech@users.noreply.github.com",
    [string]$ProxyUrl = "",
    [switch]$NoProxy,
    [switch]$NoPush,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Source = Split-Path -Parent $PSScriptRoot

function Write-Step($text) { Write-Host ">> $text" -ForegroundColor Cyan }
function Write-Warn($text) { Write-Host "!! $text" -ForegroundColor Yellow }

$gitExe = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $gitExe) {
    foreach ($candidate in @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")) {
        if (Test-Path $candidate) { $gitExe = $candidate; break }
    }
}
if (-not $gitExe) {
    Write-Warn "git not found. Install it first:"
    Write-Host "  winget install --id Git.Git -e --source winget"
    exit 1
}
Write-Step "git     : $gitExe"

# ---- proxy ----------------------------------------------------------------
if (-not $NoProxy) {
    if (-not $ProxyUrl) {
        $settings = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
        if ($settings.ProxyEnable -eq 1 -and $settings.ProxyServer) {
            $ProxyUrl = $settings.ProxyServer
            if ($ProxyUrl -notmatch "^[a-zA-Z]+://") { $ProxyUrl = "http://$ProxyUrl" }
        }
    }
    if ($ProxyUrl) {
        Write-Step "proxy   : $ProxyUrl"
        if (-not $DryRun) {
            & $gitExe config --global http.proxy  $ProxyUrl
            & $gitExe config --global https.proxy $ProxyUrl
        }
    } else {
        Write-Step "proxy   : none"
    }
}

Write-Step "source  : $Source"
Write-Step "workdir : $Work"

# ---- clone or update ------------------------------------------------------
if ((Test-Path $Work) -and -not (Test-Path (Join-Path $Work ".git"))) {
    Write-Warn "$Work exists but is not a git repository, removing it"
    if (-not $DryRun) { Remove-Item -Recurse -Force $Work }
}

if (-not (Test-Path $Work)) {
    if ($DryRun) {
        Write-Step "[dry-run] git clone $Repo $Work"
    } else {
        & $gitExe clone $Repo $Work
        if (-not (Test-Path (Join-Path $Work ".git"))) {
            Write-Warn "clone failed. If github.com is unreachable, check the proxy:"
            Write-Host "  git config --global http.proxy http://127.0.0.1:7890"
            exit 1
        }
    }
} else {
    if ($DryRun) { Write-Step "[dry-run] git -C $Work pull --ff-only" }
    else { & $gitExe -C $Work pull --ff-only }
}

$target = Join-Path $Work "NyxianROM"
if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target | Out-Null }

$excludeDirs = @(".git", ".work", "build", "kexts-bin", ".stage", ".rompkg", ".modules", "__pycache__", "Application")
$excludeFiles = @("*.pyc", "rom.zip", "main", "*.ipa")

$robocopyArgs = @("`"$Source`"", "`"$target`"", "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
foreach ($dir in $excludeDirs) { $robocopyArgs += @("/XD", "`"$dir`"") }
foreach ($file in $excludeFiles) { $robocopyArgs += @("/XF", "`"$file`"") }

Write-Step "mirroring"
if ($DryRun) {
    Write-Host ("  [dry-run] robocopy " + ($robocopyArgs -join " "))
} else {
    $proc = Start-Process -FilePath "robocopy" -ArgumentList ($robocopyArgs -join " ") -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ge 8) { throw "robocopy failed with exit code $($proc.ExitCode)" }
    Write-Host "  robocopy exit code $($proc.ExitCode) (0-7 is success)"
}

# stale copy of the workflow that was uploaded into NyxianROM/ by mistake
$stray = Join-Path $target ".github"
if (Test-Path $stray) {
    Write-Step "removing NyxianROM/.github"
    if (-not $DryRun) { Remove-Item -Recurse -Force $stray }
}

if ($DryRun) { Write-Step "[dry-run] done"; exit 0 }

Write-Step "staging"
& $gitExe -C $Work add -A
& $gitExe -C $Work status --short

$changes = & $gitExe -C $Work status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Step "nothing to commit"
    exit 0
}

Write-Step "commit"
& $gitExe -C $Work -c user.name="$UserName" -c user.email="$UserEmail" commit -m "$Message"

if ($NoPush) {
    Write-Step "skipping push (-NoPush). Push manually:"
    Write-Host "  `"$gitExe`" -C `"$Work`" push origin HEAD"
    exit 0
}

Write-Step "push (browser authorization on first run)"
& $gitExe -C $Work push origin HEAD
if ($LASTEXITCODE -ne 0) {
    Write-Warn "push failed. Check the proxy, or run git push manually:"
    Write-Host "  `"$gitExe`" -C `"$Work`" push origin HEAD"
    exit 1
}

Write-Step "done: $($Repo -replace '\.git$','')"
