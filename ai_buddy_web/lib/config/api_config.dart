class ApiConfig {
  // Development
  static const String localUrl = 'http://localhost:5058';
  
  // Production (Render) - Update this with your actual Render URL
  static const String productionUrl = 'https://ai-mental-health-api.onrender.com';
  
  // Get the appropriate URL based on environment
  static String get baseUrl {
    // Check if we're in production (web deployment)
    if (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
      return productionUrl;
    }
    return localUrl;
  }
} 