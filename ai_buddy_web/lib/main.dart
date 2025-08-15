import 'package:ai_buddy_web/screens/dhiwise_chat_screen.dart';
import 'package:ai_buddy_web/screens/interactive_chat_screen.dart';
import 'package:ai_buddy_web/screens/quest_preview_screen.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart' as DhiwiseWellness;
import 'dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;
import 'package:ai_buddy_web/dhiwise/presentation/quest_screen/quest_screen.dart' as DhiwiseQuest;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const dsn = String.fromEnvironment('SENTRY_DSN_FRONTEND', defaultValue: '');
  const env = String.fromEnvironment('SENTRY_ENV', defaultValue: 'local');
  const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  const tracesStr = String.fromEnvironment('SENTRY_TRACES_SAMPLE_RATE', defaultValue: '0');
  final traces = double.tryParse(tracesStr) ?? 0.0;

  if (dsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = env;
        options.release = version;
        options.tracesSampleRate = traces;
      },
      appRunner: () => runApp(const MyApp()),
    );
  } else {
    runApp(const MyApp());
  }
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
      ApiService().logAnalyticsEvent('app_open', metadata: {
        'action': 'app_open',
        'source': 'app',
      });
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
        builder: (context, _o, _d) => Sizer(
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
              navigatorObservers: [routeObserver],
              home: const InteractiveChatScreen(),
              routes: {
                '/home': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  final initial = (args is AppTab) ? args : AppTab.talk;
                  return HomeShell(initialTab: initial);
                },
                // Legacy landing route redirected to HomeShell Talk tab
                '/main': (context) => HomeShell(initialTab: AppTab.talk),
                '/dhiwise-chat': (context) => const MentalHealthChatScreen(),
                '/preview-quest': (context) => const QuestPreviewScreen(),
                '/interactive-chat': (context) => const InteractiveChatScreen(),
                // New direct routes for clarity
                '/wellness-dashboard': (context) => DhiwiseSizer.Sizer(
                      builder: (context, orientation, deviceType) => DhiwiseWellness.WellnessDashboardScreen(),
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