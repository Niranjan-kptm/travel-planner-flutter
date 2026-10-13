import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rtdb_event.dart';

Stream<RtdbEvent> openRtdbEventStream(Uri uri) {
  http.Client? client;
  late StreamController<RtdbEvent> controller;
  controller = StreamController<RtdbEvent>(
    onListen: () async {
      client = http.Client();
      try {
        final req = http.Request('GET', uri)
          ..headers['Accept'] = 'text/event-stream'
          ..followRedirects = true;
        final res = await client!.send(req);
        if (res.statusCode != 200) {
          controller.addError(RtdbStreamException(
              'Live updates failed (HTTP ${res.statusCode})',
              statusCode: res.statusCode));
          await controller.close();
          return;
        }
        String? event;
        final data = StringBuffer();
        await for (final line in res.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (line.isEmpty) {
            if (event != null) controller.add(RtdbEvent(event, data.toString()));
            event = null;
            data.clear();
          } else if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            if (data.isNotEmpty) data.write('\n');
            data.write(line.substring(5).trim());
          }
        }
        if (!controller.isClosed) {
          controller.addError(const RtdbStreamException('Live update stream closed'));
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(RtdbStreamException('Live updates unavailable: $e'));
          await controller.close();
        }
      }
    },
    onCancel: () {
      client?.close();
    },
  );
  return controller.stream;
}
