import 'package:flutter/foundation.dart';
import 'dart:html' as html;

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

    // For web, detect environment automatically
    try {
      // Check if we're running on localhost (development)
      final hostname = html.window.location.hostname;
      final port = html.window.location.port;
      final protocol = html.window.location.protocol;
      
      // If running on localhost (any port), use local backend
      if (hostname == 'localhost' || hostname == '127.0.0.1') {
        print('🔧 DEBUG: Detected local development environment');
        print('🔧 DEBUG: Hostname: $hostname, Port: $port, Protocol: $protocol');
        return localUrl;
      }
      
      // Otherwise, use production URL
      print('🔧 DEBUG: Detected production environment');
      print('🔧 DEBUG: Hostname: $hostname, Port: $port, Protocol: $protocol');
      return productionUrl;
    } catch (e) {
      // Fallback to production URL if detection fails
      print('🔧 DEBUG: Environment detection failed, using production URL');
      print('🔧 DEBUG: Error: $e');
      return productionUrl;
    }
  }
}
