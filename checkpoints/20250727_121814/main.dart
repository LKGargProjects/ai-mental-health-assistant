import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'widgets/chat_message_widget.dart';
import 'widgets/mood_tracker.dart';
import 'models/message.dart';

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AI Mental Health Buddy'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showMoodTracker ? Icons.chat : Icons.mood),
            onPressed: () {
              setState(() {
                _showMoodTracker = !_showMoodTracker;
              });
            },
            tooltip: _showMoodTracker ? 'Show Chat' : 'Show Mood Tracker',
          ),
        ],
      ),
      body: _showMoodTracker
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: MoodTrackerWidget(),
            )
          : Column(
              children: [
                // Welcome message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Welcome to Your Safe Space',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Feel free to share your thoughts and feelings. I\'m here to listen and support you.',
                        style: Theme.of(context).textTheme.bodyLarge,
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
                        padding: const EdgeInsets.all(8.0),
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
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
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
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Share your thoughts...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: _handleSubmitted,
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () =>
                              _handleSubmitted(_messageController.text),
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }
}
