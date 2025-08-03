import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development - use local backend for testing
  static const String localUrl = 'http://localhost:5055';

  // Production (Render)
  static const String productionUrl =
      'https://ai-mental-health-assistant-tddc.onrender.com';

  // Get the appropriate URL based on environment
  static String get baseUrl {
    // For mobile apps, always use production URL
    if (!kIsWeb) {
      return productionUrl;
    }

    // For web, use production URL for deployment
    // This ensures consistent behavior across environments
    return productionUrl;
  }
}
