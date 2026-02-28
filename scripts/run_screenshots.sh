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

log() {
  echo "INFO: $*"
}

warn() {
  echo "WARN: $*" >&2
}

need_cmd jq
need_cmd xcrun

APP_BUNDLE_ID="${APP_BUNDLE_ID:-}"
APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-}"
SCREENSHOT_MODE_ENV_KEY="${SCREENSHOT_MODE_ENV_KEY:-}"
SCREENSHOT_MODE_ENV_VALUE="${SCREENSHOT_MODE_ENV_VALUE:-1}"
SCREENSHOT_SCENE_ENV_KEY="${SCREENSHOT_SCENE_ENV_KEY:-}"
SCREENSHOT_DISABLE_FEATURE_ENV_KEY="${SCREENSHOT_DISABLE_FEATURE_ENV_KEY:-}"
SCREENSHOT_DISABLE_FEATURE_ENV_VALUE="${SCREENSHOT_DISABLE_FEATURE_ENV_VALUE:-1}"
ASC_WAIT_SECONDS_DEFAULT="${ASC_WAIT_SECONDS_DEFAULT:-2}"
DELETE_CREATED_SIMULATORS="${DELETE_CREATED_SIMULATORS:-1}"
SIM_RUNTIME_IDENTIFIER="${SIM_RUNTIME_IDENTIFIER:-}"
ASC_UPLOAD_SCREENSHOTS="${ASC_UPLOAD_SCREENSHOTS:-0}"

if [[ -z "$APP_BUNDLE_ID" ]]; then
  echo "ERROR: APP_BUNDLE_ID is required." >&2
  exit 1
fi

