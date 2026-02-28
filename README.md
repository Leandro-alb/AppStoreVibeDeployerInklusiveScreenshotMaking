# AppStoreVibeDeployerInklusiveScreenshotMaking

Reusable toolkit for deterministic iOS App Store screenshot automation and optional App Store Connect upload via `asc`, with simulator setup, permission pre-grants, scene-based captures, and scaffoldable templates for any repo.

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
bash scripts/scaffold.sh --target /path/to/project/ops/appstore-kit
```

2. Fill `.env` in target folder (copy from `.env.example`).
3. Ensure your app supports scene switching through env vars.
4. Run capture (+ optional upload):

```bash
bash scripts/run_screenshots.sh
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
