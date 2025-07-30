import 'dart:io';
import 'package:flutter/foundation.dart';

/// Optimized API configuration for single codebase usage across development, Docker, and Render production
class ApiConfig {
  // Get API URL from environment or use defaults
  static String get _apiUrl {
    // Check if we're in a web environment and can access window.location
    if (kIsWeb) {
      final host = Uri.base.host;
      final port = Uri.base.port;

      // Development environments
      if (host == 'localhost' || host == '127.0.0.1') {
        // Docker environment (nginx proxy on port 8080)
        if (port == 8080) {
          return ''; // Use relative URLs for nginx proxy
        }
        // Direct backend connection (port 3000 or other)
        if (port == 3000) {
          return 'http://localhost:5055';
        }
        // Fallback for other local ports
        return 'http://localhost:5055';
      }

      // Production environment (not localhost)
      return 'https://ai-mental-health-backend.onrender.com';
    } else {
      // For mobile apps, always use production URL
      return 'https://ai-mental-health-backend.onrender.com';
    }
  }

  // Get the appropriate URL based on environment
  static String get baseUrl => _apiUrl;

  // Helper method to get the current environment
  static String get environment {
    if (kIsWeb) {
      final host = Uri.base.host;
      final port = Uri.base.port;

      if (host == 'localhost' || host == '127.0.0.1') {
        if (port == 8080) {
          return 'docker'; // Docker environment
        }
        return 'development'; // Local development
      }
      return 'production';
    }
    return 'mobile';
  }

  // Helper method to check if we're in development
  static bool get isDevelopment =>
      environment == 'development' || environment == 'docker';

  // Helper method to check if we're in production
  static bool get isProduction => environment == 'production';

  // Helper method to check if we're in Docker
  static bool get isDocker => environment == 'docker';

  // Helper method to check if we're in mobile
  static bool get isMobile => environment == 'mobile';

  // Get connection timeout based on environment
  static Duration get connectionTimeout {
    if (isDevelopment) {
      return const Duration(seconds: 30); // Longer timeout for development
    }
    return const Duration(seconds: 10); // Standard timeout for production
  }

  // Get retry attempts based on environment
  static int get maxRetries {
    if (isDevelopment) {
      return 5; // More retries for development
    }
    return 3; // Standard retries for production
  }

  // Get logging level based on environment
  static bool get enableDetailedLogging => isDevelopment;

  // Debug information with enhanced details
  static Map<String, dynamic> get debugInfo => {
    'baseUrl': baseUrl,
    'environment': environment,
    'isWeb': kIsWeb,
    'isDevelopment': isDevelopment,
    'isProduction': isProduction,
    'isDocker': isDocker,
    'isMobile': isMobile,
    'connectionTimeout': connectionTimeout.inSeconds,
    'maxRetries': maxRetries,
    'enableDetailedLogging': enableDetailedLogging,
    'uri': {
      'host': kIsWeb ? Uri.base.host : 'mobile',
      'port': kIsWeb ? Uri.base.port : null,
      'scheme': kIsWeb ? Uri.base.scheme : 'https',
    },
  };

  /// Validate API configuration
  static bool get isValid {
    if (kIsWeb) {
      final host = Uri.base.host;
      return host.isNotEmpty;
    }
    return true; // Mobile is always valid
  }

  /// Get error message for invalid configuration
  static String? get validationError {
    if (!isValid) {
      return 'Invalid API configuration detected';
    }
    return null;
  }
}
