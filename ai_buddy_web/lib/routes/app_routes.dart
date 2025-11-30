import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/main_screen.dart';
import '../screens/dhiwise_chat_screen.dart';

class AppRoutes {
  // Global navigator key used by deep links and other services
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Legacy named routes
  static const String welcomeScreen = '/welcome';
  static const String mainScreen = '/main';
  static const String dhiwiseChatScreen = '/dhiwise-chat';

  // Additional routes referenced by DeepLinkService
  static const String interactiveChat = '/interactive-chat';
  static const String moodTracker = '/home';
  static const String questScreen = '/home/quest';
  static const String wellnessDashboard = '/wellness-dashboard';
  static const String crisisResources = '/crisis';
  static const String assessment = '/assessment';
  static const String home = '/home';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      welcomeScreen: (context) => const WelcomeScreen(),
      mainScreen: (context) => const MainScreen(),
      dhiwiseChatScreen: (context) => const MentalHealthChatScreen(),
    };
  }
}
