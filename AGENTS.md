# Repository Guidelines

## Project Structure & Modules
- Source: `lib/` with the app entry in `lib/main.dart`.
- Platforms: `android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`.
- Tests: `test/` (e.g., `test/widget_test.dart`).
- Docs & assets: `docs/` (screenshots), `release-assets/` (local APKs), build outputs in `build/app/outputs/flutter-apk/`.
- Config: `pubspec.yaml`, `analysis_options.yaml`, CI in `.github/workflows/`.

## Build, Test, and Development
- `flutter pub get`: install dependencies.
- `flutter analyze`: run static analysis/lints.
- `flutter test`: run unit/widget tests (example: `flutter test --coverage`).
- `flutter run -d <device_id>`: run locally (Android emulator/device supported).
- `flutter build apk --release --target-platform=android-arm64`: build release APK (artifact at `build/app/outputs/flutter-apk/app-release.apk`).
- Optional: `flutter pub upgrade --major-versions` to update dependencies.

## Coding Style & Naming Conventions
- Lints: `flutter_lints` via `analysis_options.yaml` (keep warnings at zero).
- Indentation: 2 spaces; avoid tabs and trailing whitespace.
- Files: `snake_case.dart`; classes: `UpperCamelCase`; methods/vars: `lowerCamelCase`.
- Prefer `const` where possible; avoid `print` (use logs/snackbars); document non‑obvious code.

## Testing Guidelines
- Framework: `flutter_test`.
- Location: tests live under `test/` and end with `*_test.dart`.
- Widget tests should be fast and isolated; avoid real platform channels.
- Run locally with `flutter test`; keep essential UI flows covered.

## Commit & Pull Request Guidelines
- Commits: conventional style (e.g., `feat:`, `fix:`, `chore:`) as seen in history.
- Scope small, messages descriptive; add rationale in the body when useful.
- PRs: clear description, linked issues, screenshots/GIFs for UI changes, and notes on platform impact (e.g., Android API 36). Update `README.md`/docs when behavior changes.
- CI/Release: tags `v*` trigger release workflow (`.github/workflows/release.yml`); local APKs in `release-assets/` can be uploaded via `upload-local-apk.yml`.

## Security & Platform Notes
- Executing device binaries may require `su`; do not hardcode credentials or sensitive paths.
- Ensure binaries match device arch (arm64) and are executable; surface permission errors in UI instead of crashing.

