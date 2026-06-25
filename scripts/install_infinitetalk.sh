#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/AhmadAFS1/InfiniteTalk.git}"
REPO_DIR="${REPO_DIR:-$PWD}"
ENV_NAME="${ENV_NAME:-infinitetalk}"
PYTHON_VERSION="${PYTHON_VERSION:-3.10}"
DOWNLOAD_MODELS="${DOWNLOAD_MODELS:-1}"
DOWNLOAD_MULTI="${DOWNLOAD_MULTI:-0}"
VALIDATE_ONLY="${VALIDATE_ONLY:-0}"
HF_HOME="${HF_HOME:-}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
MAX_JOBS="${MAX_JOBS:-$(nproc)}"
MINIFORGE_DIR="${MINIFORGE_DIR:-$HOME/miniforge3}"

usage() {
  cat <<USAGE
Usage: bash scripts/install_infinitetalk.sh [options]

Options:
  --repo-dir PATH       Install/update InfiniteTalk at PATH. Default: current directory.
  --env-name NAME       Conda env name. Default: infinitetalk.
  --skip-models         Install code/dependencies only; do not download weights.
  --with-multi          Also download multi-person InfiniteTalk checkpoint.
  --validate-only       Run validation checks against an existing install.
  --repo-url URL        Git repository URL. Default: official InfiniteTalk repo.
  -h, --help            Show this help.

Environment overrides:
  REPO_DIR, ENV_NAME, REPO_URL, HF_HOME, CUDA_HOME, MAX_JOBS, MINIFORGE_DIR

Disk guidance:
  Single-person setup needs roughly 105GB free during install.
  Multi-person setup needs roughly 120GB+ free.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-dir)
      REPO_DIR="$2"
      HF_HOME="${HF_HOME:-$2/weights/.hf-cache}"
      shift 2
      ;;
    --env-name)
      ENV_NAME="$2"
      shift 2
      ;;
    --skip-models)
      DOWNLOAD_MODELS=0
      shift
      ;;
    --with-multi)
      DOWNLOAD_MULTI=1
      shift
      ;;
    --validate-only)
      VALIDATE_ONLY=1
      DOWNLOAD_MODELS=0
      shift
      ;;
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

install_system_packages() {
  missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [[ "${#missing[@]}" -eq 0 ]] && return 0

  if command -v apt-get >/dev/null 2>&1; then
    log "Installing system packages: ${missing[*]}"
    if [[ "$(id -u)" -eq 0 ]]; then
      apt-get update
      DEBIAN_FRONTEND=noninteractive apt-get install -y git curl ca-certificates bzip2
    elif command -v sudo >/dev/null 2>&1; then
      sudo apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl ca-certificates bzip2
    else
      echo "Missing commands (${missing[*]}) and sudo is unavailable." >&2
      exit 1
    fi
  elif command -v yum >/dev/null 2>&1; then
    log "Installing system packages: ${missing[*]}"
    if [[ "$(id -u)" -eq 0 ]]; then
      yum install -y git curl ca-certificates bzip2
    elif command -v sudo >/dev/null 2>&1; then
      sudo yum install -y git curl ca-certificates bzip2
    else
      echo "Missing commands (${missing[*]}) and sudo is unavailable." >&2
      exit 1
    fi
  else
    echo "Missing commands (${missing[*]}). Install git, curl, ca-certificates, and bzip2 first." >&2
    exit 1
  fi
}

ensure_conda() {
  if command -v conda >/dev/null 2>&1; then
    return 0
  fi

  log "Conda not found; installing Miniforge at $MINIFORGE_DIR"
  mkdir -p "$(dirname "$MINIFORGE_DIR")"
  installer="$(mktemp /tmp/miniforge-XXXXXX.sh)"
  curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" -o "$installer"
  bash "$installer" -b -p "$MINIFORGE_DIR"
  rm -f "$installer"
  # shellcheck disable=SC1091
  source "$MINIFORGE_DIR/etc/profile.d/conda.sh"
}

free_gb_for() {
  df -BG "$1" | awk 'NR==2 {gsub("G","",$4); print $4}'
}

conda_run() {
  conda run -n "$ENV_NAME" "$@"
}

