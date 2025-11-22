import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'firebase_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;

  Future<void> initialize() async {
    _appLinks = AppLinks();

    // Handle initial link if app was launched from a deep link
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }

    // Listen for links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri.toString());
    });
  }

  void _handleDeepLink(String link) {
    debugPrint('Deep link received: $link');
    FirebaseService().logEvent('deep_link_opened', {'url': link});

    final uri = Uri.parse(link);
    final path = uri.path;
    final queryParams = uri.queryParameters;

    // Route to appropriate screen based on path
    switch (path) {
      case '/chat':
        _navigateTo(AppRoutes.interactiveChat, queryParams);
        break;
      case '/mood':
        _navigateTo(AppRoutes.moodTracker, queryParams);
        break;
      case '/quest':
        _navigateTo(AppRoutes.questScreen, queryParams);
        break;
      case '/wellness':
        _navigateTo(AppRoutes.wellnessDashboard, queryParams);
        break;
      case '/crisis':
        _navigateTo(AppRoutes.crisisResources, queryParams);
        break;
      case '/assessment':
        if (queryParams.containsKey('id')) {
          _navigateTo(AppRoutes.assessment, queryParams);
        }
        break;
      case '/share':
        // Handle shared content
        _handleSharedContent(queryParams);
        break;
      default:
        // Default to home
        _navigateTo(AppRoutes.home, queryParams);
    }
  }

  void _navigateTo(String route, Map<String, String> params) {
    // Get the current context from your navigation key
    final context = AppRoutes.navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushNamed(route, arguments: params);
    }
  }

  void _handleSharedContent(Map<String, String> params) {
    // Handle content shared to the app
    final type = params['type'];
    final content = params['content'];

    if (type == 'mood' && content != null) {
      // Navigate to mood tracker with pre-filled mood
      _navigateTo(AppRoutes.moodTracker, {'preset': content});
    } else if (type == 'crisis') {
      // Navigate directly to crisis resources
      _navigateTo(AppRoutes.crisisResources, {});
    }

    FirebaseService().logEvent('content_shared', {
      'type': type ?? 'unknown',
      'has_content': content != null,
    });
  }

  // Generate shareable links
  static String generateShareLink(String path, [Map<String, String>? params]) {
    const baseUrl = 'https://gentlequest.app';
    final uri = Uri.parse('$baseUrl$path');

    if (params != null && params.isNotEmpty) {
      return uri.replace(queryParameters: params).toString();
    }

    return uri.toString();
  }
}