PLAN_PATH="${SCREENSHOT_PLAN_PATH:-config/screenshots.plan.json}"
if [[ "$PLAN_PATH" != /* ]]; then
  PLAN_PATH="$KIT_ROOT/$PLAN_PATH"
fi

OUT_ROOT="${SCREENSHOT_OUTPUT_DIR:-artifacts/screenshots/raw}"
if [[ "$OUT_ROOT" != /* ]]; then
  OUT_ROOT="$KIT_ROOT/$OUT_ROOT"
fi

if [[ ! -f "$PLAN_PATH" ]]; then
  echo "ERROR: screenshot plan not found: $PLAN_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_ROOT"
SUMMARY_FILE="$(cd "$OUT_ROOT/.." && pwd)/summary.md"

if [[ -n "$SIM_RUNTIME_IDENTIFIER" ]]; then
  RUNTIME_ID="$SIM_RUNTIME_IDENTIFIER"
else
  RUNTIME_ID="$(xcrun simctl list runtimes -j | jq -r '
    [.runtimes[] | select(.platform == "iOS" and .isAvailable == true)]
    | sort_by(.version) | last.identifier // empty
  ')"
fi

if [[ -z "$RUNTIME_ID" ]]; then
  echo "ERROR: no iOS simulator runtime available. Install one in Xcode." >&2
  exit 1
fi

AVAILABLE_TYPES="$(xcrun simctl list devicetypes)"
CURRENT_UDID=""

cleanup_sim() {
  if [[ -n "$CURRENT_UDID" ]]; then
    xcrun simctl shutdown "$CURRENT_UDID" >/dev/null 2>&1 || true
    if [[ "$DELETE_CREATED_SIMULATORS" == "1" ]]; then
      xcrun simctl delete "$CURRENT_UDID" >/dev/null 2>&1 || true
    fi
    CURRENT_UDID=""
  fi
}

trap cleanup_sim EXIT INT TERM

grant_permissions() {
  local udid="$1"
  xcrun simctl privacy "$udid" grant microphone "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant camera "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant photos "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant location "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant location-when-in-use "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl privacy "$udid" grant location-always "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
}

launch_scene() {
  local udid="$1"
  local scene="$2"

  xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

  local -a env_args=()
  if [[ -n "$SCREENSHOT_MODE_ENV_KEY" ]]; then
    env_args+=("SIMCTL_CHILD_${SCREENSHOT_MODE_ENV_KEY}=${SCREENSHOT_MODE_ENV_VALUE}")
  fi
  if [[ -n "$SCREENSHOT_SCENE_ENV_KEY" ]]; then
    env_args+=("SIMCTL_CHILD_${SCREENSHOT_SCENE_ENV_KEY}=${scene}")
  fi
  if [[ -n "$SCREENSHOT_DISABLE_FEATURE_ENV_KEY" ]]; then
    env_args+=("SIMCTL_CHILD_${SCREENSHOT_DISABLE_FEATURE_ENV_KEY}=${SCREENSHOT_DISABLE_FEATURE_ENV_VALUE}")
  fi

  if [[ ${#env_args[@]} -gt 0 ]]; then
    env "${env_args[@]}" xcrun simctl launch --terminate-running-process "$udid" "$APP_BUNDLE_ID" >/dev/null
  else
    xcrun simctl launch --terminate-running-process "$udid" "$APP_BUNDLE_ID" >/dev/null
  fi
}

{
  echo "# Screenshot Run Summary"
  echo
  echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Runtime: $RUNTIME_ID"
  echo "Plan: $PLAN_PATH"
  echo
} > "$SUMMARY_FILE"

while IFS= read -r device_json; do
  label="$(printf '%s' "$device_json" | jq -r '.label')"
  asc_device_type="$(printf '%s' "$device_json" | jq -r '.ascDeviceType')"

  chosen_type=""
  udid=""
  while IFS= read -r candidate; do
    if ! printf '%s' "$AVAILABLE_TYPES" | grep -Fq "$candidate"; then
      continue
    fi

    sim_name="asc-kit-${label// /-}-$(date +%s)-$RANDOM"
    if udid="$(xcrun simctl create "$sim_name" "$candidate" "$RUNTIME_ID" 2>/dev/null)"; then
      chosen_type="$candidate"
      break
    fi
  done < <(printf '%s' "$device_json" | jq -r '.simulatorCandidates[]')

  if [[ -z "$chosen_type" || -z "$udid" ]]; then
    warn "Skipping '$label': no compatible simulator candidate for runtime $RUNTIME_ID"
    echo "- $label: skipped (no compatible simulator candidate)" >> "$SUMMARY_FILE"
    continue
  fi

  CURRENT_UDID="$udid"

  log "Booting $label ($chosen_type)"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b

  if [[ -n "$APP_BUNDLE_PATH" ]]; then
    if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
      echo "ERROR: APP_BUNDLE_PATH not found: $APP_BUNDLE_PATH" >&2
      exit 1
    fi
    xcrun simctl install "$udid" "$APP_BUNDLE_PATH"
    grant_permissions "$udid"
  else
    warn "APP_BUNDLE_PATH not set. App must already be installed on simulator."
  fi

  device_dir="$OUT_ROOT/$asc_device_type"
  rm -rf "$device_dir"
  mkdir -p "$device_dir"

  idx=0
  while IFS= read -r screen_json; do
    idx=$((idx + 1))
    screen_id="$(printf '%s' "$screen_json" | jq -r '.id')"
    scene="$(printf '%s' "$screen_json" | jq -r '.scene // empty')"
    deep_link="$(printf '%s' "$screen_json" | jq -r '.deepLink // empty')"
    wait_seconds="$(printf '%s' "$screen_json" | jq -r --arg d "$ASC_WAIT_SECONDS_DEFAULT" '.waitSeconds // ($d|tonumber)')"

    launch_scene "$udid" "$scene"

    if [[ -n "$deep_link" ]]; then
      xcrun simctl openurl "$udid" "$deep_link" || true
    fi

    sleep "$wait_seconds"
    out_file="$device_dir/$(printf '%02d' "$idx")-${screen_id}.png"
    xcrun simctl io "$udid" screenshot "$out_file"
  done < <(jq -c '.screens[]' "$PLAN_PATH")

  echo "- $label: captured to $device_dir" >> "$SUMMARY_FILE"

  if [[ "$ASC_UPLOAD_SCREENSHOTS" == "1" ]]; then
    "$SCRIPT_DIR/upload_screenshots_asc.sh" --device-type "$asc_device_type" --path "$device_dir"
  fi

  cleanup_sim
done < <(jq -c '.devices[]' "$PLAN_PATH")

log "Done. Summary: $SUMMARY_FILE"
cat "$SUMMARY_FILE"
