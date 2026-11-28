import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/domain/auth/models/device_code_response.dart';
import 'package:fluxtube/domain/auth/models/youtube_account.dart';

void main() {
  group('DeviceCodeResponse', () {
    test('parses Google device code response', () {
      final code = DeviceCodeResponse.fromJson({
        'device_code': 'device-123',
        'user_code': 'ABCD-EFGH',
        'verification_url': 'https://www.youtube.com/activate',
        'expires_in': 1800,
        'interval': 5,
      });
      expect(code.deviceCode, 'device-123');
      expect(code.userCode, 'ABCD-EFGH');
      expect(code.verificationUrl, 'https://www.youtube.com/activate');
      expect(code.expiresIn, 1800);
      expect(code.interval, 5);
    });

    test('falls back to youtube.com/activate when URL is missing', () {
      final code = DeviceCodeResponse.fromJson({
        'device_code': 'device-123',
        'user_code': 'ABCD-EFGH',
      });
      expect(code.verificationUrl, 'https://www.youtube.com/activate');
      expect(code.interval, 5);
    });
  });

  group('YoutubeAccount', () {
    test('parses a channels.list item', () {
      final account = YoutubeAccount.fromChannelItem({
        'id': 'UC123',
        'snippet': {
          'title': 'Mena Channel',
          'customUrl': '@mena',
          'thumbnails': {
            'default': {'url': 'https://example.com/avatar.jpg'},
          },
        },
      });
      expect(account.channelId, 'UC123');
      expect(account.title, 'Mena Channel');
      expect(account.handle, '@mena');
      expect(account.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('parses an Innertube accounts_list response', () {
      final account = YoutubeAccount.fromAccountsListResponse({
        'contents': {
          'accountSectionListRenderer': {
            'contents': [
              {
                'accountItemSectionRenderer': {
                  'contents': [
                    {
                      'accountItemRenderer': {
                        'accountName': {'simpleText': 'Mena Channel'},
                        'channelHandle': {
                          'runs': [
                            {'text': '@mena'},
                          ],
                        },
                        'accountPhoto': {
                          'thumbnails': [
                            {'url': 'https://example.com/small.jpg'},
                            {'url': 'https://example.com/large.jpg'},
                          ],
                        },
                        'serviceEndpoint': {
                          'browseEndpoint': {'browseId': 'UC123'},
                        },
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
      });
      expect(account?.channelId, 'UC123');
      expect(account?.title, 'Mena Channel');
      expect(account?.handle, '@mena');
      expect(account?.avatarUrl, 'https://example.com/large.jpg');
    });

    test('round-trips through JSON for secure-storage caching', () {
      const account = YoutubeAccount(
        channelId: 'UC123',
        title: 'Mena Channel',
        handle: '@mena',
        avatarUrl: 'https://example.com/avatar.jpg',
      );
      expect(YoutubeAccount.fromJson(account.toJson()), account);
    });
  });
}
