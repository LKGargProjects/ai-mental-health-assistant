import 'package:ai_buddy_web/screens/dhiwise_chat_screen.dart';
import 'package:ai_buddy_web/screens/interactive_chat_screen.dart';
import 'package:ai_buddy_web/screens/quest_preview_screen.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart'
    as DhiwiseWellness;
import 'dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;
import 'package:ai_buddy_web/dhiwise/presentation/quest_screen/quest_screen.dart'
    as DhiwiseQuest;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sentry/sentry.dart' as sentry;
import 'package:provider/provider.dart';
import 'core/utils/size_utils.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/task_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/quest_provider.dart';
import 'navigation/route_observer.dart';
import 'navigation/home_shell.dart';
import 'widgets/app_bottom_nav.dart' show AppTab;
import 'services/analytics_service.dart' show logAnalyticsEvent;
import 'services/notification_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

// Root navigator key to support global routing from notification taps
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Deduplication window for deep-link payload handling
DateTime? _lastDeepLinkAt;
String? _lastDeepLinkPayload;

// Handle notification payloads centrally
void _handleNotificationPayload(String? payload) {
  if (payload == null) return;
  if (kDebugMode) {
    try { debugPrint('[DeepLink] payload received: $payload'); } catch (_) {}
  }
  // Deduplicate identical payloads fired in quick succession (e.g., resume + tap)
  final now = DateTime.now();
  if (_lastDeepLinkPayload == payload && _lastDeepLinkAt != null) {
    final diffMs = now.difference(_lastDeepLinkAt!).inMilliseconds;
    if (diffMs < 2000) {
      if (kDebugMode) {
        try { debugPrint('[DeepLink] duplicate ignored (${diffMs}ms)'); } catch (_) {}
      }
      return;
    }
  }
  _lastDeepLinkPayload = payload;
  _lastDeepLinkAt = now;
  // Route to Explore/Quest tab. Keep backwards compatibility for 'open_today'.
  if (payload == 'open_quest' || payload == 'open_today') {
    // Immediately signal HomeShell to switch to Quest tab if it's mounted
    try {
      homeTabDeepLink.value = AppTab.quest;
    } catch (_) {}

    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      // Try after first frame if navigator not ready yet
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationPayload(payload));
      return;
    }
    // Ensure a HomeShell is the root and open with Quest tab
    nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: AppTab.quest);
  }
  if (payload == 'open_mood') {
    try {
      homeTabDeepLink.value = AppTab.mood;
    } catch (_) {}
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationPayload(payload));
      return;
    }
    nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: AppTab.mood);
  }
  if (payload == 'open_talk') {
    try {
      homeTabDeepLink.value = AppTab.talk;
    } catch (_) {}
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNotificationPayload(payload));
      return;
    }
    nav.pushNamedAndRemoveUntil('/home', (route) => false, arguments: AppTab.talk);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const dsn = String.fromEnvironment('SENTRY_DSN_FRONTEND', defaultValue: '');
  const env = String.fromEnvironment('SENTRY_ENV', defaultValue: 'local');
  const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  const tracesStr = String.fromEnvironment(
    'SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0',
  );
  final traces = double.tryParse(tracesStr) ?? 0.0;

  if (dsn.isNotEmpty) {
    await sentry.Sentry.init((options) {
      options.dsn = dsn;
      options.environment = env;
      options.release = version;
      options.tracesSampleRate = traces;
    });
  }
  // Set tap handler for notification deep-linking
  NotificationService.onSelectNotification = (payload) {
    _handleNotificationPayload(payload);
  };
  // Initialize local notifications (no-op on web). This will also
  // deliver any launch-from-notification payload via the handler above.
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Fire a minimal 'app_open' event (respects consent in ApiService)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logAnalyticsEvent(
        'app_open',
        metadata: {'action': 'app_open', 'source': 'app'},
      );
      // Handle simple deep link for web hash route: #/home/quest
      final fragment = Uri.base.fragment; // e.g., '/home/quest'
      if (fragment == '/home/quest') {
        Navigator.of(context).pushReplacementNamed('/home/quest');
      }
      // Debug 12s auto-scheduling: disabled per current plan.
      // To re-enable later, wrap in kDebugMode and call NotificationService.scheduleOneShot(...).

      // (No debug harness; dedupe verified. Keep production clean.)
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => AssessmentProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => QuestProvider()..loadQuests()),
      ],
      child: DhiwiseSizer.Sizer(
        builder: (context, o, d) => Sizer(
          builder: (context, orientation, deviceType) {
            return MaterialApp(
              title: 'AI Mental Health Buddy',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF667EEA),
                  primary: const Color(0xFF667EEA),
                  secondary: const Color(0xFFFF6B6B),
                ),
                useMaterial3: true,
              ),
              navigatorKey: rootNavigatorKey,
              navigatorObservers: [routeObserver],
              home: const HomeShell(initialTab: AppTab.talk),
              routes: {
                '/home': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  final initial = (args is AppTab) ? args : AppTab.talk;
                  return HomeShell(initialTab: initial);
                },
                '/home/quest': (context) => HomeShell(initialTab: AppTab.quest),
                // Legacy landing route redirected to HomeShell Talk tab
                '/main': (context) => HomeShell(initialTab: AppTab.talk),
                '/dhiwise-chat': (context) => const MentalHealthChatScreen(),
                '/preview-quest': (context) => const QuestPreviewScreen(),
                '/interactive-chat': (context) => const InteractiveChatScreen(),
                // New direct routes for clarity
                '/wellness-dashboard': (context) => DhiwiseSizer.Sizer(
                  builder: (context, orientation, deviceType) =>
                      DhiwiseWellness.WellnessDashboardScreen(),
                ),
                '/quests-list': (context) => const DhiwiseQuest.QuestScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}
