import 'package:flutter/material.dart';

/// Centralized config for participant profiles and avatar assets.
/// Update names/images here to change across the app.
class ProfileConfig {
  ProfileConfig._();

  // AI assistant
  static String aiName = 'Alex';
  // Default asset path for AI avatar. Replace with your own asset (no badge baked-in) as needed.
  static String? aiAvatarAsset = 'assets/images/avatar_placeholder.png'; // e.g. 'assets/images/avatar_ai.png'

  // Current user
  static String userName = 'You';
  static String? userAvatarAsset; // e.g. 'assets/images/avatar_user.png'

  // Colors for status
  static const Color online = Color(0xFF22C55E);    // green-500
  static const Color idle = Color(0xFFF59E0B);      // amber-500
  static const Color offline = Color(0xFF9CA3AF);   // gray-400
}

/// High-level presence for status badge.
enum PresenceStatus { online, idle, offline, none }

extension PresenceColor on PresenceStatus {
  Color color() {
    switch (this) {
      case PresenceStatus.online:
        return ProfileConfig.online;
      case PresenceStatus.idle:
        return ProfileConfig.idle;
      case PresenceStatus.offline:
        return ProfileConfig.offline;
      case PresenceStatus.none:
        return Colors.transparent;
    }
  }
}
