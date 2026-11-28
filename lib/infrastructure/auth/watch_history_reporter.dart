import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/domain/auth/models/playback_tracking.dart';
import 'package:fluxtube/infrastructure/auth/innertube_auth_impl.dart';

/// Reports FluxTube playback to the signed-in account's YouTube
/// watch history, the way YouTube's own clients do: fetch the
/// player response's playback-stats URLs, ping the playback URL
/// when playback starts, then the watchtime URL with the watched
/// segment every 40s while playing, on pause, and at the end.
///
/// Polls [GlobalPlayerController] instead of listening to player
/// events, so it works across the watch screen, PiP, and
/// background playback. Streams still come from NewPipe; only the
/// stats pings are signed in.
class WatchHistoryReporter {
  WatchHistoryReporter._();
  static final WatchHistoryReporter _instance = WatchHistoryReporter._();
  factory WatchHistoryReporter() => _instance;

  static const _tickInterval = Duration(seconds: 5);
  static const _watchtimeInterval = Duration(seconds: 40);
  static const _cpnAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  Timer? _timer;
  _Report? _report;
  bool _wasPlaying = false;

  void start() {
    _timer ??= Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    final auth = InnertubeAuthImpl();
    if (!auth.isSignedIn) {
      _report = null;
      _wasPlaying = false;
      return;
    }

    final player = GlobalPlayerController();
    final videoId = player.currentVideoId;
    final position = player.currentPosition.inMilliseconds / 1000.0;
    final duration = player.totalDuration.inMilliseconds / 1000.0;
    final playing = player.isPlaying;

    if (videoId == null) {
      if (_report != null) {
        _watchtime('paused', finalPing: true);
        _report = null;
      }
      _wasPlaying = false;
      return;
    }

    if (_report == null || _report!.videoId != videoId) {
      if (_report != null) {
        _watchtime('paused', finalPing: true);
      }
      _begin(videoId, position);
    }

    final report = _report!;
    report.lastPosition = position;

    if (playing) {
      if (DateTime.now().difference(report.lastPingAt) >= _watchtimeInterval) {
        _watchtime('playing');
      }
    } else if (_wasPlaying) {
      final ended = duration > 0 && position >= duration - 1;
      _watchtime(ended ? 'ended' : 'paused', finalPing: ended);
    }
    _wasPlaying = playing;
  }

  void _begin(String videoId, double position) {
    final auth = InnertubeAuthImpl();
    final report = _Report(
      videoId: videoId,
      tracking: auth.fetchPlaybackTracking(videoId),
      segmentStart: position,
    );
    _report = report;
    _wasPlaying = false;
    report.tracking.then((tracking) {
      if (tracking == null || _report != report) return;
      _ping(tracking.playbackUrl, report, {'cmt': _fmt(position)});
    });
  }

  void _watchtime(String state, {bool finalPing = false}) {
    final report = _report;
    if (report == null) return;
    var start = report.segmentStart;
    var end = report.lastPosition;
    if (end < start) {
      // Seeked backwards: don't fabricate watched time.
      start = end;
    }
    report.segmentStart = end;
    report.lastPingAt = DateTime.now();
    report.tracking.then((tracking) {
      if (tracking == null) return;
      _ping(tracking.watchtimeUrl, report, {
        'cmt': _fmt(end),
        'st': _fmt(start),
        'et': _fmt(end),
        'state': state,
        if (finalPing) 'final': '1',
      });
    });
  }

  void _ping(String baseUrl, _Report report, Map<String, String> extra) {
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters)
      ..addAll({
        'ver': '2',
        'cpn': report.cpn,
        'rt': _fmt(
          DateTime.now().difference(report.startedAt).inMilliseconds / 1000.0,
        ),
        'lact': '1',
        ...extra,
      });
    final url = uri.replace(queryParameters: params).toString();
    debugPrint(
      '[WatchHistory] ${report.videoId} '
      '${extra['state'] ?? 'playback'} ${extra['st'] ?? ''}-${extra['et'] ?? ''}',
    );
    InnertubeAuthImpl().pingStatsUrl(url);
  }

  static String _fmt(double seconds) => seconds.toStringAsFixed(3);
}

class _Report {
  _Report({
    required this.videoId,
    required this.tracking,
    required this.segmentStart,
  }) : cpn = _makeCpn(),
       startedAt = DateTime.now(),
       lastPingAt = DateTime.now(),
       lastPosition = segmentStart;

  final String videoId;
  final Future<PlaybackTracking?> tracking;
  final String cpn;
  final DateTime startedAt;
  double segmentStart;
  double lastPosition;
  DateTime lastPingAt;

  static String _makeCpn() {
    final random = Random();
    return String.fromCharCodes(
      List.generate(
        16,
        (_) => WatchHistoryReporter._cpnAlphabet.codeUnitAt(random.nextInt(64)),
      ),
    );
  }
}
