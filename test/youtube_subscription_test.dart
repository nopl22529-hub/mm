import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/domain/auth/models/youtube_subscription.dart';

void main() {
  group('YoutubeSubscription', () {
    test('parses FEchannels browse response', () {
      final subs = YoutubeSubscription.fromChannelsFeedResponse({
        'contents': {
          'twoColumnBrowseResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        {
                          'itemSectionRenderer': {
                            'contents': [
                              {
                                'shelfRenderer': {
                                  'content': {
                                    'expandedShelfContentsRenderer': {
                                      'items': [
                                        {
                                          'channelRenderer': {
                                            'channelId': 'UCabc123',
                                            'title': {
                                              'simpleText': 'Channel A',
                                            },
                                            'thumbnail': {
                                              'thumbnails': [
                                                {'url': '//yt3.example/a.jpg'},
                                              ],
                                            },
                                          },
                                        },
                                        {
                                          'gridChannelRenderer': {
                                            'channelId': 'UCdef456',
                                            'title': {
                                              'runs': [
                                                {'text': 'Channel '},
                                                {'text': 'B'},
                                              ],
                                            },
                                          },
                                        },
                                      ],
                                    },
                                  },
                                },
                              },
                            ],
                          },
                        },
                      ],
                    },
                  },
                },
              },
            ],
          },
        },
      });

      expect(subs.length, 2);
      expect(subs[0].channelId, 'UCabc123');
      expect(subs[0].title, 'Channel A');
      expect(subs[0].avatarUrl, 'https://yt3.example/a.jpg');
      expect(subs[1].channelId, 'UCdef456');
      expect(subs[1].title, 'Channel B');
    });

    test('parses guide response', () {
      final subs = YoutubeSubscription.fromGuideResponse({
        'items': [
          {
            'guideSubscriptionsSectionRenderer': {
              'items': [
                {
                  'guideEntryRenderer': {
                    'formattedTitle': {'simpleText': 'Channel A'},
                    'navigationEndpoint': {
                      'browseEndpoint': {'browseId': 'UCabc123'},
                    },
                    'thumbnail': {
                      'thumbnails': [
                        {'url': 'https://yt3.example/a.jpg'},
                      ],
                    },
                  },
                },
                {
                  'guideEntryRenderer': {
                    'formattedTitle': {'simpleText': 'Browse channels'},
                    'navigationEndpoint': {
                      'browseEndpoint': {'browseId': 'FEchannels'},
                    },
                  },
                },
              ],
            },
          },
        ],
      });

      expect(subs.length, 1);
      expect(subs.single.channelId, 'UCabc123');
      expect(subs.single.title, 'Channel A');
    });
  });
}
