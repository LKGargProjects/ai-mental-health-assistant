import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StartupScreen extends StatefulWidget {
  final VoidCallback onBackendReady;

  const StartupScreen({super.key, required this.onBackendReady});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _isBackendHealthy = false;
  bool _isChecking = true;
  String _healthStatus = 'Checking backend connection...';
  String _errorDetails = '';

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    try {
      setState(() {
        _isChecking = true;
        _healthStatus = 'Testing backend connectivity...';
        _errorDetails = '';
      });

      final apiService = ApiService();
      final healthData = await apiService.testBackendHealth();

      setState(() {
        _isBackendHealthy = true;
        _isChecking = false;
        _healthStatus = '✅ Backend connected successfully!';
        _errorDetails =
            'Port: ${healthData['port']}, Provider: ${healthData['provider']}';
      });

      // Navigate to main app after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        widget.onBackendReady();
      });
    } catch (e) {
      setState(() {
        _isBackendHealthy = false;
        _isChecking = false;
        _healthStatus = '❌ Backend connection failed';
        _errorDetails = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon/Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.psychology,
                  size: 60,
                  color: Colors.blue[700],
                ),
              ),

              const SizedBox(height: 32),

              // App Title
              Text(
                'GentleQuest',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Your AI companion for mental wellness',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Status Icon
                    _isChecking
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            _isBackendHealthy
                                ? Icons.check_circle
                                : Icons.error,
                            color: _isBackendHealthy
                                ? Colors.green
                                : Colors.red,
                            size: 40,
                          ),

                    const SizedBox(height: 16),

                    // Status Text
                    Text(
                      _healthStatus,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _isBackendHealthy
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (_errorDetails.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorDetails,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    if (!_isBackendHealthy && !_isChecking) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _checkBackendHealth,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Instructions
              if (!_isBackendHealthy && !_isChecking)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Troubleshooting',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Ensure Flask backend is running on port 5055\n'
                        '2. Check if no other service is using the port\n'
                        '3. Verify CORS is properly configured\n'
                        '4. Try refreshing the page',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
