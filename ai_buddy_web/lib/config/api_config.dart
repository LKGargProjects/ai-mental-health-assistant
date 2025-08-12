import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development - use local backend for testing
  static const String localUrl = 'http://localhost:5050';

  // Production (Render)
  static const String productionUrl =
      'https://ai-mental-health-assistant-tddc.onrender.com';

  // Get the appropriate URL based on environment
  static String get baseUrl {
    // For mobile apps, always use production URL
    if (!kIsWeb) {
      print('🔧 DEBUG: Mobile platform detected, using production URL');
      return productionUrl;
    }

    // For web in debug mode, use local URL
    if (kDebugMode) {
      print('🔧 DEBUG: Web debug mode detected, using local URL');
      return localUrl;
    }

    // For web in release mode, use production URL
    print('🔧 DEBUG: Web release mode detected, using production URL');
    return productionUrl;
  }
}
