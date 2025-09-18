// Platform router for NotificationService
// - On non-web (dart:io present), use the real implementation that imports
//   flutter_local_notifications.
// - On web, use a no-op stub so web builds don't pull in non-web plugins.

export 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_impl.dart';
