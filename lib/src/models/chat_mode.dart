enum ChatMode {
  mentalHealth,
  academic;

  String get displayName {
    switch (this) {
      case ChatMode.mentalHealth:
        return 'Mental Health Support';
      case ChatMode.academic:
        return 'Academic Help';
    }
  }

  String get description {
    switch (this) {
      case ChatMode.mentalHealth:
        return 'Talk about your feelings, get emotional support, and learn coping strategies';
      case ChatMode.academic:
        return 'Get help with homework, understand concepts, and improve your study skills';
    }
  }

  String get icon {
    switch (this) {
      case ChatMode.mentalHealth:
        return '❤️';
      case ChatMode.academic:
        return '📚';
    }
  }
} 