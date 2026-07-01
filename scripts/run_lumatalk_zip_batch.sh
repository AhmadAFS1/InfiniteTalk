#!/usr/bin/env bash
set -Eeuo pipefail

ZIP_PATH="${1:-/workspace/InfiniteTalk/assets/varied_background_selfie_images.zip}"
REPO_DIR="${INFINITETALK_REPO_DIR:-/workspace/InfiniteTalk}"
ENV_NAME="${INFINITETALK_ENV_NAME:-infinitetalk}"
TEXT="${LUMATALK_TTS_TEXT:-Hello, and welcome to LumaTalk! An AI companion platform where you can interact with AI companions for practicing foreign langauges!}"
RUN_ID="$(date -u '+%Y%m%dT%H%M%SZ')"
RUN_DIR="${RUN_DIR:-$REPO_DIR/outputs/lumatalk_zip_batch_$RUN_ID}"
IMAGE_DIR="$RUN_DIR/images"
AUDIO_PATH="$RUN_DIR/lumatalk_tts.wav"
SUMMARY_PATH="$RUN_DIR/summary.md"
GEN_FRAME_NUM="${GEN_FRAME_NUM:-81}"
SAMPLE_STEPS="${SAMPLE_STEPS:-8}"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Zip not found: $ZIP_PATH" >&2
  exit 2
fi

mkdir -p "$IMAGE_DIR"

python - "$ZIP_PATH" "$IMAGE_DIR" <<'PY'
import os
import re
import sys
import zipfile
from pathlib import Path

zip_path, image_dir = map(Path, sys.argv[1:3])
allowed = {".jpg", ".jpeg", ".png", ".webp"}
with zipfile.ZipFile(zip_path) as zf:
    image_names = [
        name for name in zf.namelist()
        if not name.endswith("/") and Path(name).suffix.lower() in allowed
    ]
    if not image_names:
        raise SystemExit(f"No supported images found in {zip_path}")
    for index, name in enumerate(sorted(image_names), start=1):
        suffix = Path(name).suffix.lower()
        stem = re.sub(r"[^A-Za-z0-9._-]+", "_", Path(name).stem).strip("._-")
        out_path = image_dir / f"{index:02d}_{stem}{suffix}"
        with zf.open(name) as src, open(out_path, "wb") as dst:
            dst.write(src.read())
        print(out_path)
PY

mapfile -t IMAGES < <(find "$IMAGE_DIR" -maxdepth 1 -type f | sort)
if [[ "${#IMAGES[@]}" -eq 0 ]]; then
  echo "No images were extracted from $ZIP_PATH" >&2
  exit 3
fi

tts_start="$(date +%s)"
if [[ ! -s "$AUDIO_PATH" ]]; then
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
  exit 4
fi

FRAME_NUM="$(conda run -n "$ENV_NAME" python -c '
import math
import sys
import soundfile as sf

info = sf.info(sys.argv[1])
target = math.ceil((info.frames / info.samplerate) * 25)
frame_num = target if (target - 1) % 4 == 0 else target + (4 - ((target - 1) % 4))
print(frame_num)
' "$AUDIO_PATH"
)"
MAX_FRAME_NUM="$FRAME_NUM"
MODE="clip"
if (( FRAME_NUM > GEN_FRAME_NUM )); then
  MODE="streaming"
else
  GEN_FRAME_NUM="$FRAME_NUM"
fi

if [[ ! -f "$SUMMARY_PATH" ]]; then
  {
    echo "# LumaTalk InfiniteTalk Batch"
    echo
    echo "- Run ID: \`$RUN_ID\`"
    echo "- Zip: \`$ZIP_PATH\`"
    echo "- Images: \`${#IMAGES[@]}\`"
    echo "- Audio: \`$AUDIO_PATH\`"
    echo "- Text: \`$TEXT\`"
    echo "- Frame count: \`$FRAME_NUM\`"
    echo "- Mode: \`$MODE\`"
    echo "- Sample steps: \`$SAMPLE_STEPS\`"
    echo "- TTS elapsed seconds: \`$((tts_end - tts_start))\`"
    echo
    echo "| Image | Status | Video | Log |"
    echo "| --- | ---: | --- | --- |"
  } > "$SUMMARY_PATH"
fi

for image_path in "${IMAGES[@]}"; do
  name="$(basename "$image_path")"
  stem="${name%.*}"
  item_dir="$RUN_DIR/$stem"
  mkdir -p "$item_dir"
  input_json="$item_dir/input.json"
  output_base="$item_dir/video"
  log_path="$item_dir/generation.log"

  if [[ -s "$output_base.mp4" ]]; then
    if ! grep -Fq "| \`$name\` | \`0\` |" "$SUMMARY_PATH"; then
      echo "| \`$name\` | \`0\` | \`$output_base.mp4\` | \`$log_path\` |" >> "$SUMMARY_PATH"
    fi
    continue
  fi

  python - "$input_json" "$image_path" "$AUDIO_PATH" <<'PY'
import json
import sys

json_path, image_path, audio_path = sys.argv[1:4]
payload = {
    "prompt": (
        "A realistic handheld talking selfie video. The person holds the phone camera "
        "at arm's length, looks into the lens, smiles warmly, and speaks naturally. "
        "The camera has subtle handheld movement with gentle sway and small walking "
        "or shifting motion, so the background moves slightly with natural parallax "
        "instead of staying perfectly still. Keep the face stable, close-up, and "
        "well-framed, with realistic lighting and no dramatic camera shake."
    ),
    "cond_video": image_path,
    "cond_audio": {"person1": audio_path},
}
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
PY

  set +e
  conda run -n "$ENV_NAME" python generate_infinitetalk.py \
    --ckpt_dir weights/Wan2.1-I2V-14B-480P \
    --wav2vec_dir weights/chinese-wav2vec2-base \
    --infinitetalk_dir weights/InfiniteTalk/single/infinitetalk.safetensors \
    --input_json "$input_json" \
    --size infinitetalk-480 \
    --frame_num "$GEN_FRAME_NUM" \
    --max_frame_num "$MAX_FRAME_NUM" \
    --mode "$MODE" \
    --sample_steps "$SAMPLE_STEPS" \
    --num_persistent_param_in_dit 0 \
    --offload_model True \
    --save_file "$output_base" \
    >"$log_path" 2>&1
  status="$?"
  set -e

  echo "| \`$name\` | \`$status\` | \`$output_base.mp4\` | \`$log_path\` |" >> "$SUMMARY_PATH"
done

echo "Batch complete: $SUMMARY_PATH"
