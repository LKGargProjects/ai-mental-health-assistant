import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value storage using FlutterSecureStorage for IO platforms (Android/iOS/macOS/Windows/Linux)
class KvStorage {
  static const FlutterSecureStorage _s = FlutterSecureStorage();

  static Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String? value) async {
    try {
      await _s.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } catch (_) {}
  }
}
