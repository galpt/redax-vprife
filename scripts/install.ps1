<#
.SYNOPSIS
    Install redax-vprife configuration files for mpv + VapourSynth + RIFE.
.DESCRIPTION
    Copies mpv.conf, VapourSynth scripts, and profiles to the appropriate
    directories.  Compatible with Windows (default) and Linux/macOS.

    By default, mpv.conf is SKIPPED if it already exists (to avoid
    overwriting user-customised settings).  Pass -Force to overwrite it.
    VapourSynth .vpy files are always overwritten (with a .bak backup).
.PARAMETER MpvDir
    Path to mpv configuration directory.
    Default: %APPDATA%\mpv  (Windows)  or  ~/.config/mpv  (Unix)
.PARAMETER VapourSynthDir
    Path to VapourSynth scripts directory (under MpvDir).
    Default: <MpvDir>\vapoursynth
.PARAMETER Force
    Overwrite existing mpv.conf (backup saved as mpv.conf.bak).
.PARAMETER DryRun
    If set, only print what would be copied without copying.
.EXAMPLE
    .\install.ps1                        # safe install (preserves mpv.conf)
    .\install.ps1 -Force                 # overwrite mpv.conf with latest
    .\install.ps1 -DryRun                # preview only
#>

param(
    [string]$MpvDir = "",
    [string]$VapourSynthDir = "",
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# ── Detect platform ──────────────────────────────────────────────────────────
$isWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

# Check for admin rights — warn if running elevated (unnecessary, all paths
# are under %APPDATA% which is user-writable).
$isAdmin = $false
if ($isWindows) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if ($isAdmin) {
    Write-Host "NOTE: Running as Administrator.  This is not required" -ForegroundColor Yellow
    Write-Host "  — all files go under %APPDATA% which is already writable" -ForegroundColor Yellow
    Write-Host "  by your user account.  Continue either way." -ForegroundColor Yellow
    Write-Host ""
}

# On Windows, warn if PowerShell execution policy blocks scripts.
if ($isWindows -and (Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue) -eq "Restricted") {
    Write-Host "NOTE: PowerShell execution policy is Restricted." -ForegroundColor Yellow
    Write-Host "  Run the following to allow script execution:" -ForegroundColor Yellow
    Write-Host "    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned" -ForegroundColor Yellow
    Write-Host ""
}

if (-not $MpvDir) {
    if ($isWindows) {
        $MpvDir = Join-Path $env:APPDATA "mpv"
    } else {
        $MpvDir = [System.IO.Path]::Combine($HOME, ".config", "mpv")
    }
}

if (-not $VapourSynthDir) {
    $VapourSynthDir = Join-Path $MpvDir "vapoursynth"
}

$RepoRoot = Split-Path -Parent $PSScriptRoot

# ── Dry run summary ─────────────────────────────────────────────────────────
Write-Host "=== redax-vprife Installer ===" -ForegroundColor Cyan
Write-Host "  Platform:    $([Environment]::OSVersion.Platform)"
Write-Host "  Mpv config:  $MpvDir"
Write-Host "  VS scripts:  $VapourSynthDir"
Write-Host "  Force:       $Force"
Write-Host "  Dry-run:     $DryRun"
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY-RUN] Would copy: $MpvDir\mpv.conf"
    Write-Host "[DRY-RUN] Would copy: $VapourSynthDir\rife.vpy"
    Write-Host "[DRY-RUN] Would copy: $VapourSynthDir\rife-720p.vpy"
    Write-Host "[DRY-RUN] Would copy: $VapourSynthDir\rife-anime.vpy"
    Write-Host "[DRY-RUN] No files modified."
    return
}

# ── Verify writability before touching anything ─────────────────────────────
$testFile = [System.IO.Path]::Combine($MpvDir, ".redax-vprife-write-test")
try {
    $null = New-Item -ItemType Directory -Path $MpvDir -Force -ErrorAction Stop
    "test" | Out-File -FilePath $testFile -Encoding utf8 -ErrorAction Stop
    Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host ""
    Write-Host "ERROR: Cannot write to $MpvDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script does NOT need Administrator rights." -ForegroundColor Yellow
    Write-Host "All files are written under %APPDATA% which your user" -ForegroundColor Yellow
    Write-Host "account already controls.  Check that:" -ForegroundColor Yellow
    Write-Host "  1. The path exists and is not read-only." -ForegroundColor Yellow
    Write-Host "  2. No other process (antivirus) is locking the folder." -ForegroundColor Yellow
    Write-Host "  3. You are not running from a restricted environment." -ForegroundColor Yellow
    exit 1
}

# ── Create output directories ───────────────────────────────────────────────
if (-not (Test-Path $MpvDir)) {
    $null = New-Item -ItemType Directory -Path $MpvDir -Force
    Write-Host "  Created:  $MpvDir"
}

if (-not (Test-Path $VapourSynthDir)) {
    $null = New-Item -ItemType Directory -Path $VapourSynthDir -Force
    Write-Host "  Created:  $VapourSynthDir"
}

# ── Copy mpv.conf ───────────────────────────────────────────────────────────
$srcMpvConf  = [System.IO.Path]::Combine($RepoRoot, "mpv", "mpv.conf")
$dstMpvConf  = Join-Path $MpvDir "mpv.conf"

if (Test-Path $dstMpvConf) {
    if ($Force) {
        $backup = $dstMpvConf + ".bak"
        Copy-Item -Path $dstMpvConf -Destination $backup -Force
        Write-Host "  BACKUP:   $backup"
        Copy-Item -Path $srcMpvConf -Destination $dstMpvConf -Force
        Write-Host "  COPIED:   $dstMpvConf (forced)"
    } else {
        Write-Host "  SKIP:     $dstMpvConf (already exists — use -Force to overwrite)"
    }
} else {
    Copy-Item -Path $srcMpvConf -Destination $dstMpvConf
    Write-Host "  COPIED:   $dstMpvConf"
}

# Save a reference copy alongside the real config (never overwrites)
$srcMpvConfExample = [System.IO.Path]::Combine($RepoRoot, "mpv", "mpv.conf")
$dstMpvConfExample = Join-Path $MpvDir "mpv.conf.redax-vprife"
if (-not (Test-Path $dstMpvConfExample)) {
    Copy-Item -Path $srcMpvConf -Destination $dstMpvConfExample
    Write-Host "  COPIED:   $dstMpvConfExample (reference copy)"
}

# ── Copy VapourSynth .vpy scripts ──────────────────────────────────────────
$vpyNames = @("rife", "rife-720p", "rife-anime")
foreach ($name in $vpyNames) {
    $src  = [System.IO.Path]::Combine($RepoRoot, "vapoursynth", "$name.vpy")
    $dst  = Join-Path $VapourSynthDir "$name.vpy"
    if (Test-Path $dst) {
        $backup = $dst + ".bak"
        Copy-Item -Path $dst -Destination $backup -Force
        Write-Host "  BACKUP:   $backup"
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  COPIED:   $dst"
}

Write-Host ""
Write-Host "=== Install complete ===" -ForegroundColor Green
Write-Host "Launch mpv with:  mpv video.mkv --profile=rife-720p"
Write-Host ""
Write-Host "If you ran this before and mpv still shows old errors, run:" -ForegroundColor Yellow
Write-Host "  .\install.ps1 -Force" -ForegroundColor Yellow
Write-Host "to overwrite mpv.conf with the latest version (backup saved)." -ForegroundColor Yellow
