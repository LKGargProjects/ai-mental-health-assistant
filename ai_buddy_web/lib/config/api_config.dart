import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Get API URL from environment or use defaults
  static String get _apiUrl {
    // Check if we're in a web environment and can access window.location
    if (kIsWeb) {
      // Check if we're in production (not localhost)
      if (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
        final url = 'https://ai-mental-health-backend.onrender.com';
        return url;
      }

      // For local development, use relative URLs to work with nginx proxy
      // This allows the nginx container to proxy /api/ requests to the backend
      final url = '';
      return url;
    } else {
      // For mobile apps, always use production URL
      final url = 'https://ai-mental-health-backend.onrender.com';
      return url;
    }
  }

  // Get the appropriate URL based on environment
  static String get baseUrl => _apiUrl;

  // Helper method to get the current environment
  static String get environment {
    if (kIsWeb) {
      if (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') {
        return 'local';
      }
      return 'production';
    }
    return 'mobile';
  }

  // Helper method to check if we're in development
  static bool get isDevelopment => environment == 'local';

  // Helper method to check if we're in production
  static bool get isProduction => environment == 'production';

  // Debug information
  static Map<String, dynamic> get debugInfo => {
    'baseUrl': baseUrl,
    'environment': environment,
    'isWeb': kIsWeb,
    'isDevelopment': isDevelopment,
    'isProduction': isProduction,
  };
}
