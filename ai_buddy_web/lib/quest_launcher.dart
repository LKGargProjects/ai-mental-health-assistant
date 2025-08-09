import 'package:flutter/material.dart';
import 'screens/quest_screen/quest_screen.dart';
import 'screens/quest_screen/widgets/quest_card_widget.dart';

void main() {
  runApp(const QuestLauncherApp());
}

class QuestLauncherApp extends StatelessWidget {
  const QuestLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          primary: const Color(0xFF667EEA),
          secondary: const Color(0xFFFF6B6B),
        ),
      ),
      home: const Scaffold(
        body: QuestScreen(),
      ),
    );
  }
}
