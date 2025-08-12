import 'package:ai_buddy_web/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: MaterialApp(
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
      ),
    );
  }
}

class ChatFigmaScreen extends StatelessWidget {
  const ChatFigmaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a placeholder for the Figma-based chat UI.
    // Replace with the full widget tree as you build out the design.
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/background_placeholder.png',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.05),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          // Main chat content
          Column(
            children: [
              // Header
              Container(
                height: 117,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 33,
                      backgroundImage: AssetImage(
                        'images/avatar_placeholder.png',
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Name
                    const Text(
                      'Alex',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF323846),
                      ),
                    ),
                  ],
                ),
              ),
              // Chat area (placeholder)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: const [
                    // Example chat bubbles
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ChatBubble(
                        text: "Hey there! How are you feeling today?",
                        isUser: false,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ChatBubble(
                        text: "I'm feeling a bit overwhelmed.",
                        isUser: true,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ChatBubble(
                        text:
                            "I understand. It's okay to feel that way. Want to talk more about it?",
                        isUser: false,
                      ),
                    ),
                  ],
                ),
              ),
              // Input bar
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 0, 21, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(35),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Type a message..',
                          style: TextStyle(
                            color: Color(0xFF959AA5),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF767F89)),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFE7E9F0) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? const Color(0xFF767F89) : const Color(0xFF5B6A6A),
          fontSize: 16,
        ),
      ),
    );
  }
}
