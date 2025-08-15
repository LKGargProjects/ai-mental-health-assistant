import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'dhiwise_quest_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => QuestProvider())],
      child: const QuestPreviewApp(),
    ),
  );
}

class QuestPreviewApp extends StatelessWidget {
  const QuestPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quest Screen Preview',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DhiwiseQuestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
