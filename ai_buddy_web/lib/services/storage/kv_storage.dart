// Conditional export: default to web implementation, override on IO platforms.
export 'kv_storage_web.dart' if (dart.library.io) 'kv_storage_io.dart';
