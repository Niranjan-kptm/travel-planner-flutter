// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'rtdb_event.dart';

/// Uses the browser's native EventSource, which the Firebase REST streaming
/// API supports directly (including its redirects).
Stream<RtdbEvent> openRtdbEventStream(Uri uri) {
  html.EventSource? source;
  late StreamController<RtdbEvent> controller;
  void forward(String name, html.Event e) {
    if (e is html.MessageEvent) {
      controller.add(RtdbEvent(name, '${e.data}'));
    }
  }

  controller = StreamController<RtdbEvent>(
    onListen: () {
      final s = html.EventSource(uri.toString());
      source = s;
      for (final name in const ['put', 'patch', 'keep-alive', 'cancel', 'auth_revoked']) {
        s.addEventListener(name, (e) => forward(name, e));
      }
      s.onError.listen((_) {
        // Stop the browser's automatic reconnect; the repository reconnects
        // itself with a fresh auth token and back-off.
        s.close();
        if (!controller.isClosed) {
          controller.addError(const RtdbStreamException('Live update connection lost'));
          controller.close();
        }
      });
    },
    onCancel: () {
      source?.close();
    },
  );
  return controller.stream;
}
