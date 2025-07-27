import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'models/chat_mode.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chatProvider.currentMode.icon),
            const SizedBox(width: 8),
            Text(chatProvider.currentMode.displayName),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.setThemeMode(
                themeProvider.isDarkMode ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
        ],
      ),
      body: const ChatScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: chatProvider.currentMode == ChatMode.mentalHealth ? 0 : 1,
        onDestinationSelected: (index) {
          chatProvider.setMode(
            index == 0 ? ChatMode.mentalHealth : ChatMode.academic,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Text('❤️'),
            label: 'Mental Health',
          ),
          NavigationDestination(
            icon: Text('📚'),
            label: 'Academic',
          ),
        ],
      ),
    );
  }
} 