import 'rtdb_event.dart';

Stream<RtdbEvent> openRtdbEventStream(Uri uri) =>
    Stream<RtdbEvent>.error(const RtdbStreamException('Streaming not supported'));
