import 'dart:convert';

/// Encodes the `createCommentParams` protobuf that YouTube's
/// `comment/create_comment` endpoint expects, the same way
/// YouTube.js builds it:
///
/// ```
/// message CreateCommentParams {
///   string video_id = 2;
///   message Params { int32 index = 1; }
///   Params params = 5;   // index: 0
///   int32 number = 10;   // 7
/// }
/// ```
///
/// The bytes are base64-encoded and URI-component-encoded, matching
/// the reference implementation.
String encodeCreateCommentParams(String videoId) {
  final videoIdBytes = utf8.encode(videoId);
  final bytes = <int>[
    // field 2 (video_id), length-delimited
    0x12, ..._varint(videoIdBytes.length), ...videoIdBytes,
    // field 5 (params), length-delimited submessage { field 1: 0 }
    0x2A, 0x02, 0x08, 0x00,
    // field 10 (number), varint 7
    0x50, 0x07,
  ];
  return Uri.encodeComponent(base64Encode(bytes));
}

List<int> _varint(int value) {
  final out = <int>[];
  var v = value;
  while (true) {
    final byte = v & 0x7F;
    v >>= 7;
    if (v == 0) {
      out.add(byte);
      break;
    }
    out.add(byte | 0x80);
  }
  return out;
}
