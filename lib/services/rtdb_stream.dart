/// Opens a Realtime Database event stream with the best transport for the
/// platform: dart:io HTTP streaming on mobile/desktop, EventSource on the web.
export 'rtdb_stream_stub.dart'
    if (dart.library.io) 'rtdb_stream_io.dart'
    if (dart.library.html) 'rtdb_stream_web.dart';
