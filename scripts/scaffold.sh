#!/usr/bin/env bash
set -euo pipefail

TARGET=""
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 --target /abs/path/to/ops/appstore-kit [--force]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

mkdir -p "$TARGET"/scripts "$TARGET"/config "$TARGET"/artifacts/screenshots/raw

copy_file() {
  local src="$1"
  local dst="$2"
  if [[ -f "$dst" && "$FORCE" != "1" ]]; then
    echo "SKIP (exists): $dst"
    return
  fi
  cp "$src" "$dst"
  echo "WROTE: $dst"
}

copy_file "$ROOT_DIR/templates/.env.example" "$TARGET/.env.example"
copy_file "$ROOT_DIR/templates/screenshots.plan.json" "$TARGET/config/screenshots.plan.json"
copy_file "$ROOT_DIR/scripts/run_screenshots.sh" "$TARGET/scripts/run_screenshots.sh"
copy_file "$ROOT_DIR/scripts/upload_screenshots_asc.sh" "$TARGET/scripts/upload_screenshots_asc.sh"

chmod +x "$TARGET/scripts/run_screenshots.sh" "$TARGET/scripts/upload_screenshots_asc.sh"

cat > "$TARGET/README.md" <<'TXT'
# App Store Kit (scaffolded)

1. `cp .env.example .env` and fill values.
2. Build your iOS simulator app bundle.
3. Run screenshot capture:

```bash
bash scripts/run_screenshots.sh
```

4. Optional ASC upload:

```bash
bash scripts/upload_screenshots_asc.sh
```
TXT

echo "Done. Target: $TARGET"
