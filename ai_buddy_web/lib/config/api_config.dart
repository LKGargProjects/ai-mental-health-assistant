import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development - use local backend for testing
  static const String localUrl = 'http://localhost:5055';

  // Production (Render)
  static const String productionUrl =
      'https://gentlequest.onrender.com';

  // Get the appropriate URL based on environment
  static String get baseUrl {
    // Mobile/native -> production URL
    if (!kIsWeb) {
      if (kDebugMode) {
        debugPrint('🔧 DEBUG: Mobile/native detected, using production URL');
      }
      return productionUrl;
    }

    // Web debug -> local backend
    if (kDebugMode) {
      debugPrint('🔧 DEBUG: Web debug detected, using local URL');
      return localUrl;
    }

    // Web release -> same-origin (served by Nginx), avoids CORS
    final origin = Uri.base.origin;
    return origin;
  }
}
