import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development - use production API for consistency
  static const String localUrl = 'https://ai-mental-health-assistant-tddc.onrender.com';

  // Production (Render)
  static const String productionUrl =
      'https://ai-mental-health-assistant-tddc.onrender.com';

  // Get the appropriate URL based on environment
  static String get baseUrl {
    // For mobile apps, always use production URL
    if (!kIsWeb) {
      return productionUrl;
    }

    // For web, always use production URL for consistency
    // This eliminates local container issues and follows our rules
    return productionUrl;
  }
}
