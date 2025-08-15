import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_buddy_web/providers/quest_provider.dart';
import 'package:ai_buddy_web/dhiwise/core/utils/size_utils.dart';
import 'package:ai_buddy_web/dhiwise/presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';

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
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'Wellness Dashboard Preview',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Inter',
          ),
          home: WellnessDashboardScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
