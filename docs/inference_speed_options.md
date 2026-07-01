# InfiniteTalk Inference Speed Options

This note captures the practical options for making our local InfiniteTalk batch generation faster on the RTX 4090.

## Current Baseline

- GPU: RTX 4090-class card with about 24 GB VRAM.
- Current output size: `infinitetalk-480`.
- Current batch settings:
  - `--sample_steps 8`
  - `--mode streaming`
  - `--frame_num 81`
  - `--max_frame_num 233`
  - `--num_persistent_param_in_dit 0`
  - `--offload_model True`
- Observed runtime: roughly 39-40 minutes per 9-10 second video.
- Current prompt to keep:

```text
A natural close-up talking selfie video. The person looks into the camera, speaks warmly, and keeps a realistic expression and posture.
```

## Biggest Likely Slowdowns Right Now

### 1. Low-VRAM mode is enabled

We are currently using:

```bash
--num_persistent_param_in_dit 0
--offload_model True
```

This keeps VRAM usage lower, but it can slow inference because model weights/modules are moved between CPU and GPU.

For a speed test on a 24 GB 4090, try:

```bash
--offload_model False
```

and omit:

```bash
--num_persistent_param_in_dit 0
```

Risk: peak VRAM may exceed what `nvidia-smi` shows during the middle of a run. Test on one image first.

### 2. We reload the model per video

The current batch script launches `generate_infinitetalk.py` once per image. That reloads the model each time, adding several minutes of overhead per video.

Best future optimization: make or use a warm batch runner that loads the pipeline once, then processes all images in one Python process.

## LoRA Speed Options

The repo README mentions two distillation LoRAs for faster inference:

### FusionX / FusioniX LoRA

README notes:

- Can run at around `8` steps.
- May improve speed and sometimes quality.
- Warning from README: it can worsen color shift over longer videos and reduce identity preservation.

Example shape:

```bash
--lora_dir weights/Wan2.1_I2V_14B_FusionX_LoRA.safetensors
--lora_scale 1.0
--sample_steps 8
--sample_text_guide_scale 1
--sample_audio_guide_scale 2
```

For our current use case, this is worth testing because we are already using `8` steps, but if the LoRA is distilled for low-step inference it may make those 8 steps more usable or allow cleaner output at similar/fewer steps.

### lightx2v LoRA

README says lightx2v can run at around `4` steps.

Example shape:

```bash
--lora_dir weights/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors
--lora_scale 1.0
--sample_steps 4
--sample_text_guide_scale 1
--sample_audio_guide_scale 2
```

This is the most aggressive speed option, but it needs a quality check. It may be faster, but motion, identity, mouth sync, or image fidelity could degrade.

## Missing Install That May Help: SageAttention

The code has a SageAttention path in:

```text
wan/modules/multitalk_model.py
```

It automatically uses SageAttention if this import works:

```python
from sageattention import sageattn
```

Current environment check showed:

```text
sageattention: not installed
flash_attn: installed
```

So we are using FlashAttention now, not SageAttention.

Installing SageAttention may speed up attention-heavy parts of the model. It should be tested after the current batch, not mid-run.

## TeaCache

TeaCache is supported by this repo:

```bash
--use_teacache
--teacache_thresh 0.2
```

This can speed up generation by reusing/cache-skipping parts of denoising. It is a good low-effort speed test, but it can change quality, so test one image first.

## Recommended Test Order

Use one representative image and the reliable prompt above.

1. Baseline one-image run with current settings.
2. Disable low-VRAM offload:

```bash
--offload_model False
```

and remove:

```bash
--num_persistent_param_in_dit 0
```

3. Add TeaCache:

```bash
--use_teacache --teacache_thresh 0.2
```

4. Install/test SageAttention.
5. Test FusionX LoRA at `8` steps with guide scales `1` and `2`.
6. Test lightx2v LoRA at `4` steps with guide scales `1` and `2`.

## Practical Decision Matrix

| Option | Expected Speed Impact | Quality Risk | Notes |
| --- | --- | --- | --- |
| Disable low-VRAM offload | Medium to high | Low if VRAM fits | Best first test on 4090 |
| Warm batch runner | Medium | None | Avoids reload overhead per video |
| TeaCache | Medium | Low to medium | Easy to try |
| SageAttention | Medium | Low | Missing install; code auto-detects it |
| FusionX LoRA | Medium to high | Medium | README warns about color/ID issues |
| lightx2v LoRA | High | Medium to high | 4-step target, must quality-check |

## Recommendation

First test speed without low-VRAM mode. If it fits in VRAM, that is the cleanest win because it should not intentionally reduce generation quality.

Next, test TeaCache and SageAttention.

Then test FusionX and lightx2v LoRAs as separate quality/speed experiments. Keep the prompt unchanged so the comparison is fair.
