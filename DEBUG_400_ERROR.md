# Debug 400 Bad Request Error - Essential Files

## Problem Summary
Flutter web app is getting `400 Bad Request` on `POST /api/self_assessment` because it's trying to connect to `http://localhost:5055` instead of using relative URLs through nginx proxy.

## Key Files for Debugging

### 1. API Configuration (Critical)
**File:** `ai_buddy_web/lib/config/api_config.dart`
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Get API URL from environment or use defaults
  static String get _apiUrl {
    // Check if we're in a web environment and can access window.location
    if (kIsWeb) {
      // Check if we're in production (not localhost)
      if (Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1') {
        final url = 'https://ai-mental-health-assistant-tddc.onrender.com';
        print('🌐 API Config: Using production URL: $url');
        return url;
      }

      // For local development, use relative URLs to work with nginx proxy
      // This allows the nginx container to proxy /api/ requests to the backend
      final url = '';
      print('🌐 API Config: Using relative URL (empty string) for nginx proxy');
      print('🌐 API Config: Uri.base.host = ${Uri.base.host}');
      print('🌐 API Config: Uri.base = ${Uri.base}');
      return url;
    } else {
      // For mobile apps, always use production URL
      final url = 'https://ai-mental-health-assistant-tddc.onrender.com';
      print('🌐 API Config: Using mobile production URL: $url');
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
```

### 2. API Service (Critical)
**File:** `ai_buddy_web/lib/services/api_service.dart`
```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/message.dart';
import '../models/mood_entry.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      _storage = const FlutterSecureStorage() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Add comprehensive logging interceptor
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('🌐 DIO LOG: $obj'),
      ),
    );

    // Add error handling interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          print('🚨 === DIO ERROR DETAILS ===');
          print('Error Type: ${error.type}');
          print('Error Message: ${error.message}');
          print('Response Status: ${error.response?.statusCode}');
          print('Response Data: ${error.response?.data}');
          print('Request URL: ${error.requestOptions.uri}');
          print('Request Headers: ${error.requestOptions.headers}');
          print('Request Data: ${error.requestOptions.data}');
          print('Base URL: ${_dio.options.baseUrl}');
          handler.next(error);
        },
      ),
    );
  }

  /// Test backend connectivity and health
  Future<Map<String, dynamic>> testBackendHealth() async {
    try {
      print('🔍 Testing backend health at: ${_dio.options.baseUrl}');
      final response = await _dio.get('/api/health');
      print('✅ Backend health check passed: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      print('❌ Backend health check failed:');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Status: ${e.response?.statusCode}');
      print('   URL: ${e.requestOptions.uri}');

      String errorMessage = 'Backend connection failed. ';

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage +=
              'Backend server not responding. Is it running on port 5055?';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage += 'Server response timeout.';
          break;
        case DioExceptionType.badResponse:
          if (e.response?.statusCode == 505) {
            errorMessage +=
                'Server error 505: HTTP Version Not Supported. This might be a CORS or server configuration issue.';
          } else {
            errorMessage += 'Server error: ${e.response?.statusCode}';
          }
          break;
        case DioExceptionType.connectionError:
          errorMessage +=
              'Cannot connect to backend. Check if Flask server is running.';
          break;
        default:
          errorMessage += 'Unexpected error: ${e.message}';
      }

      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Unexpected error during health check: $e');
      throw Exception('Unexpected error: $e');
    }
  }
}
```

### 3. Self Assessment Widget (Critical)
**File:** `ai_buddy_web/lib/widgets/self_assessment_widget.dart`
```dart
// Key section for the 400 error
Future<void> _submitAssessment() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (widget.sessionId != null) 'X-Session-ID': widget.sessionId,
        },
      ),
    );

    // Add logging interceptor
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('🌐 SELF-ASSESSMENT LOG: $obj'),
      ),
    );

    // Build assessment data with proper null handling
    final Map<String, dynamic> assessmentData = {
      'mood': _selectedMood,
      'energy': _selectedEnergy,
      'sleep': _selectedSleep,
      'stress': _selectedStress,
      'notes': _notesController.text.trim(),
    };

    // Only add optional fields if they have valid values (not null or empty)
    if (_selectedCrisisLevel.isNotEmpty) {
      assessmentData['crisis_level'] = _selectedCrisisLevel;
    }

    if (_selectedAnxietyLevel.isNotEmpty) {
      assessmentData['anxiety_level'] = _selectedAnxietyLevel;
    }

    print('📤 Sending self-assessment data: $assessmentData');
    final response = await dio.post(
      '/api/self_assessment',
      data: assessmentData,
    );
    print('✅ Self-assessment response: ${response.data}');
  } catch (e) {
    print('❌ Self-assessment error: $e');
  }
}
```

### 4. Nginx Configuration (Critical)
**File:** `ai_buddy_web/nginx.conf`
```nginx
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com https://fonts.googleapis.com; worker-src 'self' blob:; child-src 'self' blob:; font-src 'self' https://fonts.gstatic.com https://www.gstatic.com; img-src 'self' data: blob: https:;" always;

        # Flutter web routing
        location / {
            try_files $uri $uri/ /index.html;
        }

        # API proxy to backend
        location /api/ {
            proxy_pass http://backend:5055;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }

        # Static files caching
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### 5. Backend Self Assessment Endpoint (Critical)
**File:** `app.py` (relevant section)
```python
@app.route('/api/self_assessment', methods=['POST', 'GET'])
def submit_self_assessment():
    try:
        # Handle GET request (for frontend compatibility)
        if request.method == 'GET':
            return jsonify({'message': 'Self assessment endpoint is available'}), 200

        # Handle POST request
        data = request.get_json()
        app.logger.info(f"📝 Self assessment data received: {data}")

        if not data or not isinstance(data, dict):
            app.logger.error(f"❌ Invalid data format: {data}")
            return jsonify({'error': 'Invalid or missing JSON data'}), 400

        # Retrieve session_id from header or session
        session_id = request.headers.get('X-Session-ID') or session.get('session_id')
        if not session_id:
            app.logger.error("❌ No session ID provided")
            return jsonify({'error': 'Session ID is required'}), 400

        # Clean and validate the data
        cleaned_data = {}
        required_fields = ['mood', 'energy', 'sleep', 'stress', 'notes']
        optional_fields = ['crisis_level', 'anxiety_level']

        # Validate required fields
        for field in required_fields:
            if field not in data:
                app.logger.error(f"❌ Missing required field: {field}")
                return jsonify({'error': f'Missing required field: {field}'}), 400

            value = data[field]
            if value is None or (isinstance(value, str) and value.strip() == ''):
                app.logger.error(f"❌ Required field {field} is empty or null")
                return jsonify({'error': f'Required field {field} cannot be empty'}), 400

            cleaned_data[field] = value.strip() if isinstance(value, str) else value

        # Handle optional fields - only include if they have valid values
        for field in optional_fields:
            if field in data:
                value = data[field]
                # Only include if value is not None, not empty string, and not "null" string
                if value is not None and value != "" and value != "null" and value != "None":
                    cleaned_data[field] = value.strip() if isinstance(value, str) else value

        app.logger.info(f"✅ Cleaned assessment data: {cleaned_data}")

        # For now, just return success without database operations
        return jsonify({
            'success': True,
            'message': 'Assessment received successfully',
            'data': cleaned_data,
            'session_id': session_id
        }), 201
    except Exception as e:
        app.logger.error(f"❌ Self assessment error: {str(e)}")
        return jsonify({'error': str(e)}), 500
```

### 6. Docker Compose (Critical)
**File:** `docker-compose.yml`
```yaml
version: '3.8'

services:
  backend:
    build: .
    ports:
      - "5055:5055"
    environment:
      - PORT=5055
      - DATABASE_URL=postgresql+psycopg://ai_buddy:ai_buddy_password@db:5432/mental_health
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    networks:
      - app-network

  db:
    image: postgres:14
    environment:
      - POSTGRES_DB=mental_health
      - POSTGRES_USER=ai_buddy
      - POSTGRES_PASSWORD=ai_buddy_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - app-network

  flutter-web:
    build:
      context: ./ai_buddy_web
      dockerfile: Dockerfile.web
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

## Current Issue
The Flutter app is still trying to connect to `http://localhost:5055` instead of using relative URLs. The console shows:
- `Base URL: http://localhost:5055`
- `Request URL: http://localhost:5055/api/self_assessment`

## Expected Behavior
The Flutter app should:
- Use `Base URL: ` (empty string)
- Make requests to `/api/self_assessment` (relative URL)
- Let nginx proxy handle the routing to `http://backend:5055/api/self_assessment`

## Debug Steps
1. Check if the updated `ApiConfig.baseUrl` is being used
2. Verify the Docker container is serving the updated build
3. Clear browser cache and hard refresh
4. Check browser console for the debug messages from `ApiConfig` 