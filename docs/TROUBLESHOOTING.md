# Troubleshooting

Common issues when setting up RIFE interpolation with mpv + VapourSynth on
an RTX 3050 4 GB.

## Dual-GPU laptops (Intel + NVIDIA)

Most RTX 3050 laptops are dual-GPU (Intel UHD Graphics + NVIDIA GeForce).
The Vulkan device order is typically:
- Index 0 → Intel iGPU (zero compute queues — **not usable with ncnn**)
- Index 1 → NVIDIA RTX 3050 (2+ compute queues — **must use this**)

The configs in this repo ship with `gpu_id=1` in every `.vpy` script.
If you only have a single GPU (desktop RTX 3050), change `gpu_id=1` to
`gpu_id=0` or remove the parameter.

To verify your device layout, run a test script:
```python
core.rife.RIFE(rgb, list_gpu=True)
```

---

## RIFE plugin not found

```
Failed to create filter chain: vapoursynth: script evaluation failed:
No attribute 'rife'
```

**Cause:**  VapourSynth cannot find the RIFE plugin DLL.

**Fix:**
1. Verify `rife.dll` is in `%APPDATA%\VapourSynth\plugins64\`.
2. Verify the `models/` folder is in the same directory as `rife.dll`.
3. Run: `vspipe --verbose` — look for lines containing `rife`.
4. If missing, reinstall the plugin or copy manually.

---

## Black screen in mpv

**Cause:**  mpv is not receiving valid frames from VapourSynth.

**Fix:**
1. Test the script using mpv (since `video_in` is mpv-specific and not available
   when running `vspipe` standalone):
   ```
   mpv --no-audio --frames=10 --vf=vapoursynth="~~/vapoursynth/rife.vpy" video.mkv
   ```
   If this errors, there is a problem with the VapourSynth script itself.
2. Check the mpv console (`~` key) for VapourSynth error messages.
3. Common causes:
   - The input clip format is not supported (RIFE requires RGB float32).
   - `matrix_s="709"` is wrong for the source content (try `"470bg"` or `"170m"`).
   - Missing VapourSynth plugin (fmtc, resize, etc.).

---

## VRAM out of memory / Vulkan OOM

```
Vulkan: Failed to allocate memory
```

**Cause:**  RIFE inference exceeds 4 GB VRAM.

**Fix:**
1. Switch to the `rife-720p` profile (reduces per-frame VRAM ~55%).
2. Reduce `gpu_thread` to 1 in the `.vpy` script.
3. Use a lighter model: `model=37` (v4.12-lite) or `model=3` (rife-anime).
4. Close other GPU-intensive applications (browser with HW acceleration, games).
5. Monitor VRAM usage:
   ```
   nvidia-smi -l 1
   ```

**Expected VRAM budgets for RTX 3050 4 GB:**

| Configuration | VRAM used | Headroom |
|--------------|:---------:|:--------:|
| 720p, v4.14-lite, gpu_thread=2 | ~1.8 GB | ~2.2 GB |
| 1080p, v4.12-lite, gpu_thread=1 | ~2.5 GB | ~1.5 GB |
| 1080p, v4.12-lite, gpu_thread=2 | ~3.8 GB | ~0.2 GB — **risky** |
| 1080p, v4.25, gpu_thread=2 | ~5.1 GB | **OOM** |
| 1080p, rife-anime, gpu_thread=2 | ~1.5 GB | ~2.5 GB |

---

## Playback stutters / frame drops

**Cause:**  RIFE inference is slower than the output frame interval.

**Fix:**
1. Check displayed FPS: press `I` in mpv (show stats).
2. Compare with target FPS (e.g. 48 fps for 24→48 interpolation).
3. Try the `rife-720p` profile — it cuts pixel count by 55%.
4. Reduce `gpu_thread` to 1 (fewer concurrent inferences = more VRAM
   per inference = potentially faster individual frames, counter-intuitively).
5. Set `video-sync=display-vdrop` instead of `display-resample` in mpv — this
   allows mpv to drop frames when rendering falls behind.
6. For 60 fps→120 fps interpolation, drop to 720p first.

---

## Ghosting / artifacts at scene cuts

**Cause:**  RIFE interpolates across a scene change, blending two unrelated
frames.

**Fix:**
- Enable scene-change detection.  Add to your `.vpy`:

```python
y = core.resize.Bicubic(src, format=vs.GRAYS, matrix_s="709")
y = core.misc.SCDetect(y, threshold=0.1)

def _cp(n, f):
    f[0].props["_SceneChangeNext"] = f[1].props["_SceneChangeNext"]
    return f[0]

