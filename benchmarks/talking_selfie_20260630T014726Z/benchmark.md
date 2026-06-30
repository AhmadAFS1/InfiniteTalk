# InfiniteTalk Talking Selfie Benchmark

- Run ID: `20260630T014726Z`
- Status: `1`
- Started: `2026-06-30T01:47:26+00:00`
- Finished: `2026-06-30T01:51:28+00:00`
- Total elapsed: `4m 2s` (242 seconds)
- Audio prep elapsed: `0s` (0 seconds)
- Video generation elapsed: `4m 1s` (241 seconds)
- Frame count: `233`
- Expected video duration at 25 fps: `9.32s`

## Inputs

- Source image: `/workspace/InfiniteTalk/assets/2c5b099b-a028-4948-9ae2-f55e9d3a284b copy.png`
- Staged image: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T014726Z/input_image.png`
- Speech audio: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T014726Z/speech.wav`
- Audio mode: `custom_audio`
- Source audio: `/workspace/InfiniteTalk/assets/lumatalk_welcome_female_22_american_medium_step32.wav`
- Input JSON: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T014726Z/input.json`
- Spoken text: `Hi! I am here on camera, talking to you from this selfie. Thanks for watching.`

## Output

- Video: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T014726Z/talking_selfie.mp4`
- Video exists: `False`
- Video size bytes: `0`
- Log: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T014726Z/generation.log`

## Generation Settings

- Command: `conda run -n infinitetalk python generate_infinitetalk.py`
- Size: `infinitetalk-480`
- Frame num: `233`
- Sample steps: `8`
- Offload model: `True`
- num_persistent_param_in_dit: `0`
- Wan checkpoint: `weights/Wan2.1-I2V-14B-480P`
- Wav2Vec checkpoint: `weights/chinese-wav2vec2-base`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
