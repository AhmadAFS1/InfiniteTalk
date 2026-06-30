# InfiniteTalk Talking Selfie Benchmark

- Run ID: `20260629T232827Z`
- Status: `0`
- Started: `2026-06-29T23:28:27+00:00`
- Finished: `2026-06-29T23:42:32+00:00`
- Total elapsed: `14m 5s` (845 seconds)
- TTS prep elapsed: `14s` (14 seconds)
- Video generation elapsed: `13m 51s` (831 seconds)

## Inputs

- Source image: `/workspace/InfiniteTalk/assets/2c5b099b-a028-4948-9ae2-f55e9d3a284b copy.png`
- Staged image: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260629T232827Z/input_image.png`
- Speech audio: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260629T232827Z/speech.wav`
- Input JSON: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260629T232827Z/input.json`
- Spoken text: `Hi! I am filming a quick selfie video. I wanted to say hello, and I hope you are having a great day.`

## Output

- Video: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260629T232827Z/talking_selfie.mp4`
- Video exists: `True`
- Video size bytes: `169405`
- Log: `/workspace/InfiniteTalk/benchmarks/talking_selfie_20260629T232827Z/generation.log`

## Generation Settings

- Command: `conda run -n infinitetalk python generate_infinitetalk.py`
- Size: `infinitetalk-480`
- Sample steps: `8`
- Offload model: `True`
- num_persistent_param_in_dit: `0`
- Wan checkpoint: `weights/Wan2.1-I2V-14B-480P`
- Wav2Vec checkpoint: `weights/chinese-wav2vec2-base`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