rgb = core.std.ModifyFrame(rgb, clips=[rgb, y], selector=_cp)
out = core.rife.RIFE(rgb, model=37, gpu_thread=1, sc=True)
```

Then set `sc=True` in the RIFE call.

---

## mpv.conf syntax error

**Cause:**  Incorrect escape characters or missing quotes.

**Fix:**
- Use `~~/` (tilde-tilde) for mpv config-relative paths.
- If paths contain spaces, use the `%n%"..."` quoting:
  ```
  vf=vapoursynth="%31%C:\Users\Me\My Scripts\rife.vpy"
  ```
- Backslashes in paths are fine on Windows inside mpv.conf.

---

## Vulkan not detected

```
[vo/gpu-next/vulkan] No device found
```

**Cause:**  Vulkan drivers not installed or GPU driver too old.

**Fix:**
1. Update NVIDIA driver to 545+.
2. Verify Vulkan support:
   ```
   vulkaninfo | grep "deviceName"
   ```
   Should show "NVIDIA GeForce RTX 3050".
3. Install [Vulkan Runtime](https://vulkan.lunarg.com/sdk/home) if needed.

---

## RIFE: failed to load model

```
RIFE: failed to load model
```

**Cause:**  The plugin can't open `flownet.param` inside the model
directory.  This is almost always a **models-directory layout** issue
— the plugin derives the path from its own DLL location:

```
{plugin_dir}\models\{model_name}\flownet.param
```

The `model_name` is auto-generated from the `model=` parameter value.
For example, `model=45` looks for:
```
{plugin_dir}\models\rife-v4.14-lite_ensembleFalse\flownet.param
```

**Verify the directory layout:**

Run this in PowerShell to check where VapourSynth expects the models:

```powershell
# Find where rife.dll is loaded from
python -c "import vapoursynth; print(vapoursynth.core.get_plugins()['com.holywu.rife'].path)"
```

The expected models path is the DLL's directory + `\models\`.
For example, if the DLL is at:
```
%APPDATA%\VapourSynth\plugins64\rife.dll
```
Then models must be at:
```
%APPDATA%\VapourSynth\plugins64\models\
```

**Correct layout:**
```
%APPDATA%\VapourSynth\plugins64\
    rife.dll
    models\
        rife-v4.12-lite_ensembleFalse\
            flownet.param
        rife-v4.14-lite_ensembleFalse\
            flownet.param
        rife-anime\
            flownet.param
```

**Wrong layouts that cause this error:**
- ❌ `models\` is inside the ZIP but was never extracted
- ❌ `models\` is in a different folder (e.g. next to `mpv.exe`)
- ❌ Only `rife.dll` was copied, the `models\` directory was skipped
- ❌ The ZIP was extracted to a temp folder and only `rife.dll` was moved

**Tip:** If you're unsure, pass `model_path` explicitly in your `.vpy`
script to a known-good path where the models exist:

```python
out = core.rife.RIFE(rgb, model=37, model_path="C:/path/to/models/rife-v4.12-lite_ensembleFalse", ...)
```

---

## ncnn: failed to create GPU instance

```
RIFE: failed to create GPU instance
```

**Cause:**  The RIFE plugin cannot initialise the Vulkan GPU context.

**Fix:**
1. Verify your GPU supports Vulkan 1.2+ (NVIDIA driver 545+).
2. Ensure `gpu_id` points to a discrete GPU, not an integrated GPU
   with zero compute queues.  Use `list_gpu=True` to enumerate:
   ```python
   core.rife.RIFE(rgb, list_gpu=True)
   ```
3. Try specifying the GPU ID explicitly in your `.vpy` script:
   ```python
   out = core.rife.RIFE(rgb, gpu_id=1, ...)
   ```

---

## Audio desync

**Cause:**  RIFE processing adds latency and occasional frame drops, causing
audio to drift ahead of video.

**Fix:**
1. In mpv.conf, set `video-sync=display-resample`.
2. If desync persists, try `video-sync=audio` (syncs video to audio clock).
3. Reduce RIFE load (720p profile) to minimise frame drops.
4. Increase audio buffer:
   ```
   audio-buffer=2
   ```

---

## Seeking is slow

**Cause:**  VapourSynth needs to decode and process frames sequentially from
the nearest keyframe; RIFE adds a significant per-frame cost.

**Fix:**
- This is inherent to the VapourSynth pipeline.  Use smaller seeks or
  pre-encoded files for smooth scrubbing.
- Consider using `--hr-seek=no` for faster (but less accurate) seeking.

---

## No improvement over native playback

**Cause:**  Source is already 60 fps content or display refresh matches source.

**Fix:**
- RIFE only helps when the source frame rate is lower than the display refresh.
  - 24 fps → 48 fps display: visible smoothness improvement.
  - 60 fps → 120 fps display: still helps but diminishing returns.
  - 60 fps → 60 fps display: no benefit.
- Use `factor_num=4` for 4x interpolation (stronger effect, heavier compute).

---

## Where to get help

- [VapourSynth Discussions](https://github.com/vapoursynth/vapoursynth/discussions)
- [mpv issue tracker](https://github.com/mpv-player/mpv/issues)
- [RIFE plugin issues](https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/issues)
