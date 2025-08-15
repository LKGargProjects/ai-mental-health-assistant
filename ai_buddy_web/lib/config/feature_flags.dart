class FeatureFlags {
  // Gate streaming behind a flag. Toggle to enable/disable.
  static const bool enableStreaming = true;

  // Future: support other streaming transports (e.g., websockets)
  static const String streamingTransport = 'sse'; // 'sse'
}
