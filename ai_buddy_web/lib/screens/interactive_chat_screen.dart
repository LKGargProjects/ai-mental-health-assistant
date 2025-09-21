import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/status_avatar.dart';
import '../config/profile_config.dart';
import '../core/utils/size_utils.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/keyboard_dismissible_scaffold.dart';
import '../widgets/safety_legal_sheet.dart';
import '../widgets/crisis_resources.dart';

class InteractiveChatScreen extends StatefulWidget {
  final bool showBottomNav;
  final ValueNotifier<int>? reselect;
  const InteractiveChatScreen({super.key, this.showBottomNav = true, this.reselect});

  @override
  State<InteractiveChatScreen> createState() => _InteractiveChatScreenState();
}

class _InteractiveChatScreenState extends State<InteractiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  double _lastBottomInset = 0.0;
  final GlobalKey _inputBarKey = GlobalKey();
  double _inputBarHeight = 0.0;
  
  // One-time legal acknowledgment key
  static const _prefsLegalAckV1 = 'legal_ack_v1';
  // Global in-flight guard to prevent duplicate Safety & Legal sheet
  static bool _legalSheetShowing = false;
  // Chat disclaimer cadence: show small top notice for first few sessions
  static const _prefsDisclaimerSeenCount = 'chat_disclaimer_seen_count_v1';
  static const _maxDisclaimerSessions = 3;
  int _disclaimerSeenCount = 0;
  bool _showTopDisclaimer = false;

  Future<void> _ensureLegalAck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ack = prefs.getBool(_prefsLegalAckV1) ?? false;
      if (!ack && mounted) {
        // Prevent double invocation from concurrent mounts/renders
        if (_legalSheetShowing) return;
        _legalSheetShowing = true;
        try {
          await showSafetyLegalSheet(context, requireAcknowledge: true);
        } finally {
          _legalSheetShowing = false;
        }
        await prefs.setBool(_prefsLegalAckV1, true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Safety & Legal ack check failed: $e');
    }
  }

  Future<void> _loadDisclaimerPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getInt(_prefsDisclaimerSeenCount) ?? 0;
      if (!mounted) return;
      setState(() {
        _disclaimerSeenCount = seen;
        _showTopDisclaimer = seen < _maxDisclaimerSessions;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Disclaimer prefs read failed: $e');
    }
  }

  Future<void> _dismissTopDisclaimer({bool increment = true}) async {
    if (mounted) {
      setState(() => _showTopDisclaimer = false);
    }
    if (!increment) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (_disclaimerSeenCount + 1).clamp(0, _maxDisclaimerSessions);
      await prefs.setInt(_prefsDisclaimerSeenCount, next);
      if (!mounted) return;
      setState(() => _disclaimerSeenCount = next);
    } catch (e) {
      if (kDebugMode) debugPrint('Disclaimer prefs write failed: $e');
    }
  }

  void _onReselect() {
    // On re-tap, bring the latest messages into view
    _scrollToBottom();
  }

  Future<void> _showAllCrisisResourcesSheet(List<Map<String, dynamic>> numbers) async {
    if (numbers.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: appTheme.whiteCustom,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.h, 12.h, 16.h, 4.h),
                  child: Text(
                    'Crisis resources',
                    style: TextStyleHelper.instance.headline24Bold,
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(8.h, 8.h, 8.h, 8.h),
                    itemCount: numbers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final n = numbers[i];
                      final name = (n['name'] ?? '').toString();
                      final number = ((n['number'] ?? n['phone']) ?? '').toString().trim();
                      final textInstr = (n['text'] ?? '').toString().trim();
                      return ListTile(
                        dense: false,
                        title: Text(name.isNotEmpty
                            ? name
                            : (number.isNotEmpty
                                ? number
                                : (textInstr.isNotEmpty ? textInstr : 'Resource'))),
                        subtitle: number.isNotEmpty
                            ? Text(number)
                            : (textInstr.isNotEmpty ? Text(textInstr) : null),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (number.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_forwarded_rounded),
                                tooltip: 'Call',
                                onPressed: () async {
                                  final uri = Uri(scheme: 'tel', path: number);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else {
                                    await Clipboard.setData(ClipboardData(text: number));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Call not supported. Number copied to clipboard.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            if (textInstr.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.sms_rounded),
                                tooltip: 'Text',
                                onPressed: () async {
                                  // Parse patterns like "HOME to 741741" (optionally prefixed by 'Text ')
                                  String s = textInstr.trim();
                                  if (s.toLowerCase().startsWith('text ')) {
                                    s = s.substring(5).trim();
                                  }
                                  final reg = RegExp(r'^(.+?)\s+to\s+(\d+)$', caseSensitive: false);
                                  final m = reg.firstMatch(s);
                                  if (m != null) {
                                    final body = m.group(1)!.trim();
                                    final to = m.group(2)!.trim();
                                    final uri = Uri(
                                      scheme: 'sms',
                                      path: to,
                                      queryParameters: {'body': body},
                                    );
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      await Clipboard.setData(ClipboardData(text: textInstr));
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('SMS not supported. Instructions copied to clipboard.')),
                                        );
                                      }
                                    }
                                  } else {
                                    await Clipboard.setData(ClipboardData(text: textInstr));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Instructions copied to clipboard.')),
                                      );
                                    }
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Copy',
                              onPressed: () async {
                                final toCopy = number.isNotEmpty ? number : (textInstr.isNotEmpty ? textInstr : name);
                                if (toCopy.trim().isEmpty) return;
                                await Clipboard.setData(ClipboardData(text: toCopy.trim()));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied to clipboard.')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHelpSheet() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.0,
              top: 12.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Need help now?',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(ctx).maybePop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you are in immediate danger, call your local emergency number.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  const CrisisResourcesWidget(riskLevel: RiskLevel.high),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).maybePop();
                        await showSafetyLegalSheet(context);
                      },
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Safety & Legal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize with some sample messages if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.messages.isEmpty) {
        _addSampleMessages(chatProvider);
      }
      // Ensure we start at the latest message
      _scrollToBottom();
      // One-time Safety & Legal acknowledgment
      _ensureLegalAck();
      // Load disclaimer cadence and decide whether to show top notice
      _loadDisclaimerPrefs();
    });
    // Listen for tab reselect events
    widget.reselect?.addListener(_onReselect);
  }

  @override
  void didUpdateWidget(covariant InteractiveChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselect != widget.reselect) {
      oldWidget.reselect?.removeListener(_onReselect);
      widget.reselect?.addListener(_onReselect);
    }
  }

  void _addSampleMessages(ChatProvider chatProvider) {
    // The ChatProvider already loads initial greeting message
    // No need to add sample messages as the provider handles this
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messageText = _messageController.text.trim();
    _messageController.clear();
    // Keep the input focused (especially on iOS) after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
    // Fire-and-forget send. Provider will immediately add the user message and set typing.
    // Scroll now to reveal the just-added message, and handle errors non-blockingly.
    _scrollToBottom();
    chatProvider.sendMessage(messageText).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final target = _scrollController.position.maxScrollExtent;
      if (bottomInset > 0) {
        // When keyboard is open, jump to avoid animation lag
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if (bottomInset != _lastBottomInset) {
      _lastBottomInset = bottomInset;
      // When keyboard shows/hides, keep view pinned to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    // Measure input bar height post-frame and update padding accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _inputBarKey.currentContext;
      if (ctx != null) {
        final newH = ctx.size?.height ?? 0.0;
        if (newH != _inputBarHeight && mounted) {
          setState(() => _inputBarHeight = newH);
        }
      }
    });
    return KeyboardDismissibleScaffold(
      safeTop: false,
      safeBottom: false,
      bottomNavigationBar: widget.showBottomNav ? const AppBottomNav(current: AppTab.talk) : null,
      body: PopScope(
        canPop: !_inputFocus.hasFocus,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _inputFocus.hasFocus) {
            // First back press: dismiss keyboard instead of popping
            _inputFocus.unfocus();
          }
        },
        child: Stack(
          children: [
            // Plain themed background
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            // Main Content
            Column(
              children: [
                // Header
                Container(
                  color: appTheme.whiteCustom,
                  padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: Row(
                      children: [
                        Builder(
                          builder: (ctx) {
                            final route = ModalRoute.of(ctx);
                            final isModal = route is PageRoute && route.fullscreenDialog == true;
                            // Show back button only when keyboard is open; keep layout stable otherwise
                            return KeyboardAwareBackButton(isModal: isModal, size: 44.h);
                          },
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StatusAvatar(
                                name: ProfileConfig.aiName,
                                imageAsset: ProfileConfig.aiAvatarAsset,
                                size: 66.h,
                                status: PresenceStatus.online,
                                showStatus: true,
                              ),
                              SizedBox(width: 12.h),
                              Text(
                                ProfileConfig.aiName,
                                style: TextStyleHelper.instance.headline24Bold,
                              ),
                            ],
                          ),
                        ),
                        // Overflow menu for Safety & Legal access
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (value) async {
                            switch (value) {
                              case 'help':
                                await _showHelpSheet();
                                break;
                              case 'safety':
                                await showSafetyLegalSheet(context);
                                break;
                              case 'settings':
                                Navigator.of(context).pushNamed('/settings');
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'help',
                              child: Text('Help'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'safety',
                              child: Text('Safety & Legal'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'settings',
                              child: Text('Settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(
                  height: 8.h,
                  color: appTheme.colorFFF3F4,
                ),
                // Ephemeral top disclaimer (first few sessions only)
                Builder(builder: (ctx) {
                  final isKb = MediaQuery.viewInsetsOf(ctx).bottom > 0;
                  if (!_showTopDisclaimer || isKb) return const SizedBox.shrink();
                  return Semantics(
                    label: 'Wellness disclaimer',
                    child: Container(
                      width: double.infinity,
                      color: Colors.amber.shade50,
                      padding: EdgeInsets.fromLTRB(12.h, 8.h, 4.h, 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, size: 18.0, color: Colors.black54),
                          SizedBox(width: 8.h),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(fontSize: 12.0, color: Colors.black87, height: 1.2),
                                children: const [
                                  TextSpan(text: 'Not medical care. For crisis, call local emergency.'),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dismiss',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _dismissTopDisclaimer(increment: true),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                // Chat Messages
                Expanded(
                  child: Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      // Always keep view pinned to bottom on updates (new msgs/typing)
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                      final count = chatProvider.messages.length + (chatProvider.isTyping ? 1 : 0);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(16.h, 16.h, 16.h, _inputBarHeight + 8.h),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                        itemCount: count,
                        itemBuilder: (context, index) {
                          final isTypingRow = chatProvider.isTyping && index == chatProvider.messages.length;
                          if (isTypingRow) {
                            return _buildTypingBubble();
                          }
                          final message = chatProvider.messages[index];
                          final isLast = index == chatProvider.messages.length - 1 && !chatProvider.isTyping;
                          return _buildMessageBubble(message, isLast: isLast);
                        },
                      );
                    },
                  ),
                ),
                // Input Area
              Container(
                key: _inputBarKey,
                color: appTheme.whiteCustom,
                padding: EdgeInsets.fromLTRB(16.h, 4.h, 0.h, 16.h),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  left: false,
                  right: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: appTheme.colorFFF3F4,
                                borderRadius: BorderRadius.circular(24.h),
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _inputFocus,
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(
                                    fontSize: 16.0, // iOS standard input text size
                                    color: Colors.grey[600],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.h,
                                    vertical: 10.h,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 16.0, // iOS standard input text size
                                  color: Colors.black87,
                                ),
                                onSubmitted: (_) {
                                  // Match the send button exactly: send without dismissing the keyboard
                                  _sendMessage();
                                  // Reassert focus to keep iOS keyboard open
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) _inputFocus.requestFocus();
                                  });
                                },
                                // Prevent the default editing-complete behavior from unfocusing on iOS
                                onEditingComplete: () {},
                                textInputAction: TextInputAction.send,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                minLines: 1,
                              ),
                            ), // end Container
                          ), // end Expanded
                          SizedBox(width: 8.h),
                          SizedBox(
                            width: 74.h,
                            child: Center(
                              child: Semantics(
                                button: true,
                                label: 'Send message',
                                child: GestureDetector(
                                  onTap: _sendMessage,
                                  child: Container(
                                    padding: EdgeInsets.all(10.h),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 32.h,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, {bool isLast = false}) {
    // Guard: Do not render empty assistant messages (prevents blank bubble on web)
    if (!message.isUser && message.content.trim().isEmpty) {
      if (kDebugMode) debugPrint('[UI] Skipping empty assistant message bubble');
      return const SizedBox.shrink();
    }
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
      margin: EdgeInsets.only(bottom: isLast ? 4.h : 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            StatusAvatar(
              name: ProfileConfig.aiName,
              imageAsset: ProfileConfig.aiAvatarAsset,
              size: 52.h,
              status: PresenceStatus.online,
              showStatus: true,
            ),
            SizedBox(width: 12.h),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 12.h),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.green.shade100 : appTheme.whiteCustom,
                borderRadius: BorderRadius.circular(16.h),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4.h,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w400,
                      color: appTheme.colorFF1F29,
                      height: 1.4,
                    ),
                  ),
                  // Hidden: do not render internal crisis debug content in UI
                  if (!message.isUser && (message.crisisNumbers != null && message.crisisNumbers!.isNotEmpty)) ...[
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 8.h,
                      runSpacing: 4.h,
                      children: [
                        for (final n in message.crisisNumbers!.take(3))
                          _CrisisChip(
                            name: (n['name'] ?? '').toString(),
                            phone: ((n['number'] ?? n['phone']) ?? '').toString(),
                            textInstr: (n['text'] ?? '').toString(),
                          ),
                        if (message.crisisNumbers!.length > 3)
                          Semantics(
                            button: true,
                            label: 'More crisis resources',
                            child: GestureDetector(
                              onTap: () => _showAllCrisisResourcesSheet(message.crisisNumbers!),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: const Text(
                                  'More…',
                                  style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Semantics(
                      label: 'Safety note',
                      child: Text(
                        'These resources are informational and not a substitute for professional care. If you\'re in immediate danger, call your local emergency number.',
                        style: TextStyle(
                          fontSize: 11.0,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                  // Hidden: do not render debug footer in UI
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 12.h),
            StatusAvatar(
              name: ProfileConfig.userName,
              imageAsset: ProfileConfig.userAvatarAsset,
              size: 52.h,
              status: PresenceStatus.none,
              showStatus: false,
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildTypingBubble() {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusAvatar(
              name: ProfileConfig.aiName,
              imageAsset: ProfileConfig.aiAvatarAsset,
              size: 52.h,
              status: PresenceStatus.online,
              showStatus: true,
            ),
            SizedBox(width: 12.h),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 12.h),
                decoration: BoxDecoration(
                  color: appTheme.whiteCustom,
                  borderRadius: BorderRadius.circular(16.h),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4.h,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: const _TypingDots(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.reselect?.removeListener(_onReselect);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

}

// Risk pill removed from UI; actionable chips remain.

class _CrisisChip extends StatelessWidget {
  const _CrisisChip({required this.name, required this.phone, this.textInstr = ''});
  final String name;
  final String phone; // may be empty when only text instructions exist (e.g., "HOME to 741741")
  final String textInstr;

  Future<void> _onTap(BuildContext context) async {
    final p = phone.trim();
    final t = textInstr.trim();
    if (p.isNotEmpty) {
      final tel = Uri(scheme: 'tel', path: p);
      try {
        final can = await canLaunchUrl(tel);
        if (can) {
          final ok = await launchUrl(tel, mode: LaunchMode.externalApplication);
          if (!ok) {
            // Fall back to copy
            await Clipboard.setData(ClipboardData(text: p));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Couldn\'t open dialer. Number copied to clipboard.')),
              );
            }
          }
        } else {
          await Clipboard.setData(ClipboardData(text: p));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Call not supported. Number copied to clipboard.')),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('tel: launch error: $e');
        await Clipboard.setData(ClipboardData(text: p));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Number copied to clipboard. Dial manually.')),
          );
        }
      }
      return;
    }
    if (t.isNotEmpty) {
      // Attempt to parse patterns like "HOME to 741741"
      String s = t;
      if (s.toLowerCase().startsWith('text ')) {
        s = s.substring(5).trim();
      }
      final reg = RegExp(r'^(.+?)\s+to\s+(\d+)$', caseSensitive: false);
      final m = reg.firstMatch(s);
      if (m != null) {
        final body = m.group(1)!.trim();
        final to = m.group(2)!.trim();
        final sms = Uri(scheme: 'sms', path: to, queryParameters: {'body': body});
        try {
          final can = await canLaunchUrl(sms);
          if (can) {
            final ok = await launchUrl(sms, mode: LaunchMode.externalApplication);
            if (!ok) {
              await Clipboard.setData(ClipboardData(text: t));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Couldn\'t open SMS. Instructions copied.')),
                );
              }
            }
          } else {
            await Clipboard.setData(ClipboardData(text: t));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SMS not supported. Instructions copied.')),
              );
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('sms: launch error: $e');
          await Clipboard.setData(ClipboardData(text: t));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Instructions copied to clipboard.')),
            );
          }
        }
      } else {
        await Clipboard.setData(ClipboardData(text: t));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Instructions copied to clipboard.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = name.trim().isNotEmpty;
    final hasPhone = phone.trim().isNotEmpty;
    final hasText = textInstr.trim().isNotEmpty;
    final label = () {
      if (hasName && hasPhone) return '$name · ${phone.trim()}';
      if (hasName && hasText) return '$name · ${textInstr.trim()}';
      if (hasPhone) return phone.trim();
      if (hasText) return textInstr.trim();
      if (hasName) return name.trim();
      return '';
    }();
    if (label.isEmpty) return const SizedBox.shrink();
    final semanticsLabel = () {
      if (hasPhone && hasName) return 'Call $name at ${phone.trim()}';
      if (hasPhone) return 'Call ${phone.trim()}';
      if (hasText && hasName) return '$name: ${textInstr.trim()}';
      if (hasText) return textInstr.trim();
      return label;
    }();
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTapHint: (hasPhone || hasText) ? 'Activate' : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (hasPhone || hasText) ? () => _onTap(context) : null,
        onLongPress: (hasPhone || hasText)
            ? () async {
                final toCopy = hasPhone ? phone.trim() : (hasText ? textInstr.trim() : name.trim());
                await Clipboard.setData(ClipboardData(text: toCopy));
                if (kDebugMode) debugPrint('Copied crisis info: $toCopy');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard.')),
                  );
                }
              }
            : null,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 44.h, minHeight: 36.h),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.h, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.blueGrey.shade200),
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade500;
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    if (reduceMotion) {
      if (_c.isAnimating) _c.stop();
      // Static dots for reduced motion
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 3.h),
            width: 8.h,
            height: 8.h,
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          );
        }),
      );
    }
    if (!_c.isAnimating) _c.repeat();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        double v(int i) {
          final t = (_c.value + (i * 0.2)) % 1.0;
          return (0.5 + 0.5 * math.sin(2 * math.pi * t)).clamp(0.0, 1.0);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 3.h),
              width: 8.h,
              height: 8.h,
              decoration: BoxDecoration(
                color: baseColor.withOpacity(v(i)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
