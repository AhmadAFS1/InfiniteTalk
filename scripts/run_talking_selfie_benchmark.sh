#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_PATH="${1:-/workspace/input_selfie.png}"
shift || true
TEXT="Hi! I am here on camera, talking to you from this selfie. Thanks for watching."
AUDIO_SOURCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audio)
      AUDIO_SOURCE="$2"
      shift 2
      ;;
    --text)
      TEXT="$2"
      shift 2
      ;;
    *)
      if [[ -z "$AUDIO_SOURCE" && -f "$1" && "$1" =~ \.(wav|mp3|m4a|aac|flac|ogg)$ ]]; then
        AUDIO_SOURCE="$1"
      else
        TEXT="$1"
      fi
      shift
      ;;
  esac
done

REPO_DIR="${INFINITETALK_REPO_DIR:-/workspace/InfiniteTalk}"
ENV_NAME="${INFINITETALK_ENV_NAME:-infinitetalk}"
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')"
RUN_DIR="$REPO_DIR/benchmarks/talking_selfie_$RUN_ID"
REPORT_PATH="$RUN_DIR/benchmark.md"
OUTPUT_BASE="$RUN_DIR/talking_selfie"
AUDIO_PATH="$RUN_DIR/speech.wav"
INPUT_JSON="$RUN_DIR/input.json"
LOG_PATH="$RUN_DIR/generation.log"
FRAME_NUM_PATH="$RUN_DIR/frame_num.txt"
AUDIO_MODE="kokoro_tts"
GEN_FRAME_NUM="81"
GEN_MODE="clip"
MAX_FRAME_NUM="81"

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Image not found: $IMAGE_PATH" >&2
  echo "Place the selfie at /workspace/input_selfie.png or pass an image path as the first argument." >&2
  exit 2
fi

mkdir -p "$RUN_DIR"
IMAGE_EXT="${IMAGE_PATH##*.}"
cp "$IMAGE_PATH" "$RUN_DIR/input_image.$IMAGE_EXT"
INPUT_IMAGE="$RUN_DIR/input_image.$IMAGE_EXT"

tts_start="$(date +%s)"
if [[ -n "$AUDIO_SOURCE" ]]; then
  if [[ ! -f "$AUDIO_SOURCE" ]]; then
    echo "Audio not found: $AUDIO_SOURCE" >&2
    exit 4
  fi
  AUDIO_MODE="custom_audio"
  conda run -n "$ENV_NAME" ffmpeg -y -i "$AUDIO_SOURCE" -ac 1 -ar 24000 "$AUDIO_PATH" >/dev/null 2>&1
else
  HF_HOME="$RUN_DIR/hf-cache" conda run -n "$ENV_NAME" python -c '
import sys
import torch
import soundfile as sf
from kokoro import KPipeline

text, audio_path = sys.argv[1], sys.argv[2]
pipeline = KPipeline(lang_code="a")
chunks = []
for _, _, audio in pipeline(text, voice="af_heart", speed=1.0, split_pattern=r"\n+"):
    chunks.append(audio.cpu())
if not chunks:
    raise SystemExit("Kokoro produced no audio")
speech = torch.cat(chunks, dim=0).numpy()
sf.write(audio_path, speech, 24000)
' "$TEXT" "$AUDIO_PATH"
fi
tts_end="$(date +%s)"

if [[ ! -s "$AUDIO_PATH" ]]; then
  echo "TTS did not create audio: $AUDIO_PATH" >&2
  exit 3
fi

FRAME_NUM="$(conda run -n "$ENV_NAME" python -c '
import math
import sys
import soundfile as sf

audio_path = sys.argv[1]
info = sf.info(audio_path)
duration = info.frames / info.samplerate
target = math.ceil(duration * 25)
# InfiniteTalk requires frame_num to be 4n + 1.
frame_num = target if (target - 1) % 4 == 0 else target + (4 - ((target - 1) % 4))
print(frame_num)
' "$AUDIO_PATH")"
printf '%s\n' "$FRAME_NUM" > "$FRAME_NUM_PATH"
MAX_FRAME_NUM="$FRAME_NUM"
if (( FRAME_NUM > GEN_FRAME_NUM )); then
  GEN_MODE="streaming"
else
  GEN_FRAME_NUM="$FRAME_NUM"
  MAX_FRAME_NUM="$FRAME_NUM"
fi

python - "$INPUT_JSON" "$INPUT_IMAGE" "$AUDIO_PATH" <<'PY'
import json
import sys

json_path, image_path, audio_path = sys.argv[1:4]
payload = {
    "prompt": (
        "A friendly young woman records a natural talking selfie video indoors. "
        "She looks into the camera, smiles gently, says hi, and speaks casually "
        "to the viewer. The shot remains close-up and realistic."
    ),
    "cond_video": image_path,
    "cond_audio": {"person1": audio_path},
}
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
PY

