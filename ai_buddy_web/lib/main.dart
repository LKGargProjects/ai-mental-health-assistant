import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/assessment_provider.dart';
import 'providers/task_provider.dart';
import 'providers/progress_provider.dart';
import 'widgets/chat_message_widget.dart';
import 'widgets/mood_tracker.dart';
import 'widgets/self_assessment_screen.dart';
import 'widgets/task_list_screen.dart';
import 'widgets/community_feed_screen.dart';

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
  int _currentIndex = 0;

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
          // Assessment button
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SelfAssessmentScreen(),
                ),
              );
            },
            tooltip: 'Mental Health Assessment',
          ),
          // Tasks button
          IconButton(
            icon: const Icon(Icons.task_alt),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TaskListScreen()),
              );
            },
            tooltip: 'Wellness Tasks',
          ),
          // Community button
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CommunityFeedScreen(),
                ),
              );
            },
            tooltip: 'Community',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Chat screen
          _buildChatScreen(),
          // Mood tracker screen
          _buildMoodTrackerScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.mood), label: 'Mood'),
        ],
      ),
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        // Welcome message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.3),
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickActionChip(
                    'Take Assessment',
                    Icons.psychology,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SelfAssessmentScreen(),
                        ),
                      );
                    },
                  ),
                  _buildQuickActionChip('View Tasks', Icons.task_alt, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TaskListScreen(),
                      ),
                    );
                  }),
                  _buildQuickActionChip('Community', Icons.people, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CommunityFeedScreen(),
                      ),
                    );
                  }),
                ],
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
                      color: Theme.of(context).colorScheme.secondaryContainer,
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
                  onPressed: () => _handleSubmitted(_messageController.text),
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodTrackerScreen() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: MoodTrackerWidget(),
    );
  }

  Widget _buildQuickActionChip(
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    // MVP Testing: Use India for crisis detection testing
    // TODO: Implement proper country detection or user preference
    print('🔍 DEBUG: Sending message with country: in');
    chatProvider.sendMessage(text, country: 'in');
    _messageController.clear();
    _scrollToBottom();
  }
}
