# Releases Guide

## 2025-08-23 — Web UI and Build Fixes (Render)

- Prevent duplicate Safety & Legal modal via guard in `ai_buddy_web/lib/screens/interactive_chat_screen.dart`.
- Removed `dart:io` usage in `ai_buddy_web/lib/services/notification_service.dart`; use `defaultTargetPlatform`/`kIsWeb` for web compatibility.
- Verified `KeyboardAwareBackButton` from `ai_buddy_web/lib/widgets/keyboard_dismissible_scaffold.dart` and wiring across screens.
- Quest tab now uses `WellnessDashboardScreen` via `ai_buddy_web/lib/navigation/home_shell.dart`.
- Web builds disable PWA caching (`--pwa-strategy=none`) and nginx is configured to avoid stale assets.
- Dockerfile updated for reproducible web builds; deployment config aligned with Render.

This project includes one-command Android release scripts and a GitHub Actions workflow for signed AAB builds without committing secrets.

## Local Android releases

- AAB (Play Store):
  - Create `ai_buddy_web/android/key.properties` from the example and fill passwords, or use env vars.
  - Command:
    ```bash
    ./scripts/release_android_aab.sh
    ```
  - Output: `ai_buddy_web/build/app/outputs/bundle/release/app-release.aab`

- APK (testing/sideload):
  ```bash
  ./scripts/release_android_apk.sh
  ```
  Output: `ai_buddy_web/build/app/outputs/flutter-apk/app-release.apk` (or module output path)

### Keystore setup (upload key)

```bash
cd ai_buddy_web/android/app
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storetype JKS
```

