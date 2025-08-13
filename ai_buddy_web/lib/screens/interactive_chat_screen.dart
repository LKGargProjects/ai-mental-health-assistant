import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../core/utils/image_constant.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/dhiwise/custom_image_view.dart';
import '../core/utils/size_utils.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_back_button.dart';
import '../widgets/keyboard_dismissible_scaffold.dart';

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
  
  void _onReselect() {
    // On re-tap, bring the latest messages into view
    _scrollToBottom();
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
      body: Stack(
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
                          // Always show back button: if there's no history, it will at least dismiss the keyboard
                          return AppBackButton(isModal: isModal);
                        },
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                CustomImageView(
                                  imagePath: ImageConstant.imgImage66x66,
                                  height: 66.h,
                                  width: 66.h,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  bottom: 4.h,
                                  right: 4.h,
                                  child: Container(
                                    height: 12.h,
                                    width: 12.h,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: appTheme.whiteCustom,
                                        width: 2.h,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 12.h),
                            Text(
                              'Alex',
                              style: TextStyleHelper.instance.headline24Bold,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 32.h),
                    ],
                  ),
                ),
              ),
              // Divider
              Container(
                height: 8.h,
                color: appTheme.colorFFF3F4,
              ),
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
                  child: Row(
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
                      SizedBox(
                        width: 74.h,
                        child: Center(
                          child: GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: EdgeInsets.all(11.h),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 30.h,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, {bool isLast = false}) {
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
            CustomImageView(
              imagePath: ImageConstant.imgImage52x52,
              height: 52.h,
              width: 52.h,
              fit: BoxFit.cover,
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4.h,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 16.0, // iOS standard body text size
                  fontWeight: FontWeight.w400,
                  color: appTheme.colorFF1F29,
                  height: 1.4, // iOS standard line height
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 12.h),
            CustomImageView(
              imagePath: ImageConstant.imgImage52x52,
              height: 52.h,
              width: 52.h,
              fit: BoxFit.cover,
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
          CustomImageView(
            imagePath: ImageConstant.imgImage52x52,
            height: 52.h,
            width: 52.h,
            fit: BoxFit.cover,
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
                    color: Colors.black.withValues(alpha: 0.08),
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
              color: baseColor.withValues(alpha: 0.6),
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
                color: baseColor.withValues(alpha: v(i)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
