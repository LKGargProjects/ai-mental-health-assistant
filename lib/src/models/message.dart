class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? riskLevel;
  final List<Map<String, String>>? resources;

  const Message({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.riskLevel,
    this.resources,
  });

  bool get isCritical => riskLevel == 'critical';
  bool get isHigh => riskLevel == 'high';
  bool get hasResources => resources != null && resources!.isNotEmpty;

  @override
  String toString() {
    return 'Message{content: $content, isUser: $isUser, timestamp: $timestamp, riskLevel: $riskLevel}';
  }
} 