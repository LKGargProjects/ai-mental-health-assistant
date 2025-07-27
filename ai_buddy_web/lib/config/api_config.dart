import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development
  static const String localUrl = 'http://127.0.0.1:5050';

  // Production (Render)
  static const String productionUrl =
      'https://ai-mental-health-assistant.onrender.com';

  // Get the appropriate URL based on environment
  static String get baseUrl {
    // For mobile apps, always use production URL
    if (!kIsWeb) {
      return productionUrl;
    }

    // For web, check if we're in production
    if (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
      return productionUrl;
    }
    return localUrl;
  }
}
