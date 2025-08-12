import 'package:ai_buddy_web/screens/main_screen.dart';
import 'package:ai_buddy_web/screens/welcome_screen.dart';
import 'package:ai_buddy_web/screens/dhiwise_chat_screen.dart';
import 'package:ai_buddy_web/screens/interactive_chat_screen.dart';
import 'package:ai_buddy_web/screens/quest_preview_screen.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart' as DhiwiseWellness;
import 'dhiwise/core/utils/size_utils.dart' as DhiwiseSizer;
import 'package:ai_buddy_web/dhiwise/presentation/quest_screen/quest_screen.dart' as DhiwiseQuest;

import 'package:flutter/material.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
              home: const WelcomeScreen(),
              routes: {
                '/home': (context) {
                  final args = ModalRoute.of(context)?.settings.arguments;
                  final initial = (args is AppTab) ? args : AppTab.talk;
                  return HomeShell(initialTab: initial);
                },
                '/main': (context) => const MainScreen(),
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