generate_start="$(date +%s)"
set +e
conda run -n "$ENV_NAME" python generate_infinitetalk.py \
  --ckpt_dir weights/Wan2.1-I2V-14B-480P \
  --wav2vec_dir weights/chinese-wav2vec2-base \
  --infinitetalk_dir weights/InfiniteTalk/single/infinitetalk.safetensors \
  --input_json "$INPUT_JSON" \
  --size infinitetalk-480 \
  --frame_num "$GEN_FRAME_NUM" \
  --max_frame_num "$MAX_FRAME_NUM" \
  --mode "$GEN_MODE" \
  --sample_steps 8 \
  --num_persistent_param_in_dit 0 \
  --offload_model True \
  --save_file "$OUTPUT_BASE" \
  >"$LOG_PATH" 2>&1
status="$?"
set -e
generate_end="$(date +%s)"

total_start="$tts_start"
total_end="$generate_end"

python - "$REPORT_PATH" "$RUN_ID" "$IMAGE_PATH" "$INPUT_IMAGE" "$AUDIO_PATH" "$INPUT_JSON" "$OUTPUT_BASE.mp4" "$LOG_PATH" "$TEXT" "$status" "$tts_start" "$tts_end" "$generate_start" "$generate_end" "$total_start" "$total_end" "$FRAME_NUM" "$AUDIO_MODE" "$AUDIO_SOURCE" "$GEN_FRAME_NUM" "$MAX_FRAME_NUM" "$GEN_MODE" <<'PY'
import os
import sys
from datetime import datetime, timezone

(
    report_path, run_id, source_image, staged_image, audio_path, input_json,
    output_video, log_path, text, status, tts_start, tts_end, gen_start,
    gen_end, total_start, total_end, frame_num, audio_mode, audio_source,
    gen_frame_num, max_frame_num, gen_mode
) = sys.argv[1:]

def fmt(seconds: int) -> str:
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    if hours:
        return f"{hours}h {minutes}m {sec}s"
    if minutes:
        return f"{minutes}m {sec}s"
    return f"{sec}s"

def iso(epoch: str) -> str:
    return datetime.fromtimestamp(int(epoch), tz=timezone.utc).isoformat()

tts_seconds = int(tts_end) - int(tts_start)
gen_seconds = int(gen_end) - int(gen_start)
total_seconds = int(total_end) - int(total_start)
video_exists = os.path.exists(output_video)
video_size = os.path.getsize(output_video) if video_exists else 0

content = f"""# InfiniteTalk Talking Selfie Benchmark

- Run ID: `{run_id}`
- Status: `{status}`
- Started: `{iso(total_start)}`
- Finished: `{iso(total_end)}`
- Total elapsed: `{fmt(total_seconds)}` ({total_seconds} seconds)
- Audio prep elapsed: `{fmt(tts_seconds)}` ({tts_seconds} seconds)
- Video generation elapsed: `{fmt(gen_seconds)}` ({gen_seconds} seconds)
- Frame count: `{frame_num}`
- Expected video duration at 25 fps: `{int(frame_num) / 25:.2f}s`
- Generation mode: `{gen_mode}`
- Generation window frame num: `{gen_frame_num}`
- Max frame num: `{max_frame_num}`

## Inputs

- Source image: `{source_image}`
- Staged image: `{staged_image}`
- Speech audio: `{audio_path}`
- Audio mode: `{audio_mode}`
- Source audio: `{audio_source or "generated by Kokoro TTS"}`
- Input JSON: `{input_json}`
- Spoken text: `{text}`

## Output

- Video: `{output_video}`
- Video exists: `{video_exists}`
- Video size bytes: `{video_size}`
- Log: `{log_path}`

## Generation Settings

- Command: `conda run -n infinitetalk python generate_infinitetalk.py`
- Size: `infinitetalk-480`
- Frame num: `{gen_frame_num}`
- Max frame num: `{max_frame_num}`
- Mode: `{gen_mode}`
- Sample steps: `8`
- Offload model: `True`
- num_persistent_param_in_dit: `0`
- Wan checkpoint: `weights/Wan2.1-I2V-14B-480P`
- Wav2Vec checkpoint: `weights/chinese-wav2vec2-base`
- InfiniteTalk checkpoint: `weights/InfiniteTalk/single/infinitetalk.safetensors`
"""

with open(report_path, "w", encoding="utf-8") as f:
    f.write(content)
PY

echo "Benchmark report: $REPORT_PATH"
echo "Generation log: $LOG_PATH"
echo "Output video: $OUTPUT_BASE.mp4"
exit "$status"
