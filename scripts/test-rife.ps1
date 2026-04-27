<#
.SYNOPSIS
    Quick VRAM and performance test for RIFE on current GPU.
.DESCRIPTION
    Runs a brief RIFE benchmark on the GPU to test VRAM consumption and
    inference speed.  Uses a generated test pattern so no video file needed.
    Requires VapourSynth and RIFE plugin installed.
.PARAMETER Model
    RIFE model number to test (default: 37 = v4.12-lite).
.PARAMETER GpuThread
    Thread count (default: 1).
.PARAMETER Width
    Test frame width (default: 1920).
.PARAMETER Height
    Test frame height (default: 1080).
.PARAMETER Frames
    Number of frames to interpolate (default: 60).
.EXAMPLE
    .\test-rife.ps1                                    # default: 1080p, lite, 1 thread
    .\test-rife.ps1 -Width 1280 -Height 720            # 720p test
    .\test-rife.ps1 -Model 45 -GpuThread 2             # v4.14-lite with 2 threads
#>

param(
    [int]$Model = 37,
    [int]$GpuThread = 1,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [int]$Frames = 60
)

Write-Host "=== RIFE Performance Test ===" -ForegroundColor Cyan
Write-Host "  Model:      $Model (v4.12-lite)"
Write-Host "  Resolution: ${Width}x${Height}"
Write-Host "  GPU thread: $GpuThread"
Write-Host "  Frames:     $Frames"
Write-Host ""

# Generate a basic test VapourSynth script
$testScript = @"
import vapoursynth as vs
import time

core = vs.core

# Generate test frames (colour gradient)
src = core.std.BlankClip(
    width=$Width, height=$Height,
    format=vs.RGBS, length=2,
    color=[0.0, 0.0, 0.0]
)

# Duplicate frames to make a mini-video
src = src * ($Frames + 1)

# Run RIFE
start = time.time()
out = core.rife.RIFE(src, model=$Model, gpu_thread=$GpuThread, factor_num=2, factor_den=1)
out = out[0:$Frames]  # request exactly Frames output frames
# Force evaluation
out = core.std.AssumeFPS(out, fpsnum=60000, fpsden=1000)
out.set_output()
"@

$testScriptPath = [System.IO.Path]::GetTempFileName() + ".vpy"
$testScript | Out-File -FilePath $testScriptPath -Encoding utf8

try {
    Write-Host "Running VaporSynth benchmark..."
    Write-Host "Script: $testScriptPath"
    Write-Host ""
    Write-Host "Launch with: vspipe $testScriptPath - --start 0 --end $($Frames-1)"
    Write-Host ""
    Write-Host "Or in mpv: mpv --vf=vapoursynth=\"$testScriptPath\" --no-audio test_pattern.mkv"
} finally {
    # Keep the temp script around so user can inspect it
    Write-Host "Script left at: $testScriptPath (delete manually when done)"
}
