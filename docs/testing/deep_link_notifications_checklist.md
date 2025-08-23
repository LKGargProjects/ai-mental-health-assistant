# On-Device Test Checklist: Deep Links & Notification Taps

Use this to validate routing behavior is stable across app states on Android and iOS.

- __Prereqs__
  - Notifications allowed for the app (iOS: Settings → Notifications → Allow).
  - Build contains `NotificationService.init()` and `_handleNotificationPayload()` wiring (present in repo).
  - For Android 13+: runtime notification permission granted.

- __Payloads to test__
  - `open_quest` (also legacy `open_today`)
  - `open_mood`
  - `open_talk`

- __Routing expectations__
  - `open_quest` → `HomeShell` `AppTab.quest`
  - `open_mood` → `HomeShell` `AppTab.mood`
  - `open_talk` → `HomeShell` `AppTab.talk`

- __Scenarios__
  1. Cold start (terminated)
     - Deliver notification with payload (e.g., `open_quest`).
     - Tap the notification.
     - Expect app to launch to correct tab.
  2. Background
     - App is backgrounded.
     - Deliver notification with payload.
     - Tap notification.
     - Expect app returns to foreground and navigates to correct tab.
  3. Foreground
     - App is in foreground.
     - Deliver notification with payload.
     - Tap notification banner (iOS) or tray (Android).
     - Expect tab switch in-app without restarting app.
  4. Duplicate tap dedupe
     - Quickly trigger two identical taps/opens within ~2 seconds (e.g., tap then re-tap).
     - Expect only a single navigation.
     - In Debug build, confirm log: `[DeepLink] duplicate ignored (<n>ms)`.
  5. Already-on-tab reselect behavior
     - If already on target tab, tapping should pop that tab’s stack to root and trigger reselect behavior.
  6. Mixed payloads
     - From quest tab, tap `open_mood` and `open_talk` payloads.
     - Confirm correct tab switch each time.

- __Web hash (optional)__
  - Navigate to URL with `#/home/quest` fragment.
  - Expect redirect to `/home/quest` route.

- __What to capture__
  - Platform version, device model, app build (commit/tag).
  - Any deviations from expected routing.
  - Whether a duplicate navigation occurred.

- __Relevant code__
  - `lib/services/notification_service.dart` → `NotificationService.init()`, tap callback wiring.
  - `lib/main.dart` → `_handleNotificationPayload()`, dedupe + navigation.
  - `lib/navigation/home_shell.dart` → `homeTabDeepLink` handler, per-tab navigators.

