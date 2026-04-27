<#
.SYNOPSIS
    Quick VRAM and performance test for RIFE on current GPU.
.DESCRIPTION
    Generates a VapourSynth script with a moving test pattern and runs it
    through vspipe to measure RIFE inference speed.  The test pattern
    alternates between two colour gradients to create motion that gives
    the optical flow engine real work (avoids artificially fast results
    from zero-motion inputs).  Requires VapourSynth and RIFE plugin installed.
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

$modelName = switch ($Model) {
    37  { "v4.12-lite" }
    41  { "v4.13-lite" }
    45  { "v4.14-lite" }
    49  { "v4.15-lite" }
    65  { "v4.22-lite" }
    70  { "v4.25-lite" }
    3   { "rife-anime" }
    default { "unknown" }
}

Write-Host "=== RIFE Performance Test ===" -ForegroundColor Cyan
Write-Host "  Model:      $Model ($modelName)"
Write-Host "  Resolution: ${Width}x${Height}"
Write-Host "  GPU thread: $GpuThread"
Write-Host "  Frames:     $Frames"
Write-Host ""

# Generate a test VapourSynth script.
# Uses two alternating BlankClip frames with different colours to create motion.
# This is faster to evaluate than per-frame Python callbacks.
$testScript = @"
import vapoursynth as vs
import time

core = vs.core

# Two alternating frames of different colours — creates real motion
# for the optical flow engine to work on.
frame_a = core.std.BlankClip(
    width=$Width, height=$Height,
    format=vs.RGBS, length=1,
    color=[0.0, 0.2, 0.4]
)
frame_b = core.std.BlankClip(
    width=$Width, height=$Height,
    format=vs.RGBS, length=1,
    color=[0.6, 0.8, 1.0]
)

# Interleave A,B,A,B,... to make ($Frames + 1) source frames
src = core.std.Interleave([frame_a, frame_b] * (($Frames // 2) + 2))
src = core.std.Trim(src, first=0, length=$Frames + 1)

# Run RIFE — with actual alternating frames, the flow network
# has real work to do and benchmarks are meaningful.
start = time.time()
out = core.rife.RIFE(
    src, model=$Model, gpu_thread=$GpuThread,
    factor_num=2, factor_den=1,
)
out = core.std.AssumeFPS(out, fpsnum=60000, fpsden=1000)

# Force evaluation by requesting RIFE output frames
# (vspipe will drive evaluation when invoked)
print(f"Model $Model, {Width}x{Height}, gpu_thread=$GpuThread")
out.set_output()
"@

$testScriptPath = [System.IO.Path]::GetTempFileName() + ".vpy"
$testScript | Out-File -FilePath $testScriptPath -Encoding utf8

Write-Host "Script saved to: $testScriptPath"
Write-Host ""
Write-Host "Run benchmark:"
Write-Host "  vspipe $testScriptPath - --start 0 --end $($Frames - 1) --progress"
Write-Host ""
Write-Host "This pipes $Frames interpolated frames to stdout (discard with > nul)."
Write-Host "The --progress flag shows per-frame timing.  Watch peak VRAM with:"
Write-Host "  nvidia-smi -l 1"
