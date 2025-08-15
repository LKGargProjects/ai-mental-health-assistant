import 'package:flutter/material.dart';
import 'status_avatar.dart';
import '../config/profile_config.dart';

class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    super.key,
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            StatusAvatar(
              name: ProfileConfig.aiName,
              imageAsset: ProfileConfig.aiAvatarAsset,
              size: 40,
              status: PresenceStatus.online,
            ),
            const SizedBox(width: 8.0),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(text),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8.0),
            StatusAvatar(
              name: ProfileConfig.userName,
              imageAsset: ProfileConfig.userAvatarAsset,
              size: 40,
              status: PresenceStatus.none,
              showStatus: false,
            ),
          ],
        ],
      ),
    );
  }
}