import 'package:flutter/material.dart';

enum MessageType { text, error, system }
enum RiskLevel { none, low, medium, high }

class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;
  final RiskLevel riskLevel;
  final List<String>? resources;

  Message({
    String? id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.riskLevel = RiskLevel.none,
    this.resources,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String?,
      content: json['content'] as String,
      isUser: json['is_user'] as bool,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString() == 'RiskLevel.${json['risk_level'] ?? 'none'}',
        orElse: () => RiskLevel.none,
      ),
      resources: (json['resources'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'risk_level': riskLevel.toString().split('.').last,
      'resources': resources,
    };
  }

  Color getMessageColor(BuildContext context) {
    if (type == MessageType.error) {
      return Theme.of(context).colorScheme.error;
    }
    if (type == MessageType.system) {
      return Theme.of(context).colorScheme.surfaceVariant;
    }
    return isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondaryContainer;
  }

  Color getTextColor(BuildContext context) {
    if (type == MessageType.error) {
      return Theme.of(context).colorScheme.onError;
    }
    if (type == MessageType.system) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSecondaryContainer;
  }
} 