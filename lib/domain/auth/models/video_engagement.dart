/// The signed-in user's rating of a video.
enum VideoRating { like, dislike, none }

/// Signed-in engagement state for one video, parsed from an
/// Innertube `next` response: current like/dislike rating, whether
/// the user is subscribed to the channel, and the opaque `params`
/// strings YouTube attaches to its like/subscribe endpoints (the
/// endpoints accept them back; calls without them may be rejected).
class VideoEngagement {
  const VideoEngagement({
    this.rating = VideoRating.none,
    this.isSubscribed,
    this.likeParams,
    this.dislikeParams,
    this.removeLikeParams,
    this.subscribeParams,
    this.unsubscribeParams,
  });

  final VideoRating rating;

  /// Null when the response did not say.
  final bool? isSubscribed;
  final String? likeParams;
  final String? dislikeParams;
  final String? removeLikeParams;
  final String? subscribeParams;
  final String? unsubscribeParams;

  VideoEngagement copyWith({VideoRating? rating, bool? isSubscribed}) {
    return VideoEngagement(
      rating: rating ?? this.rating,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      likeParams: likeParams,
      dislikeParams: dislikeParams,
      removeLikeParams: removeLikeParams,
      subscribeParams: subscribeParams,
      unsubscribeParams: unsubscribeParams,
    );
  }

  /// Parses a `next` response by searching the renderer tree rather
  /// than following one exact path — YouTube rearranges these
  /// view models often, but the endpoint objects and status fields
  /// keep their names.
  static VideoEngagement fromNextResponse(Map<String, dynamic> json) {
    var rating = VideoRating.none;
    bool? isSubscribed;
    String? likeParams;
    String? dislikeParams;
    String? removeLikeParams;
    String? subscribeParams;
    String? unsubscribeParams;

    void visit(Object? node) {
      if (node is Map<String, dynamic>) {
        // Old renderer: likeButtonRenderer { likeStatus: LIKE|... }
        // New view model: likeStatusEntity { likeStatus: ... }
        final likeStatus = node['likeStatus'];
        if (likeStatus is String) {
          if (likeStatus == 'LIKE') rating = VideoRating.like;
          if (likeStatus == 'DISLIKE') rating = VideoRating.dislike;
        }

        // TV/older renderers: a toggled toggleButtonRenderer whose
        // service endpoint is a likeEndpoint with a status.
        if (node['isToggled'] == true) {
          for (final key in const [
            'defaultServiceEndpoint',
            'toggledServiceEndpoint',
            'serviceEndpoint',
          ]) {
            final endpoint = node[key];
            if (endpoint is Map<String, dynamic>) {
              final like = endpoint['likeEndpoint'];
              if (like is Map<String, dynamic>) {
                if (like['status'] == 'LIKE') rating = VideoRating.like;
                if (like['status'] == 'DISLIKE') {
                  rating = VideoRating.dislike;
                }
              }
            }
          }
        }

        // New view models mark the toggled side of the segmented
        // like/dislike button instead of a single status field.
        final likeButton = node['likeButtonViewModel'];
        if (likeButton is Map<String, dynamic> && _isToggled(likeButton)) {
          rating = VideoRating.like;
        }
        final dislikeButton = node['dislikeButtonViewModel'];
        if (dislikeButton is Map<String, dynamic> &&
            _isToggled(dislikeButton)) {
          rating = VideoRating.dislike;
        }

        final likeEndpoint = node['likeEndpoint'];
        if (likeEndpoint is Map<String, dynamic>) {
          likeParams ??= likeEndpoint['likeParams'] as String?;
          dislikeParams ??= likeEndpoint['dislikeParams'] as String?;
          removeLikeParams ??= likeEndpoint['removeLikeParams'] as String?;
          // Some shapes carry a single `params` plus a status.
          final params = likeEndpoint['params'];
          if (params is String) {
            switch (likeEndpoint['status']) {
              case 'LIKE':
                likeParams ??= params;
              case 'DISLIKE':
                dislikeParams ??= params;
              case 'INDIFFERENT':
                removeLikeParams ??= params;
            }
          }
        }

        // subscribeButtonRenderer { subscribed: bool, ... }
        final subscribed = node['subscribed'];
        if (subscribed is bool) isSubscribed = subscribed;

        final subscribeEndpoint = node['subscribeEndpoint'];
        if (subscribeEndpoint is Map<String, dynamic>) {
          subscribeParams ??= subscribeEndpoint['params'] as String?;
        }
        final unsubscribeEndpoint = node['unsubscribeEndpoint'];
        if (unsubscribeEndpoint is Map<String, dynamic>) {
          unsubscribeParams ??= unsubscribeEndpoint['params'] as String?;
        }

        for (final child in node.values) {
          visit(child);
        }
      } else if (node is List) {
        for (final child in node) {
          visit(child);
        }
      }
    }

    visit(json);
    return VideoEngagement(
      rating: rating,
      isSubscribed: isSubscribed,
      likeParams: likeParams,
      dislikeParams: dislikeParams,
      removeLikeParams: removeLikeParams,
      subscribeParams: subscribeParams,
      unsubscribeParams: unsubscribeParams,
    );
  }

  static bool _isToggled(Map<String, dynamic> buttonViewModel) {
    if (buttonViewModel['isToggled'] == true) return true;
    var toggle = buttonViewModel['toggleButtonViewModel'];
    // View models nest one wrapper level: {toggleButtonViewModel: {...}}.
    if (toggle is Map<String, dynamic> &&
        toggle['toggleButtonViewModel'] is Map<String, dynamic>) {
      toggle = toggle['toggleButtonViewModel'];
    }
    if (toggle is Map<String, dynamic>) {
      if (toggle['isToggled'] == true) return true;
      final state = toggle['toggleState'];
      if (state is String && state.toUpperCase().contains('TOGGLED')) {
        return true;
      }
    }
    return false;
  }
}
