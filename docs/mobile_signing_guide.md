# Mobile Signing & Release Guide

This guide summarizes how to sign and build Android and iOS releases for the Flutter module at `ai_buddy_web/`, using the scripts and examples in `scripts/`.

## Android (App Bundle AAB)

- __Keystore (local)__
  - Create a keystore (replace passwords/alias):
    ```bash
    keytool -genkeypair -v -keystore upload-keystore.jks -alias upload \
      -keyalg RSA -keysize 2048 -validity 10000
    ```
  - Place it at `ai_buddy_web/android/app/upload-keystore.jks` (or another path).
  - Either create `ai_buddy_web/android/key.properties` (Gradle default) or use env vars.
- __Env file option__
  - Copy `scripts/android_signing.env.example` to `scripts/android_signing.env` and fill:
    - `STORE_FILE`
    - `STORE_PASSWORD`
    - `KEY_ALIAS`
    - `KEY_PASSWORD`
- __Local build__
  - Run: `./scripts/release_android_aab.sh`
  - The script supports three modes:
    - `key.properties` if `ai_buddy_web/android/key.properties` exists
    - `env-vars` if any of `STORE_FILE/STORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD` are set
    - `debug-fallback` if neither is present (installable but not Play-ready)
  - Output AAB is auto-located and printed at the end.
- __CI/Secrets (optional)__
  - Use `./scripts/encode_keystore.sh path/to/upload-keystore.jks` to base64-encode keystore.
  - Store the base64 string and passwords as CI secrets, then reconstruct keystore at runtime and export env vars expected by Gradle or the script.

## iOS (IPA)

- __Prereqs__
  - Xcode installed and signed in with your Apple ID.
  - A valid signing certificate and provisioning profile accessible to Xcode.
  - App identifiers are centralized in `ai_buddy_web/ios/Config/AppIdentifiers.xcconfig`.
- __Env file option__
  - Copy `scripts/ios_signing.env.example` to `scripts/ios_signing.env` and fill:
    - `IOS_EXPORT_METHOD` (e.g., `app-store`, `ad-hoc`, `development`, `enterprise`)
    - `APPLE_TEAM_ID`
    - Optional: `IOS_BUNDLE_ID` and `IOS_PROVISIONING_PROFILE_SPECIFIER` to pin a specific profile
- __Local build__
  - Use: `./scripts/release_ios_ipa.sh`
  - The script will:
    - Build the Flutter iOS archive
    - Generate an ExportOptions.plist based on env values
    - Export an IPA and print its path
- __Notes__
  - Automatic signing works when the correct team is selected and Xcode can resolve a profile.
  - If automatic signing collides with multiple profiles, set `IOS_BUNDLE_ID` and `IOS_PROVISIONING_PROFILE_SPECIFIER` explicitly in the env file.

## Notification Integration (verification snapshot)

- `NotificationService` is initialized in `ai_buddy_web/lib/main.dart` and sets `onSelectNotification` for deep-link payload handling.
- The wellness reminder uses `NotificationService.scheduleOneShot(...)` with `debugTag: 'daily_reminder'` in `ai_buddy_web/lib/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart`.
- A hidden debug trigger can schedule a quick test notification from `ai_buddy_web/lib/widgets/app_bottom_nav.dart` when in debug mode.

## Troubleshooting

- If Android build uses `debug-fallback`, ensure keystore or env vars are provided.
- For iOS signing issues, verify you’re logged into the correct Apple team and that profiles exist for the `BUNDLE_ID`.
- Run `flutter clean && flutter pub get` and (for iOS) `pod install` in `ai_buddy_web/ios` if dependencies changed.
