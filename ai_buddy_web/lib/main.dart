import 'package:ai_buddy_web/screens/main_screen.dart';
import 'package:ai_buddy_web/screens/welcome_screen.dart';
import 'package:ai_buddy_web/screens/dhiwise_chat_screen.dart';
import 'package:ai_buddy_web/screens/interactive_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/utils/size_utils.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/task_provider.dart';
import 'providers/progress_provider.dart';

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
      ],
      child: Sizer(
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
            home: const WelcomeScreen(),
            routes: {
              '/main': (context) => const MainScreen(),
              '/dhiwise-chat': (context) => const MentalHealthChatScreen(),
              '/interactive-chat': (context) => const InteractiveChatScreen(),
            },
          );
        },
      ),
    );
  }
}