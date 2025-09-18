/// Web stub for NotificationService.
/// Provides the same API but performs no-ops, so Flutter Web builds
/// don't attempt to link native notification plugins.
class NotificationService {
  static void Function(String? payload)? onSelectNotification;

  static Future<void> init() async {
    // no-op on web
  }

  static Future<void> cancelReminder() async {
    // no-op on web
  }

  static Future<void> scheduleOneShot({
    required DateTime target,
    String title = 'Daily check‑in',
    String body = 'Take 2 minutes to reflect and log your mood.',
    int? notificationId,
    String payload = 'open_quest',
    bool cancelPrevious = true,
    String debugTag = '',
  }) async {
    // no-op on web
  }
}
