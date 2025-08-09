import 'package:flutter/material.dart';
import '../presentation/mental_health_chat_screen/mental_health_chat_screen.dart';
import '../presentation/wellness_dashboard_screen/wellness_dashboard_screen.dart';

import '../presentation/app_navigation_screen/app_navigation_screen.dart';

class AppRoutes {
  static const String mentalHealthChatScreen = '/mental_health_chat_screen';
  static const String wellnessDashboardScreen = '/wellness_dashboard_screen';

  static const String appNavigationScreen = '/app_navigation_screen';
  static const String initialRoute = '/';

  static Map<String, WidgetBuilder> get routes => {
        mentalHealthChatScreen: (context) => MentalHealthChatScreen(),
        wellnessDashboardScreen: (context) => WellnessDashboardScreen(),
        appNavigationScreen: (context) => AppNavigationScreen(),
        initialRoute: (context) => AppNavigationScreen()
      };
}
