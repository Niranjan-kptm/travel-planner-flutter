/// One Server-Sent Event from the Realtime Database REST streaming API.
/// See https://firebase.google.com/docs/reference/rest/database#section-streaming
class RtdbEvent {
  final String event; // put, patch, keep-alive, cancel, auth_revoked
  final String data; // JSON text
  const RtdbEvent(this.event, this.data);
}

class RtdbStreamException implements Exception {
  final String message;
  final int? statusCode;
  const RtdbStreamException(this.message, {this.statusCode});
  @override
  String toString() => message;
}
