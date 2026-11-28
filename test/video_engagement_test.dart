import 'package:flutter_test/flutter_test.dart';
import 'package:fluxtube/domain/auth/models/video_engagement.dart';

void main() {
  group('VideoEngagement.fromNextResponse', () {
    test('parses old renderer shapes', () {
      final engagement = VideoEngagement.fromNextResponse({
        'contents': {
          'videoPrimaryInfoRenderer': {
            'videoActions': {
              'menuRenderer': {
                'topLevelButtons': [
                  {
                    'segmentedLikeDislikeButtonRenderer': {
                      'likeButton': {
                        'toggleButtonRenderer': {
                          'defaultServiceEndpoint': {
                            'likeEndpoint': {
                              'status': 'LIKE',
                              'target': {'videoId': 'abc'},
                              'likeParams': 'like-p',
                              'dislikeParams': 'dislike-p',
                              'removeLikeParams': 'remove-p',
                            },
                          },
                        },
                      },
                      'likeStatus': 'LIKE',
                    },
                  },
                ],
              },
            },
          },
          'videoSecondaryInfoRenderer': {
            'subscribeButton': {
              'subscribeButtonRenderer': {
                'subscribed': true,
                'serviceEndpoints': [
                  {
                    'unsubscribeEndpoint': {
                      'channelIds': ['UC123'],
                      'params': 'unsub-p',
                    },
                  },
                ],
              },
            },
          },
        },
      });

      expect(engagement.rating, VideoRating.like);
      expect(engagement.isSubscribed, isTrue);
      expect(engagement.likeParams, 'like-p');
      expect(engagement.dislikeParams, 'dislike-p');
      expect(engagement.removeLikeParams, 'remove-p');
      expect(engagement.unsubscribeParams, 'unsub-p');
    });

    test('parses new view-model shapes', () {
      final engagement = VideoEngagement.fromNextResponse({
        'contents': {
          'segmentedLikeDislikeButtonViewModel': {
            'likeButtonViewModel': {
              'likeButtonViewModel': {
                'toggleButtonViewModel': {
                  'toggleButtonViewModel': {'isToggled': false},
                },
                'likeStatusEntity': {'likeStatus': 'DISLIKE'},
              },
            },
            'dislikeButtonViewModel': {
              'dislikeButtonViewModel': {
                'toggleButtonViewModel': {
                  'toggleButtonViewModel': {'isToggled': true},
                },
              },
            },
          },
          'subscribeButtonViewModel': {
            'subscribeButtonViewModel': {
              'subscribeStateEntity': {'subscribed': false},
              'onTap': {
                'innertubeCommand': {
                  'subscribeEndpoint': {
                    'channelIds': ['UC123'],
                    'params': 'sub-p',
                  },
                },
              },
            },
          },
        },
      });

      expect(engagement.rating, VideoRating.dislike);
      expect(engagement.isSubscribed, isFalse);
      expect(engagement.subscribeParams, 'sub-p');
    });

    test('defaults when nothing is present', () {
      final engagement = VideoEngagement.fromNextResponse({
        'contents': <String, dynamic>{},
      });
      expect(engagement.rating, VideoRating.none);
      expect(engagement.isSubscribed, isNull);
      expect(engagement.likeParams, isNull);
    });
  });
}
