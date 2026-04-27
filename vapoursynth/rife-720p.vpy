# =============================================================================
# rife-720p.vpy — VapourSynth RIFE 2x with 720p safe resolution
# Target: NVIDIA RTX 3050 4 GB VRAM
# Model:   rife-v4.14-lite (model=45), gpu_thread=1
# =============================================================================
# Downscales to 720p before RIFE, then upscales back to original resolution.
# This preserves ~1.5 GB VRAM headroom compared to native 1080p, allowing
# gpu_thread=2 for smoother real-time playback.
#
# Place this file in %APDATA%\mpv\vapoursynth\ (Windows)
# or ~/.config/mpv/vapoursynth/ (Linux/macOS)
#
# Load via mpv:  --profile=rife-720p
#          or:   --vf=vapoursynth="~~/vapoursynth/rife-720p.vpy"
# =============================================================================

import vapoursynth as vs

core = vs.core

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
src = video_in

# ---------------------------------------------------------------------------
# Colour conversion  YUV → RGB float32
# ---------------------------------------------------------------------------
rgb = core.resize.Bicubic(src, format=vs.RGBS, matrix_s="709")

# ---------------------------------------------------------------------------
# Downscale to 720p before RIFE — critical for 4 GB VRAM budget
# ---------------------------------------------------------------------------
target_width = 1280
target_height = 720

rgb = core.resize.Bicubic(
    rgb,
    width=target_width,
    height=target_height,
    filter_param_a=0.333,   # B-spline (smooth downscale)
    filter_param_b=0.333,
)

# ---------------------------------------------------------------------------
# RIFE interpolation
#
# model       = 45   → rife-v4.14-lite (ensemble=False)
#                      Slightly newer than v4.12-lite; still lightweight.
# gpu_thread  = 2    → At 720p, two inference queues fit in 4 GB VRAM.
#                      This doubles throughput vs gpu_thread=1.
# ---------------------------------------------------------------------------
out = core.rife.RIFE(
    rgb,
    model=45,
    gpu_thread=2,
    sc=False,
    factor_num=2,
    factor_den=1,
)

# ---------------------------------------------------------------------------
# Upscale back to original resolution  (720p → 1080p)
# ---------------------------------------------------------------------------
out = core.resize.Bicubic(
    out,
    width=src.width,
    height=src.height,
    filter_param_a=0.333,
    filter_param_b=0.333,
)

# ---------------------------------------------------------------------------
# Colour conversion back to YUV
# ---------------------------------------------------------------------------
out = core.resize.Bicubic(out, format=vs.YUV420P8, matrix_s="709")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
out.set_output()
