class SseHandle {
  final Stream<Map<String, dynamic>> stream;
  final void Function() close;
  SseHandle({required this.stream, required this.close});
}

// Non-web stub: no SSE support
SseHandle connectSse({
  required String url,
  required Map<String, String> query,
}) {
  final controller = Stream<Map<String, dynamic>>.empty();
  void closer() {}
  return SseHandle(stream: controller, close: closer);
}
