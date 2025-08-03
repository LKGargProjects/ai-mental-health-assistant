import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import 'crisis_resources.dart';

class ChatMessageWidget extends StatelessWidget {
  final Message message;

  const ChatMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser) _buildAvatar(context),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.getMessageColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: message.getTextColor(context)),
                      a: TextStyle(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (message.isUser) _buildAvatar(context),
            ],
          ),
          // Show crisis widget for high-risk messages
          if (!message.isUser && message.riskLevel == RiskLevel.high)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: CrisisResourcesWidget(
                riskLevel: message.riskLevel,
                crisisMsg: message.crisisMsg,
                crisisNumbers: message.crisisNumbers,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      backgroundColor: message.isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Text(
        message.isUser ? '👤' : '🤖',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
