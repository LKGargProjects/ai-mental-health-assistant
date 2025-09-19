import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Real implementation for mobile/desktop (non-web) platforms.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _reminderNotificationId = 10001;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'daily_checkin_channel',
    'Daily Check‑in',
    description: 'Reminds you to do your quick wellness check‑in',
    importance: Importance.high,
  );

  static bool _inited = false;
  // Optional callback set by app code to handle notification taps/deep-links.
  static void Function(String? payload)? onSelectNotification;

  static Future<void> init() async {
    if (_inited || kIsWeb) {
      _inited = true;
      return;
    }

    // Android init
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS (Darwin) init
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      // Optionally handle taps by reading payload in app code if needed later
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Forward tap payload to app layer for routing.
        // Handle notification tap silently
        try {
          onSelectNotification?.call(response.payload);
        } catch (_) {}
      },
    );

    // Timezone database needed for accurate scheduling across DST/timezones
    try {
      tz.initializeTimeZones();
    } catch (_) {}

    // Create Android channel explicitly
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_channel);
      // Android 13+ runtime permission
      await androidImpl?.requestNotificationsPermission();
    }

    // If the app was launched via a notification, forward that payload too.
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if ((launchDetails?.didNotificationLaunchApp ?? false)) {
        onSelectNotification?.call(launchDetails?.notificationResponse?.payload);
      }
    } catch (_) {}

    _inited = true;
  }

  /// Cancel any previously scheduled reminder notification
  static Future<void> cancelReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Schedule a one-shot local notification at the provided local time.
  static Future<void> scheduleOneShot({
    required DateTime target,
    String title = 'Daily check‑in',
    String body = 'Take 2 minutes to reflect and log your mood.',
    int? notificationId,
    String payload = 'open_quest',
    bool cancelPrevious = true,
    String debugTag = '',
  }) async {
    if (kIsWeb) return;

    // Ensure initialized
    if (!_inited) {
      await init();
    }

    // Determine the ID to use (default to reminder id)
    final int id = notificationId ?? _reminderNotificationId;

    // Defensive: cancel any previous pending notification with the same id to avoid duplicates
    if (cancelPrevious) {
      if (id == _reminderNotificationId) {
        await cancelReminder();
      } else {
        await _plugin.cancel(id);
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: const DefaultStyleInformation(true, true),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tz.TZDateTime tzTarget = tz.TZDateTime.from(target, tz.local);

    // Debug logging for scheduling
    // Schedule notification silently

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTarget,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      // Do not set matchDateTimeComponents to keep it one-shot
    );
  }
}
