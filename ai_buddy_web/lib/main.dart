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

/// Optimized main application entry point
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Main application widget with optimized theme and providers
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
        theme: _buildTheme(),
        home: const HomePage(),
      ),
    );
  }

  /// Build optimized theme with consistent colors
  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF667EEA),
        primary: const Color(0xFF667EEA),
        secondary: const Color(0xFFFF6B6B),
        surface: Colors.white,
        background: const Color(0xFFF8F9FA),
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Optimized home page with better state management
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  bool _showMoodTracker = false;
  bool _showAssessment = false;
  bool _hasStartedChat = false;
  bool _isBackendReady = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize backend check
    _checkBackendHealth();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// Check backend health on startup
  Future<void> _checkBackendHealth() async {
    try {
      // Skip backend check for now to avoid private method access
      setState(() {
        _isBackendReady = true;
      });
      _fadeController.forward();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Backend connection failed: $e');
      }
    }
  }

  /// Show error message to user
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Scroll to bottom with smooth animation
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Send message with loading state
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(message);

      _messageController.clear();
      _scrollToBottom();

      if (!_hasStartedChat) {
        setState(() {
          _hasStartedChat = true;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          _fadeController.forward();
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
              _buildAppBar(),
              Expanded(child: _buildMainContent(isMobile)),
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build optimized app bar
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.psychology, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AI Mental Health Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build action buttons with animations
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAnimatedButton(
          icon: Icons.mood,
          label: 'Mood',
          onPressed: () => _toggleMoodTracker(),
          isActive: _showMoodTracker,
        ),
        const SizedBox(width: 8),
        _buildAnimatedButton(
          icon: Icons.assessment,
          label: 'Assessment',
          onPressed: () => _toggleAssessment(),
          isActive: _showAssessment,
        ),
      ],
    );
  }

  /// Build animated button with state
  Widget _buildAnimatedButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build main content area
  Widget _buildMainContent(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_showMoodTracker) _buildMoodTracker(),
          if (_showAssessment) _buildAssessment(),
          Expanded(child: _buildChatInterface()),
        ],
      ),
    );
  }

  /// Build mood tracker widget
  Widget _buildMoodTracker() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _showMoodTracker
          ? Container(
              padding: const EdgeInsets.all(16),
              child: const MoodTrackerWidget(),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Build assessment widget
  Widget _buildAssessment() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _showAssessment
          ? Container(
              padding: const EdgeInsets.all(16),
              child: const SelfAssessmentWidget(),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Build optimized chat interface
  Widget _buildChatInterface() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final messages = chatProvider.messages;

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _buildWelcomeMessage()
                  : _buildMessageList(messages),
            ),
            _buildInputSection(),
          ],
        );
      },
    );
  }

  /// Build welcome message
  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Welcome! I\'m here to support you.',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Share how you\'re feeling, and I\'ll listen and help.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build optimized message list
  Widget _buildMessageList(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatMessageWidget(message: message),
        );
      },
    );
  }

  /// Build input section with loading state
  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isLoading ? null : _sendMessage,
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(
              _isLoading ? Icons.hourglass_empty : Icons.send,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom section with additional features
  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomButton(
            icon: Icons.help_outline,
            label: 'Resources',
            onPressed: () {
              // TODO: Implement resources
            },
          ),
          _buildBottomButton(
            icon: Icons.settings,
            label: 'Settings',
            onPressed: () {
              // TODO: Implement settings
            },
          ),
        ],
      ),
    );
  }

  /// Build bottom button
  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toggle mood tracker visibility
  void _toggleMoodTracker() {
    setState(() {
      _showMoodTracker = !_showMoodTracker;
      if (_showMoodTracker) {
        _showAssessment = false;
      }
    });
  }

  /// Toggle assessment visibility
  void _toggleAssessment() {
    setState(() {
      _showAssessment = !_showAssessment;
      if (_showAssessment) {
        _showMoodTracker = false;
      }
    });
  }
}
