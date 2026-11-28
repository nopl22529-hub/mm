import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/domain/auth/models/create_comment_params.dart';

void main() {
  group('encodeCreateCommentParams', () {
    test('matches the reference protobuf encoding', () {
      // CreateCommentParams { video_id: 'dQw4w9WgXcQ',
      // params: { index: 0 }, number: 7 }, base64 + URI-encoded.
      expect(
        encodeCreateCommentParams('dQw4w9WgXcQ'),
        'EgtkUXc0dzlXZ1hjUSoCCABQBw%3D%3D',
      );
      expect(encodeCreateCommentParams('abc123'), 'EgZhYmMxMjMqAggAUAc%3D');
    });
  });
}
