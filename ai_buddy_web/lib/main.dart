import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'widgets/chat_message_widget.dart';
import 'widgets/mood_tracker.dart';
import 'widgets/self_assessment_widget.dart';
import 'widgets/startup_screen.dart';
import 'models/message.dart';
import 'config/api_config.dart';

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
      ],
      child: MaterialApp(
        title: 'AI Mental Health Assistant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667EEA),
            primary: const Color(0xFF667EEA),
            secondary: const Color(0xFFFF6B6B),
          ),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showMoodTracker = false;
  bool _showAssessment = false;
  bool _hasStartedChat = false;
  bool _isBackendReady = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show startup screen if backend is not ready
    if (!_isBackendReady) {
      return StartupScreen(
        onBackendReady: () {
          setState(() {
            _isBackendReady = true;
          });
        },
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final isWeb = kIsWeb;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: isMobile ? 20 : 24,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'AI Mental Health Assistant',
                            style:
                                (isMobile
                                        ? Theme.of(context).textTheme.titleLarge
                                        : Theme.of(
                                            context,
                                          ).textTheme.headlineMedium)
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your supportive companion for mental health and emotional well-being',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12.0 : 20.0,
                  ),
                  constraints: isWeb ? BoxConstraints(maxWidth: 800) : null,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _showMoodTracker
                      ? const SingleChildScrollView(
                          padding: EdgeInsets.all(20.0),
                          child: MoodTrackerWidget(),
                        )
                      : _showAssessment
                      ? const SelfAssessmentWidget()
                      : _hasStartedChat || _hasMessages()
                      ? _buildChatInterface()
                      : _buildWelcomeInterface(),
                ),
              ),
              // Bottom navigation
              Container(
                padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showMoodTracker = !_showMoodTracker;
                          _showAssessment = false;
                          if (_showMoodTracker) {
                            _hasStartedChat = false;
                          }
                        });
                      },
                      icon: Icon(
                        _showMoodTracker ? Icons.chat : Icons.mood,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                      tooltip: _showMoodTracker
                          ? 'Show Chat'
                          : 'Show Mood Tracker',
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showAssessment = !_showAssessment;
                          _showMoodTracker = false;
                          if (_showAssessment) {
                            _hasStartedChat = false;
                          }
                        });
                      },
                      icon: Icon(
                        _showAssessment ? Icons.chat : Icons.assessment,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                      tooltip: _showAssessment
                          ? 'Show Chat'
                          : 'Self Assessment',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeInterface() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
      child: Column(
        children: [
          // Welcome message
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😊', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                'Welcome!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'I\'m here to listen, support, and help you through whatever you\'re going through. Whether you need someone to talk to, coping strategies, or just a friendly ear, I\'m here for you.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Feature cards
          Expanded(
            child: GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: isMobile ? 12 : 16,
              mainAxisSpacing: isMobile ? 12 : 16,
              childAspectRatio: isMobile ? 1.1 : 1.2,
              children: [
                _buildFeatureCard('💬', '24/7 Support'),
                _buildFeatureCard('🛡️', 'Confidential'),
                _buildFeatureCard('❤️', 'Empathetic'),
                _buildFeatureCard('💡', 'Coping Strategies'),
              ],
            ),
          ),
          // Input area
          Container(
            margin: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Share what\'s on your mind...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF667EEA),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _handleSubmitted(_messageController.text),
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String emoji, String title) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: isMobile ? 24 : 32)),
          const SizedBox(height: 8),
          Text(
            title,
            style:
                (isMobile
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatInterface() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        // Chat header
        Container(
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat, color: Color(0xFF667EEA)),
              const SizedBox(width: 8),
              Text(
                'Chat with AI Assistant',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Chat messages
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                itemCount: chatProvider.messages.length,
                itemBuilder: (context, index) {
                  return ChatMessageWidget(
                    message: chatProvider.messages[index],
                  );
                },
              );
            },
          ),
        ),
        // Typing indicator
        Consumer<ChatProvider>(
          builder: (context, chatProvider, child) {
            if (!chatProvider.isLoading) return const SizedBox.shrink();
            return Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('AI is typing...'),
                  ),
                ],
              ),
            );
          },
        ),
        // Input area
        Container(
          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Share what\'s on your mind...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                    onSubmitted: _handleSubmitted,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF667EEA),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => _handleSubmitted(_messageController.text),
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _hasStartedChat = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  bool _hasMessages() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    return chatProvider.messages.isNotEmpty;
  }
}