download_hf() {
  local repo="$1"
  local local_dir="$2"
  shift 2
  mkdir -p "$local_dir"
  HF_HUB_ENABLE_HF_TRANSFER=1 HF_HOME="$HF_HOME" conda_run huggingface-cli download "$repo" "$@" --local-dir "$local_dir"
}

validate_install() {
  log "Validating install"
  conda_run python -c '
import importlib
import scipy
import torch
from importlib.metadata import version

modules = [
    "torch", "torchvision", "torchaudio", "xformers", "flash_attn", "misaki",
    "cv2", "diffusers", "transformers", "tokenizers", "accelerate", "imageio",
    "easydict", "ftfy", "dashscope", "imageio_ffmpeg", "skimage", "loguru",
    "gradio", "numpy", "xfuser", "pyloudnorm", "optimum.quanto", "scenedetect",
    "moviepy", "decord", "librosa", "soundfile", "einops", "huggingface_hub",
]
failed = []
for module in modules:
    try:
        importlib.import_module(module)
    except Exception as exc:
        failed.append(f"{module}: {type(exc).__name__}: {exc}")
print("torch", torch.__version__, "cuda", torch.version.cuda, "cuda_available", torch.cuda.is_available())
print("diffusers", version("diffusers"))
print("transformers", version("transformers"))
print("xfuser", version("xfuser"))
print("scipy", scipy.__version__)
if failed:
    raise SystemExit("\n".join(failed))
'

  conda_run python generate_infinitetalk.py --help >/dev/null
  conda_run python app.py --help >/dev/null

  if [[ -d weights ]]; then
    log "Validating required single-person model files"
    required_files=(
      weights/Wan2.1-I2V-14B-480P/config.json
      weights/Wan2.1-I2V-14B-480P/Wan2.1_VAE.pth
      weights/Wan2.1-I2V-14B-480P/diffusion_pytorch_model.safetensors.index.json
      weights/Wan2.1-I2V-14B-480P/models_t5_umt5-xxl-enc-bf16.pth
      weights/Wan2.1-I2V-14B-480P/models_clip_open-clip-xlm-roberta-large-vit-huge-14.pth
      weights/chinese-wav2vec2-base/config.json
      weights/chinese-wav2vec2-base/preprocessor_config.json
      weights/chinese-wav2vec2-base/model.safetensors
      weights/InfiniteTalk/single/infinitetalk.safetensors
    )
    for file in "${required_files[@]}"; do
      [[ -s "$file" ]] || { echo "Missing required file: $file" >&2; exit 1; }
    done
    shard_count="$(find weights/Wan2.1-I2V-14B-480P -maxdepth 1 -name 'diffusion_pytorch_model-*.safetensors' | wc -l)"
    [[ "$shard_count" -eq 7 ]] || { echo "Expected 7 Wan diffusion shards, found $shard_count" >&2; exit 1; }
  fi
}

clean_download_caches() {
  rm -rf "$REPO_DIR/weights/.hf-cache"
  find "$REPO_DIR/weights" -type d -path '*/.cache/huggingface' -prune -exec rm -rf {} + 2>/dev/null || true
  find "$REPO_DIR/weights" -type f -name '*.incomplete' -delete 2>/dev/null || true
}

install_system_packages git curl bzip2
ensure_conda
HF_HOME="${HF_HOME:-$REPO_DIR/weights/.hf-cache}"

if [[ "$VALIDATE_ONLY" == "1" ]]; then
  cd "$REPO_DIR"
  validate_install
  log "Validation complete"
  exit 0
fi

if [[ -d "$REPO_DIR/.git" ]]; then
  log "Updating existing repo at $REPO_DIR"
  git -C "$REPO_DIR" fetch --depth 1 origin main || true
else
  if [[ -n "$(find "$REPO_DIR" -mindepth 1 -maxdepth 1 ! -name weights 2>/dev/null | head -1)" ]]; then
    log "Using existing non-git directory at $REPO_DIR"
  else
    log "Cloning InfiniteTalk into $REPO_DIR"
    mkdir -p "$(dirname "$REPO_DIR")"
    tmpdir="$(mktemp -d)"
    git clone --depth 1 "$REPO_URL" "$tmpdir"
    mkdir -p "$REPO_DIR"
    cp -a "$tmpdir"/. "$REPO_DIR"/
    rm -rf "$REPO_DIR/.git"
    rm -rf "$tmpdir"
  fi
