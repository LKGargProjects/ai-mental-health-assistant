import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/main_screen.dart';
import '../screens/dhiwise_chat_screen.dart';

class AppRoutes {
  static const String welcomeScreen = '/welcome';
  static const String mainScreen = '/main';
  static const String dhiwiseChatScreen = '/dhiwise-chat';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      welcomeScreen: (context) => const WelcomeScreen(),
      mainScreen: (context) => const MainScreen(),
      dhiwiseChatScreen: (context) => const MentalHealthChatScreen(),
    };
  }
}
