import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/crisis_resources.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Column(
          children: [
            if (chatProvider.error != null)
              Container(
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatProvider.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: chatProvider.clearError,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: chatProvider.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chatProvider.currentMode.icon,
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          chatProvider.currentMode.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatProvider.messages[index];
                      return Column(
                        children: [
                          ChatMessage(message: message),
                          if (message.hasResources)
                            CrisisResources(resources: message.resources!),
                        ],
                      );
                    },
                  ),
            ),
            if (chatProvider.isLoading) const TypingIndicator(),
            const ChatInput(),
          ],
        );
      },
    );
  }
} 