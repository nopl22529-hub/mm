import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/domain/auth/models/playback_tracking.dart';
import 'package:fluxtube/domain/auth/models/youtube_history_item.dart';

void main() {
  group('YoutubeHistoryItem', () {
    test('parses classic videoRenderer history', () {
      final items = YoutubeHistoryItem.fromHistoryResponse({
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
                                    'verticalListRenderer': {
                                      'items': [
                                        {
                                          'videoRenderer': {
                                            'videoId': 'dQw4w9WgXcQ',
                                            'title': {
                                              'runs': [
                                                {'text': 'Never Gonna'},
                                              ],
                                            },
                                            'ownerText': {
                                              'runs': [
                                                {
                                                  'text': 'Rick Astley',
                                                  'navigationEndpoint': {
                                                    'browseEndpoint': {
                                                      'browseId': 'UCxyz',
                                                    },
                                                  },
                                                },
                                              ],
                                            },
                                            'viewCountText': {
                                              'simpleText': '1B views',
                                            },
                                            'lengthText': {
                                              'simpleText': '3:33',
                                            },
                                            'thumbnail': {
                                              'thumbnails': [
                                                {
                                                  'url': 'https://i.ytimg.example/x.jpg',
                                                },
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

      expect(items.length, 1);
      expect(items.single.videoId, 'dQw4w9WgXcQ');
      expect(items.single.title, 'Never Gonna');
      expect(items.single.channelName, 'Rick Astley');
      expect(items.single.channelId, 'UCxyz');
      expect(items.single.viewsText, '1B views');
      expect(items.single.durationText, '3:33');
    });

    test('parses lockupViewModel history', () {
      final items = YoutubeHistoryItem.fromHistoryResponse({
        'contents': [
          {
            'lockupViewModel': {
              'contentId': 'abc123def45',
              'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
              'contentImage': {
                'thumbnailViewModel': {
                  'image': {
                    'thumbnails': [
                      {'url': 'https://i.ytimg.example/y.jpg'},
                    ],
                  },
                },
              },
              'metadata': {
                'lockupMetadataViewModel': {
                  'title': {'content': 'Some Video'},
                  'metadata': {
                    'contentMetadataViewModel': {
                      'metadataRows': [
                        {
                          'metadataParts': [
                            {
                              'text': {
                                'content': 'Some Channel',
                                'commandRuns': [],
                              },
                            },
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
        ],
      });

      expect(items.length, 1);
      expect(items.single.videoId, 'abc123def45');
      expect(items.single.title, 'Some Video');
      expect(items.single.channelName, 'Some Channel');
      expect(items.single.thumbnailUrl, 'https://i.ytimg.example/y.jpg');
    });
  });

  group('PlaybackTracking', () {
    test('parses player response', () {
      final tracking = PlaybackTracking.fromPlayerResponse({
        'playbackTracking': {
          'videostatsPlaybackUrl': {'baseUrl': 'https://s.youtube.com/play'},
          'videostatsWatchtimeUrl': {'baseUrl': 'https://s.youtube.com/watch'},
        },
      });
      expect(tracking?.playbackUrl, 'https://s.youtube.com/play');
      expect(tracking?.watchtimeUrl, 'https://s.youtube.com/watch');
    });

    test('returns null without playbackTracking', () {
      expect(PlaybackTracking.fromPlayerResponse({}), isNull);
    });
  });
}
