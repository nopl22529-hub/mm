/// Playback-stats URLs from an Innertube player response, used to
/// report playback to the signed-in account's watch history the
/// same way YouTube's own clients do.
class PlaybackTracking {
  const PlaybackTracking({
    required this.playbackUrl,
    required this.watchtimeUrl,
  });

  /// Pinged once when playback starts.
  final String playbackUrl;

  /// Pinged periodically while playing, on pause, and at the end.
  final String watchtimeUrl;

  static PlaybackTracking? fromPlayerResponse(Map<String, dynamic> json) {
    final tracking = json['playbackTracking'];
    if (tracking is! Map<String, dynamic>) return null;
    final playback = tracking['videostatsPlaybackUrl'];
    final watchtime = tracking['videostatsWatchtimeUrl'];
    if (playback is Map<String, dynamic> && watchtime is Map<String, dynamic>) {
      final playbackUrl = playback['baseUrl'];
      final watchtimeUrl = watchtime['baseUrl'];
      if (playbackUrl is String &&
          playbackUrl.isNotEmpty &&
          watchtimeUrl is String &&
          watchtimeUrl.isNotEmpty) {
        return PlaybackTracking(
          playbackUrl: playbackUrl,
          watchtimeUrl: watchtimeUrl,
        );
      }
    }
    return null;
  }
}
