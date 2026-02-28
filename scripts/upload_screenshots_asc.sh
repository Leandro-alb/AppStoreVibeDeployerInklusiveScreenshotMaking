#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$KIT_ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$KIT_ROOT/.env"
  set +a
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

asc_run() {
  if [[ -n "${ASC_PROFILE_NAME:-}" ]]; then
    asc --profile "$ASC_PROFILE_NAME" "$@"
  else
    asc "$@"
  fi
}

need_cmd asc

if [[ -z "${ASC_VERSION_LOCALIZATION_ID:-}" ]]; then
  echo "ERROR: ASC_VERSION_LOCALIZATION_ID is required for screenshot upload." >&2
  exit 1
fi

DEVICE_TYPE=""
SCREENSHOT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device-type)
      DEVICE_TYPE="${2:-}"
      shift 2
      ;;
    --path)
      SCREENSHOT_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

upload_one() {
  local device_type="$1"
  local path="$2"

  if [[ ! -d "$path" ]]; then
    echo "WARN: missing screenshot path, skip: $path" >&2
    return
  fi

  echo "INFO: Uploading $device_type from $path"
  asc_run screenshots upload \
    --version-localization "$ASC_VERSION_LOCALIZATION_ID" \
    --device-type "$device_type" \
    --path "$path" \
    --output table
}

if [[ -n "$DEVICE_TYPE" || -n "$SCREENSHOT_PATH" ]]; then
  if [[ -z "$DEVICE_TYPE" || -z "$SCREENSHOT_PATH" ]]; then
    echo "ERROR: --device-type and --path must be provided together." >&2
    exit 1
  fi
  upload_one "$DEVICE_TYPE" "$SCREENSHOT_PATH"
  exit 0
fi

ROOT_DIR="${SCREENSHOT_OUTPUT_DIR:-artifacts/screenshots/raw}"
if [[ "$ROOT_DIR" != /* ]]; then
  ROOT_DIR="$KIT_ROOT/$ROOT_DIR"
fi

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "ERROR: screenshot root not found: $ROOT_DIR" >&2
  exit 1
fi

for dir in "$ROOT_DIR"/*; do
  [[ -d "$dir" ]] || continue
  device_type="$(basename "$dir")"
  upload_one "$device_type" "$dir"
done