Create `ai_buddy_web/android/key.properties` (gitignored):
```properties
storeFile=app/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

Alternatively, use environment variables:
- `STORE_FILE`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
- Or a local (gitignored) `scripts/android_signing.env` created from the provided example.

## Local iOS releases

- Prerequisites (local Mac):
  - Xcode installed and you are signed in with an Apple Developer account in Xcode.
  - Valid signing certificate and provisioning profile accessible to Xcode.
  - Optional: copy `scripts/ios_signing.env.example` to `scripts/ios_signing.env` and fill values.
- Command:
  ```bash
  ./scripts/release_ios_ipa.sh
  ```
- Controls (env in `scripts/ios_signing.env`):
  - `IOS_EXPORT_METHOD` – `app-store` | `ad-hoc` | `development` | `enterprise` (default: `ad-hoc`)
  - `APPLE_TEAM_ID` – your Apple Team ID, used for automatic signing
  - `IOS_BUNDLE_ID` + `IOS_PROVISIONING_PROFILE_SPECIFIER` – optional to pin a specific provisioning profile
- Output: typically under `ai_buddy_web/build/ios/ipa/*.ipa`

### iOS local overrides (bundle id & team)

You can override signing identifiers locally without touching the Xcode project by creating a gitignored `ios/Config/local-overrides.xcconfig` from the provided example:

```
// ios/Config/local-overrides.xcconfig
APP_BUNDLE_ID = com.yourcompany.mhb
DEVELOPMENT_TEAM = YOURTEAMID
// Optional
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
```

Notes:
- `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` include `Config/AppIdentifiers.xcconfig` and then `Config/local-overrides.xcconfig` (if present).
- `PRODUCT_BUNDLE_IDENTIFIER` is parameterized as `$(APP_BUNDLE_ID)` in `ios/Runner.xcodeproj/project.pbxproj` for all configurations.
- `DEVELOPMENT_TEAM` in the pbxproj is quoted as `"$(DEVELOPMENT_TEAM)"` to avoid parsing errors.
- Minimum iOS target is set to 13.0 across configurations.

## CI: GitHub Actions Android release

- Manual workflow: `.github/workflows/android_release.yml` (run with "Run workflow").
- Inputs:
  - `app_id` (optional) – override applicationId via `ORG_GRADLE_PROJECT_APP_ID`.
  - `package_name` (optional) – Play package (defaults to `app.mhb.preview`).
  - `track` (optional) – Play track (`internal`, `alpha`, `beta`, `production`).
  - `upload` – set to `true` to auto-upload AAB to Google Play after build.
- Required secrets:
  - `ANDROID_KEYSTORE_BASE64` – base64 of your `upload-keystore.jks`.
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`
  - For Play upload: `PLAY_SERVICE_ACCOUNT_JSON` – the full JSON of a Google Play service account with "Release to tracks" permissions.

### Create secrets

Use the helper script to base64-encode the keystore:
```bash
./scripts/encode_keystore.sh ai_buddy_web/android/app/upload-keystore.jks
# Copy output into GitHub secret ANDROID_KEYSTORE_BASE64
```
Then add the remaining three string secrets as-is.

The workflow restores the keystore, builds the AAB via Gradle using env overrides, and uploads the artifact.
If `upload` is `true`, it will upload the built AAB to Google Play on the selected `track` using `PLAY_SERVICE_ACCOUNT_JSON`.

## Notes

- Signing fallback: If no keystore is present, builds use debug signing (installable, not Play-ready).
- No secrets in repo: `ai_buddy_web/android/key.properties` and `scripts/android_signing.env` are gitignored.
- Local vs Flutter toolchain: We use Gradle for reliability even when Flutter's Android cmdline-tools/licenses are not configured.

---

# Unified Mobile Release (CI Orchestrator)

Use `.github/workflows/mobile_release.yml` to drive Android and iOS together with unified inputs.

## Orchestrator Inputs

- `app_id`, `package_name`, `android_track`
- `ios_bundle_id`, `ios_scheme`, `ios_export_method`
- `build_number` – defaults to GitHub run number when empty
- `release_notes` – text changelog applied across platforms
- `preflight` – run `dart format`, `flutter analyze`, `flutter test`
- `upload_android`, `upload_ios` – toggle store uploads
- `environment` – GitHub Environment for upload jobs (e.g., `beta`, `production`)
- `sentry_upload`, `sentry_org`, `sentry_project_android`, `sentry_project_ios`, `sentry_release`
- `create_gh_release` – create GitHub Release and attach artifacts
- `tag_prefix` – defaults to `mobile-v`
- `notify_slack` – sends a Slack message via `SLACK_WEBHOOK_URL`

## Per-Platform Workflows

- Android: `.github/workflows/android_release.yml`
  - Inputs: `app_id`, `package_name`, `track`, `build_number`, `release_notes`, `upload`, `preflight`, `environment`, `sentry_*`
  - Artifacts: `android-aab`
  - Optional: Upload to Google Play when `upload=true` (gated by `environment`).

- iOS: `.github/workflows/ios_release.yml`
  - Inputs: `bundle_id`, `scheme`, `export_method`, `build_number`, `release_notes`, `upload`, `preflight`, `environment`, `sentry_*`
  - Artifacts: `ios-ipa` (signed) or `ios-app` (unsigned .app zip)
  - Optional: Upload to TestFlight when `upload=true` (gated by `environment`).

## Runbook (CI)

1. Prepare release notes text (concise, user-facing).
2. From GitHub → Actions → Run `Mobile Release`:
   - Set `build_number` (optional) and `release_notes`.
   - Set `preflight=true` for formatting, lint, and tests.
   - For dry run: keep `upload_android=false`, `upload_ios=false`.
   - For uploads: set desired flags to `true` and choose `environment` (`beta` recommended first).
   - Optional: enable `sentry_upload=true` and provide Sentry inputs/secrets.
   - Optional: enable `create_gh_release` and `notify_slack`.
3. Approve the run if the selected environment requires approval.
4. Collect artifacts from the run summary (AAB/IPA) and verify.
5. If enabled, a GitHub Release is created and a Slack message is posted.

## Secrets and Environments

Create GitHub Environments `beta` and `production`. Scope secrets to each environment and turn on required reviewers for `production`.

- Android signing and Play:
  - `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
  - `PLAY_SERVICE_ACCOUNT_JSON`

- iOS signing and TestFlight:
  - `IOS_P12_BASE64`, `IOS_P12_PASSWORD`, `IOS_MOBILEPROVISION_BASE64`
  - `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_PRIVATE_KEY_BASE64`

- Common/optional:
  - `SLACK_WEBHOOK_URL` – for notifications
  - `SENTRY_AUTH_TOKEN` – for symbol uploads

In both platform workflows, upload jobs are gated by `environment`. Configure secrets at the environment level so production uploads are protected.

## Preflight Checks

When `preflight=true`, the following run in `ai_buddy_web/` before builds:

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze`
- `flutter test -r expanded`

## Crash Reporting Symbols

- Sentry is supported optionally on both platforms:
  - Android: uploads ProGuard `mapping.txt` when available.
  - iOS: uploads dSYMs when detected.
- Provide `SENTRY_AUTH_TOKEN`, `sentry_org`, and the platform-specific `sentry_project`. `sentry_release` can override the default `<id>@<build_number>` naming.
- Note: Firebase Crashlytics upload is not configured yet. If needed, we can add Gradle `uploadCrashlyticsSymbolFile` for Android and `upload-symbols` for iOS.

## Artifacts and Outputs

- Android: `android-aab` artifact containing the release AAB.
- iOS: `ios-ipa` (signed) or `ios-app` (unsigned .app zip) artifact.
- Orchestrator (optional): GitHub Release with attached artifacts; Slack message.

## Troubleshooting

- Reusable workflow lint warnings locally ("Unable to find reusable workflow") stem from local analysis not resolving the repo slug. They resolve on GitHub when the repo slug `LKGargProjects/ai-mental-health-assistant` is correct.
- Slack step: ensure `SLACK_WEBHOOK_URL` is set in the target environment. The workflow posts plain JSON (no jq dependency).
- iOS signing: if signing secrets are missing, the iOS workflow falls back to producing an unsigned `.app` zip (no TestFlight upload).
