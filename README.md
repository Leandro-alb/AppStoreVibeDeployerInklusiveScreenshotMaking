# appstore-ops-kit

Generic toolkit to automate iOS App Store screenshot capture and optional upload via `asc`.

This is repo-agnostic. It can be scaffolded into any project.

## What it provides

- Deterministic multi-device screenshot pipeline via `xcrun simctl`
- Scene-based app relaunch for unique screens per shot
- Permission pre-grants (camera/microphone/photos/location)
- Optional upload to App Store Connect via `asc`

## Requirements

- macOS with full Xcode + installed iOS simulator runtime(s)
- `jq`
- `asc` (only for upload)

## Quick start

1. Scaffold into your project:

```bash
bash tools/appstore-ops-kit/scripts/scaffold.sh --target /path/to/project/ops/appstore-kit
```

2. Fill `.env` in target folder (copy from `.env.example`).

3. Ensure your app supports scene switching by env vars (defaults):
- `WALKINATS_SCREENSHOT_MODE=1`
- `WALKINATS_SCREENSHOT_SCENE=<scene-id>`

4. Run capture (+ optional upload):

```bash
bash /path/to/project/ops/appstore-kit/scripts/run_screenshots.sh
```

## Config contract

- `config/screenshots.plan.json`
  - `devices[]`: `label`, `ascDeviceType`, `simulatorCandidates[]`
  - `screens[]`: `id`, `scene`, optional `deepLink`, optional `waitSeconds`

- `.env`
  - `APP_BUNDLE_ID`
  - `APP_BUNDLE_PATH` (simulator `.app` path)
  - `ASC_UPLOAD_SCREENSHOTS=1` to upload
  - `ASC_PROFILE_NAME` and `ASC_VERSION_LOCALIZATION_ID` for upload

## Notes

- If 5.5" device is missing, install a compatible runtime/device and re-run.
- If ASC set is full, delete old screenshots in ASC UI and re-run upload.
