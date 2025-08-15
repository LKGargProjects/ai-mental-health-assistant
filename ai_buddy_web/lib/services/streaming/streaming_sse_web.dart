import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class SseHandle {
  final Stream<Map<String, dynamic>> stream;
  final void Function() close;
  SseHandle({required this.stream, required this.close});
}

SseHandle connectSse({
  required String url,
  required Map<String, String> query,
}) {
  final uri = Uri.parse(url).replace(queryParameters: query);

  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final es = html.EventSource(uri.toString());

  void onMessage(html.MessageEvent e) {
    try {
      final data = e.data is String ? e.data as String : e.data.toString();
      if (data.trim().isEmpty) return;
      final decoded = json.decode(data) as Map<String, dynamic>;
      controller.add(decoded);
    } catch (_) {
      // ignore malformed chunks
    }
  }

  void onError(html.Event _) {
    if (!controller.isClosed) {
      controller.add({'type': 'error', 'message': 'stream_error'});
      controller.close();
    }
    es.close();
  }

  es.onMessage.listen(onMessage);
  es.onError.listen(onError);

  void close() {
    es.close();
    if (!controller.isClosed) controller.close();
  }

  return SseHandle(stream: controller.stream, close: close);
}
