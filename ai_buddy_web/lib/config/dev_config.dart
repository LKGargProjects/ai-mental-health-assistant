// =============================================================================
// DEVELOPMENT CONFIGURATION
// =============================================================================
// This file contains development-specific configurations

class DevConfig {
  // Development API URL
  static const String devApiUrl = 'http://localhost:5050';

  // Development web port
  static const int devWebPort = 8080;

  // Debug settings
  static const bool enableDebugLogging = true;
  static const bool enableDioLogging = true;

  // Development features
  static const bool enableHotReload = true;
  static const bool enableDevTools = true;

  // Mock data for development
  static const bool useMockData = false;

  // Development timeout settings
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Development CORS settings
  static const List<String> allowedOrigins = [
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ];
}
