# InfiniteTalk Benchmark Notes

These notes capture the setup used for the talking selfie benchmark run on
2026-06-30 and the GPU tradeoffs to keep in mind for future Vast.ai machines.

## Model Stack Used

The successful talking selfie run used the full 14B 480p InfiniteTalk stack:

- Task: `infinitetalk-14B`
- Size: `infinitetalk-480`
- Base model: `weights/Wan2.1-I2V-14B-480P`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
- Audio encoder: `weights/chinese-wav2vec2-base`
- Text encoder checkpoint: `models_t5_umt5-xxl-enc-bf16.pth`
- Image encoder checkpoint: `models_clip_open-clip-xlm-roberta-large-vit-huge-14.pth`
- VAE checkpoint: `Wan2.1_VAE.pth`

This was not a quantized run:

- `quant_dir=None`
- `quant=None`
- model parameter dtype: `torch.bfloat16`
- CLIP dtype: `torch.float16`

## Successful Run

The generated video and benchmark report are intentionally allowed in git:

- Video: `benchmarks/talking_selfie_20260630T015424Z/talking_selfie.mp4`
- Report: `benchmarks/talking_selfie_20260630T015424Z/benchmark.md`

Run settings:

- Mode: `streaming`
- Audio mode: custom WAV input
- Frame count: `233`
- Generated frames: `231`
- Output duration: about `9.24s`
- Sample steps: `8`
- Offload model: `True`
- `num_persistent_param_in_dit`: `0`
- Total elapsed: `41m 56s`
- Video generation elapsed: `41m 55s`

Streaming mode was required because the audio was longer than a single 81-frame
window. Running the full audio through `--frame_num 233` in clip mode failed
before sampling, while streaming mode generated the complete clip.

## GPU And VRAM Notes

The RTX 5000 Ada machine used for the successful run has 32GB VRAM. The runner
used conservative memory settings:

```bash
--offload_model True
--num_persistent_param_in_dit 0
--size infinitetalk-480
--sample_steps 8
--mode streaming
```

`--offload_model True` was chosen for reliability, not because we proved that
the machine could not run without offload. It moves model components between CPU
and GPU, which lowers peak VRAM pressure but can make generation much slower.

The observed GPU memory during generation does not necessarily equal the memory
needed to keep the full 14B stack resident on GPU. The full stack includes the
Wan 14B DiT, T5 XXL text encoder, CLIP image encoder, VAE, Wav2Vec audio
encoder, activations, and temporary tensors. With offload enabled, only part of
that stack is on GPU at a time.

## 4090 / 3090 Guidance

An RTX 4090 or RTX 3090 has 24GB VRAM. For this full 14B model, 24GB should be
treated as a memory-constrained but plausible target at 480p when offload is
enabled.

Recommended starting settings for 24GB cards:

```bash
--offload_model True
--num_persistent_param_in_dit 0
--size infinitetalk-480
--sample_steps 8
--mode streaming
```

Expected tradeoffs:

- 24GB cards are likely to need offload for reliable 14B inference.
- A 4090 may still be faster than the RTX 5000 Ada despite less VRAM because of
  stronger raw compute, but CPU/GPU transfer from offloading can limit that gain.
- Running multiple videos in parallel on one 24GB GPU is not recommended with
  the full 14B stack.
- Testing `--offload_model False` is reasonable on 32GB+ GPUs, but it may OOM
  on 24GB cards.

## Git Persistence

The repository ignores heavyweight runtime files by default but allows generated
benchmark videos and benchmark reports to be tracked:

- Trackable: `benchmarks/**/*.mp4`
- Trackable: `benchmarks/**/benchmark.md`
- Ignored: staged benchmark images, generated WAV files, logs, model weights,
  and `save_audio/`

This keeps useful benchmark artifacts persistent without accidentally committing
the 80GB+ model weights or temporary media.
