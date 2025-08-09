import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../core/utils/image_constant.dart';
import '../theme/theme_helper.dart';
import '../theme/text_style_helper.dart';
import '../widgets/dhiwise/custom_image_view.dart';
import '../core/utils/size_utils.dart';
import '../widgets/app_bottom_nav.dart';

class InteractiveChatScreen extends StatefulWidget {
  const InteractiveChatScreen({super.key});

  @override
  State<InteractiveChatScreen> createState() => _InteractiveChatScreenState();
}

class _InteractiveChatScreenState extends State<InteractiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with some sample messages if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.messages.isEmpty) {
        _addSampleMessages(chatProvider);
      }
    });
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

    // Send to backend - this will add both user and AI messages
    try {
      await chatProvider.sendMessage(messageText);
      _scrollToBottom();
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      body: Stack(
        children: [
          // Background Image
          CustomImageView(
            imagePath: ImageConstant.imgBackground1440x635,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
          ),
          // Main Content
          Column(
            children: [
              // Header
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 16.h),
                child: SafeArea(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.h),
                          child: CustomImageView(
                            imagePath: ImageConstant.imgImage,
                            height: 24.h,
                            width: 16.h,
                          ),
                        ),
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
                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16.h),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];
                        return _buildMessageBubble(message);
                      },
                    );
                  },
                ),
              ),
              // Input Area
              Container(
                color: appTheme.whiteCustom,
                padding: EdgeInsets.all(16.h),
                child: SafeArea(
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
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: TextStyle(
                                fontSize: 16.0, // iOS standard input text size
                                color: Colors.grey[600],
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.h,
                                vertical: 12.h,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16.0, // iOS standard input text size
                              color: Colors.black87,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.send,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            minLines: 1,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.h),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: EdgeInsets.all(12.h),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20.h,
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
      // Bottom Navigation (shared)
      bottomNavigationBar: const AppBottomNav(current: AppTab.talk),
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
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
                    color: Colors.black.withOpacity(0.1),
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
