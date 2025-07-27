import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';

class ChatMessage extends StatelessWidget {
  final Message message;

  const ChatMessage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Card(
          color: _getMessageColor(colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: message.content,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                if (!message.isUser) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${DateTime.now().difference(message.timestamp).inSeconds} seconds ago',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: message.isUser
                          ? Colors.white70
                          : theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getMessageColor(ColorScheme colorScheme) {
    if (message.isUser) {
      return colorScheme.primary;
    }
    if (message.isCritical) {
      return colorScheme.errorContainer;
    }
    if (message.isHigh) {
      return colorScheme.surfaceContainerHighest;
    }
    return colorScheme.surface;
  }
} 