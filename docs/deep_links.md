# Deep Link & Notification Routing (Flutter)

This document summarizes how deep-link payloads and local notification taps route users within the app.

- __Entry points__
  - `NotificationService.init()` sets `onDidReceiveNotificationResponse` to forward tap payloads to the app.
  - `main.dart` assigns `NotificationService.onSelectNotification = _handleNotificationPayload`.

- __Handler__
  - `lib/main.dart::_handleNotificationPayload(String? payload)`
    - Dedupe guard: ignores identical payloads received within 2 seconds (debug logs only in `kDebugMode`).
    - Routes using a global navigator key `rootNavigatorKey` and the shared `homeTabDeepLink` ValueNotifier.

- __Routing map__
  - `open_quest` (also accepts legacy `open_today`) → `AppTab.quest`
  - `open_mood` → `AppTab.mood`
  - `open_talk` → `AppTab.talk`

- __Navigation model__
  - `lib/navigation/home_shell.dart`
    - `homeTabDeepLink: ValueNotifier<AppTab>` is observed by `HomeShell` to switch tabs globally.
    - When already on the target tab, the tab’s navigator pops to root and triggers a reselect action.

- __Web hash deep-link (basic)__
  - In `MyApp.initState()`, fragment `#/home/quest` is redirected to `/home/quest` (direct route). This is unrelated to notification payloads.

- __Logging policy__
  - All deep-link and notification logs are gated by `kDebugMode` and use `debugPrint`.
  - Release builds remain clean.

- __Notes__
  - `NotificationService` is a lightweight wrapper around `flutter_local_notifications` v17 with timezone-aware scheduling.
  - For device testing, verify payload delivery in: cold start, background, and foreground states (see checklist in `docs/testing/deep_link_notifications_checklist.md`).
