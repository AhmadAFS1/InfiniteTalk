# InfiniteTalk LightX2V Offload Benchmark - 2026-07-02

This note records the successful InfiniteTalk speed test run on this machine.

## Summary

- Result: successful generation
- Practical takeaway: about 20 minutes to generate a 10 second talking-head video
- Exact measured runtime: 21m 43s, or 1303 seconds
- Output duration: 10.68s
- Output video: `benchmarks/lightx2v_offload_20260702T172130Z/talking_selfie_lightx2v_offload.mp4`
- Run directory: `benchmarks/lightx2v_offload_20260702T172130Z`

## Output Metadata

- Resolution: 896x448
- FPS: 25
- Frames: 267
- File size: 588,375 bytes
- Video duration from ffprobe: 10.68s

## Generation Settings

- Task: `infinitetalk-14B`
- Size bucket: `infinitetalk-480`
- Base model: `weights/Wan2.1-I2V-14B-480P`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
- Wav2Vec checkpoint: `weights/chinese-wav2vec2-base`
- LoRA: `weights/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors`
- LoRA scale: `1.0`
- Sample steps: `4`
- Text guidance scale: `1.0`
- Audio guidance scale: `2.0`
- Mode: `streaming`
- Frame num: `81`
- Max frame num: `269`
- Motion frame: `9`
- Sample shift: `2`
- TeaCache: enabled
- TeaCache threshold: `0.2`
- Offload model: `True`
- DiT persistent params: `0`
- Seed: `42`

## Command Shape

```bash
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True conda run -n infinitetalk python generate_infinitetalk.py \
  --ckpt_dir weights/Wan2.1-I2V-14B-480P \
  --wav2vec_dir weights/chinese-wav2vec2-base \
  --infinitetalk_dir weights/InfiniteTalk/single/infinitetalk.safetensors \
  --lora_dir weights/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors \
  --lora_scale 1.0 \
  --input_json examples/single_example_image.json \
  --size infinitetalk-480 \
  --sample_text_guide_scale 1.0 \
  --sample_audio_guide_scale 2.0 \
  --sample_steps 4 \
  --mode streaming \
  --motion_frame 9 \
  --sample_shift 2 \
  --frame_num 81 \
  --max_frame_num 269 \
  --offload_model True \
  --num_persistent_param_in_dit 0 \
  --use_teacache \
  --teacache_thresh 0.2 \
  --save_file benchmarks/lightx2v_offload_20260702T172130Z/talking_selfie_lightx2v_offload
```

## Notes

An earlier attempt with the same 4-step LightX2V settings but `--offload_model False` failed with CUDA out of memory. The no-offload path nearly fit, using about 47.32 GiB out of 47.37 GiB usable VRAM before failing on an additional 50 MiB allocation.

The successful run used CPU offload. Sampled VRAM during the successful run was mostly around 9-13.5 GB, but no continuous VRAM logger was running.
