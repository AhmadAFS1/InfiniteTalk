# InfiniteTalk Talking Selfie Benchmark

- Run ID: `20260630T015424Z`
- Status: `0`
- Started: `2026-06-30T01:54:24+00:00`
- Finished: `2026-06-30T02:36:20+00:00`
- Total elapsed: `41m 56s` (2516 seconds)
- Audio prep elapsed: `0s` (0 seconds)
- Video generation elapsed: `41m 55s` (2515 seconds)
- Frame count: `233`
- Expected video duration at 25 fps: `9.32s`
- Generation mode: `streaming`
- Generation window frame num: `81`
- Max frame num: `233`

## Inputs

- Source image: `/workspace/InfiniteTalk/assets/2c5b099b-a028-4948-9ae2-f55e9d3a284b copy.png`
- Staged image: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T015424Z/input_image.png`
- Speech audio: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T015424Z/speech.wav`
- Audio mode: `custom_audio`
- Source audio: `/workspace/InfiniteTalk/assets/lumatalk_welcome_female_22_american_medium_step32.wav`
- Input JSON: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T015424Z/input.json`
- Spoken text: `Hi! I am here on camera, talking to you from this selfie. Thanks for watching.`

## Output

- Video: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T015424Z/talking_selfie.mp4`
- Video exists: `True`
- Video size bytes: `438669`
- Log: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260630T015424Z/generation.log`

## Generation Settings

- Command: `conda run -n infinitetalk python generate_infinitetalk.py`
- Size: `infinitetalk-480`
- Frame num: `81`
- Max frame num: `233`
- Mode: `streaming`
- Sample steps: `8`
- Offload model: `True`
- num_persistent_param_in_dit: `0`
- Wan checkpoint: `weights/Wan2.1-I2V-14B-480P`
- Wav2Vec checkpoint: `weights/chinese-wav2vec2-base`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