fi

cd "$REPO_DIR"

log "Checking CUDA and disk"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "Warning: nvidia-smi not found. InfiniteTalk requires an NVIDIA GPU for practical inference." >&2
fi
if [[ "$DOWNLOAD_MODELS" == "1" ]]; then
  required_gb=105
  [[ "$DOWNLOAD_MULTI" == "1" ]] && required_gb=120
  available_gb="$(free_gb_for "$REPO_DIR")"
  if (( available_gb < required_gb )); then
    echo "Warning: only ${available_gb}GB free. Recommended: ${required_gb}GB+." >&2
  fi
fi

log "Creating conda environment: $ENV_NAME"
if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  conda create -y -n "$ENV_NAME" "python=$PYTHON_VERSION"
fi

export CUDA_HOME PATH MAX_JOBS
PATH="$CUDA_HOME/bin:$PATH"

log "Installing PyTorch, xformers, and build prerequisites"
conda_run python -m pip install --upgrade pip
conda_run python -m pip install torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121
conda_run python -m pip install -U xformers==0.0.28 --index-url https://download.pytorch.org/whl/cu121
conda_run python -m pip install misaki[en] ninja psutil packaging wheel

log "Installing InfiniteTalk Python dependencies"
conda_run python -m pip install -r requirements.txt

log "Applying compatibility pins validated with Torch 2.4.1/CUDA 12.1"
conda_run python -m pip install --force-reinstall \
  'numpy>=1.23.5,<2' \
  'scipy==1.11.4' \
  'transformers==4.49.0' \
  'huggingface_hub>=0.26.0,<1.0' \
  'tokenizers>=0.20.3,<0.22' \
  'diffusers==0.33.0' \
  'gradio==5.50.0'
conda_run python -m pip install --force-reinstall --no-deps 'xfuser==0.4.1'
conda_run python -m pip install soundfile einops hf_transfer

log "Installing flash-attn"
conda_run python -m pip install flash_attn==2.7.4.post1 --no-build-isolation

log "Installing ffmpeg and librosa"
conda install -y -n "$ENV_NAME" -c conda-forge ffmpeg librosa
conda_run python -m pip install --force-reinstall 'numpy>=1.23.5,<2' 'scipy==1.11.4'
find "$(conda run -n "$ENV_NAME" python -c 'import site; print(site.getsitepackages()[0])')" \
  -maxdepth 1 -type d -name 'scipy-*.dist-info' ! -name 'scipy-1.11.4.dist-info' -exec rm -rf {} + 2>/dev/null || true

if [[ "$DOWNLOAD_MODELS" == "1" ]]; then
  log "Downloading model weights"
  mkdir -p weights
  download_hf Wan-AI/Wan2.1-I2V-14B-480P weights/Wan2.1-I2V-14B-480P
  clean_download_caches
  download_hf TencentGameMate/chinese-wav2vec2-base weights/chinese-wav2vec2-base
  download_hf TencentGameMate/chinese-wav2vec2-base weights/chinese-wav2vec2-base model.safetensors --revision refs/pr/1
  clean_download_caches
  download_hf MeiGen-AI/InfiniteTalk weights/InfiniteTalk single/infinitetalk.safetensors
  if [[ "$DOWNLOAD_MULTI" == "1" ]]; then
    download_hf MeiGen-AI/InfiniteTalk weights/InfiniteTalk multi/infinitetalk.safetensors
  fi
  clean_download_caches
fi

validate_install

log "Install complete"
cat <<NEXT

Activate:
  conda activate $ENV_NAME

Run Gradio:
  cd "$REPO_DIR"
  python app.py --offload_model True --num_persistent_param_in_dit 0

Run CLI single-image example:
  cd "$REPO_DIR"
  python generate_infinitetalk.py \\
    --ckpt_dir weights/Wan2.1-I2V-14B-480P \\
    --wav2vec_dir weights/chinese-wav2vec2-base \\
    --infinitetalk_dir weights/InfiniteTalk/single/infinitetalk.safetensors \\
    --input_json examples/single_example_image.json \\
    --size infinitetalk-480 \\
    --sample_steps 8 \\
    --num_persistent_param_in_dit 0 \\
    --save_file outputs/infinitetalk_single
NEXT
