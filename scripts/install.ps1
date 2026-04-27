<#
.SYNOPSIS
    Install redax-vprife configuration files for mpv + VapourSynth + RIFE.
.DESCRIPTION
    Copies mpv.conf, VapourSynth scripts, and profiles to the appropriate
    directories.  Compatible with Windows (default) and Linux/macOS.
.PARAMETER MpvDir
    Path to mpv configuration directory.
    Default: %APPDATA%\mpv  (Windows)  or  ~/.config/mpv  (Unix)
.PARAMETER VapourSynthDir
    Path to VapourSynth scripts directory (under MpvDir).
    Default: <MpvDir>\vapoursynth
.PARAMETER DryRun
    If set, only print what would be copied without copying.
.EXAMPLE
    .\install.ps1                     # interactive install
    .\install.ps1 -DryRun             # preview only
#>

param(
    [string]$MpvDir = "",
    [string]$VapourSynthDir = "",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# ── Detect platform ──────────────────────────────────────────────────────────
$isWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

if (-not $MpvDir) {
    if ($isWindows) {
        $MpvDir = "$env:APPDATA\mpv"
    } else {
        $MpvDir = "$HOME\.config\mpv"
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
Write-Host "  Dry-run:     $DryRun"
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY-RUN] Would create: $MpvDir\mpv.conf"
    Write-Host "[DRY-RUN] Would create: $VapourSynthDir\rife.vpy"
    Write-Host "[DRY-RUN] Would create: $VapourSynthDir\rife-720p.vpy"
    Write-Host "[DRY-RUN] Would create: $VapourSynthDir\rife-anime.vpy"
    Write-Host "[DRY-RUN] No files modified."
    return
}

# ── Create directories ──────────────────────────────────────────────────────
if (-not (Test-Path $MpvDir)) {
    New-Item -ItemType Directory -Path $MpvDir -Force | Out-Null
    Write-Host "  Created:  $MpvDir"
}

if (-not (Test-Path $VapourSynthDir)) {
    New-Item -ItemType Directory -Path $VapourSynthDir -Force | Out-Null
    Write-Host "  Created:  $VapourSynthDir"
}

# ── Copy files ──────────────────────────────────────────────────────────────
$vpyNames = @("rife", "rife-720p", "rife-anime")

# mpv.conf — only copy if it doesn't already exist (respect user config)
$srcMpvConf  = Join-Path $RepoRoot "mpv" "mpv.conf"
$dstMpvConf  = Join-Path $MpvDir "mpv.conf"
if (Test-Path $dstMpvConf) {
    Write-Host "  SKIP:     $dstMpvConf (already exists)"
} else {
    Copy-Item -Path $srcMpvConf -Destination $dstMpvConf
    Write-Host "  COPIED:   $dstMpvConf"
}

# Save a reference copy alongside the real config (never overwrites)
$srcMpvConfExample = Join-Path $RepoRoot "mpv" "mpv.conf"
$dstMpvConfExample = Join-Path $MpvDir "mpv.conf.redax-vprife"
if (-not (Test-Path $dstMpvConfExample)) {
    Copy-Item -Path $srcMpvConf -Destination $dstMpvConfExample
    Write-Host "  COPIED:   $dstMpvConfExample (reference copy)"
}

# VapourSynth .vpy scripts
foreach ($name in $vpyNames) {
    $src  = Join-Path $RepoRoot "vapoursynth" "$name.vpy"
    $dst  = Join-Path $VapourSynthDir "$name.vpy"
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  COPIED:   $dst"
}

Write-Host ""
Write-Host "=== Install complete ===" -ForegroundColor Green
Write-Host "Launch mpv with:  mpv video.mkv --profile=rife-720p"
Write-Host "Or set a default profile in $MpvDir\mpv.conf"
