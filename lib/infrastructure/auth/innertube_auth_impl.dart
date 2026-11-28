import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluxtube/core/api_client.dart';
import 'package:fluxtube/domain/auth/models/device_code_response.dart';
import 'package:fluxtube/domain/auth/models/video_engagement.dart';
import 'package:fluxtube/domain/auth/models/youtube_account.dart';
import 'package:fluxtube/domain/auth/youtube_auth_service.dart';

/// YouTube sign-in via the OAuth 2.0 TV / limited-input device flow,
/// the same flow Innertube clients (YouTube.js, yt-dlp, SmartTube)
/// use: the app shows a short code, the user enters it at
/// youtube.com/activate, and the app polls for tokens.
///
/// The default client credentials below are the public YouTube TV
/// client credentials that every Innertube client ships. Installed /
/// TV apps cannot keep a client secret (Google's device-flow guide
/// says so explicitly), so these identify the *client type*, not a
/// person. The user's own refresh token is the sensitive value, and
/// it never leaves the device: it is stored in platform secure
/// storage (Android Keystore / iOS Keychain) via
/// `flutter_secure_storage`, never in Drift, logs, or the repo.
///
/// A build can override the client with its own Google Cloud OAuth
/// client (type: TVs and Limited Input devices) via:
/// `--dart-define=YOUTUBE_CLIENT_ID=... --dart-define=YOUTUBE_CLIENT_SECRET=...`
class InnertubeAuthImpl extends ChangeNotifier implements YoutubeAuthService {
  static final InnertubeAuthImpl _instance = InnertubeAuthImpl._internal();
  factory InnertubeAuthImpl() => _instance;
  InnertubeAuthImpl._internal();

  static const _clientId = String.fromEnvironment(
    'YOUTUBE_CLIENT_ID',
    defaultValue: '861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com',
  );
  static const _clientSecret = String.fromEnvironment(
    'YOUTUBE_CLIENT_SECRET',
    defaultValue: 'SboVhoG9s0rNafixCSGGKXAT',
  );

  static const _scope = 'https://www.googleapis.com/auth/youtube';
  static const _deviceCodeUrl = 'https://oauth2.googleapis.com/device/code';
  static const _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const _revokeUrl = 'https://oauth2.googleapis.com/revoke';
  static const _channelsUrl =
      'https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true';
  static const _innertubeBase = 'https://www.youtube.com/youtubei/v1';

  // Innertube WEB client context. YouTube rotates client versions;
  // bump this if authenticated Innertube calls start failing.
  static const _webClientVersion = '2.20260623.01.00';
  static const _tvClientVersion = '7.20260311.12.00';

  static const _kRefreshToken = 'yt_refresh_token';
  static const _kAccessToken = 'yt_access_token';
  static const _kAccessTokenExpiry = 'yt_access_token_expiry_ms';
  static const _kAccountJson = 'yt_account_json';

  final FlutterSecureStorage _storage = FlutterSecureStorage();

  YoutubeAccount? _account;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  bool _restoring = false;

  @override
  YoutubeAccount? get account => _account;

  @override
  bool get isSignedIn => _account != null;

  bool get isRestoring => _restoring;

  Dio get _dio => ApiClient.dio;

  @override
  Future<void> restoreSession() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final refreshToken = await _storage.read(key: _kRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        return;
      }
      _accessToken = await _storage.read(key: _kAccessToken);
      final expiryMs = int.tryParse(
        await _storage.read(key: _kAccessTokenExpiry) ?? '',
      );
      _accessTokenExpiry = expiryMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiryMs);

      final cachedAccount = await _storage.read(key: _kAccountJson);
      if (cachedAccount != null && cachedAccount.isNotEmpty) {
        try {
          _account = YoutubeAccount.fromJson(
            jsonDecode(cachedAccount) as Map<String, dynamic>,
          );
          notifyListeners();
        } catch (_) {
          // Corrupt cache is not fatal; it is refreshed below.
        }
      }

      final token = await getValidAccessToken();
      if (token == null) return;
      final fresh = await _fetchAccount(token);
      if (fresh != null) {
        _account = fresh;
        await _storage.write(
          key: _kAccountJson,
          value: jsonEncode(fresh.toJson()),
        );
        notifyListeners();
      } else if (_account == null) {
        // Valid tokens but no channel details: still signed in.
        _account = _fallbackAccount;
        notifyListeners();
      }
    } catch (e) {
      log('[InnertubeAuth] restoreSession failed: $e');
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  @override
  Future<DeviceCodeResponse> requestDeviceCode() async {
    final response = await _dio.post<dynamic>(
      _deviceCodeUrl,
      data: {'client_id': _clientId, 'scope': _scope},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = response.data;
    if (response.statusCode == 200 && data is Map<String, dynamic>) {
      return DeviceCodeResponse.fromJson(data);
    }
    throw YoutubeAuthException(
      'Could not start YouTube sign-in (HTTP ${response.statusCode}).',
    );
  }

  @override
  Future<YoutubeAccount> pollForSignIn(
    DeviceCodeResponse deviceCode, {
    bool Function()? isCancelled,
  }) async {
    var interval = deviceCode.interval;
    final deadline = DateTime.now().add(
      Duration(seconds: deviceCode.expiresIn),
    );

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() ?? false) {
        throw YoutubeAuthException('Sign-in cancelled.');
      }
      await Future<void>.delayed(Duration(seconds: interval));
      if (isCancelled?.call() ?? false) {
        throw YoutubeAuthException('Sign-in cancelled.');
      }

      final response = await _dio.post<dynamic>(
        _tokenUrl,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'device_code': deviceCode.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        continue;
      }
      if (response.statusCode == 200 && data['access_token'] is String) {
        await _storeTokens(data);
        final token = _accessToken;
        if (token == null) {
          throw YoutubeAuthException('YouTube sign-in returned no token.');
        }
        // Tokens are already stored at this point, so a failed
        // channel lookup must not fail the sign-in.
        final account = await _fetchAccount(token) ?? _fallbackAccount;
        _account = account;
        await _storage.write(
          key: _kAccountJson,
          value: jsonEncode(account.toJson()),
        );
        notifyListeners();
        return account;
      }

      switch (data['error'] as String?) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += 5;
          continue;
        case 'access_denied':
          throw YoutubeAuthException('YouTube sign-in was denied.');
        case 'expired_token':
          throw YoutubeAuthException(
            'The sign-in code expired. Please try again.',
          );
        default:
          // Transient errors keep polling until the deadline.
          continue;
      }
    }
    throw YoutubeAuthException('The sign-in code expired. Please try again.');
  }

  @override
  Future<String?> getValidAccessToken() async {
    final expiry = _accessTokenExpiry;
    if (_accessToken != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return _accessToken;
    }

    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post<dynamic>(
        _tokenUrl,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        await _storeTokens(data, keepRefreshToken: refreshToken);
        return _accessToken;
      }
      log('[InnertubeAuth] token refresh failed: HTTP ${response.statusCode}');
    } catch (e) {
      log('[InnertubeAuth] token refresh error: $e');
      // Network errors should not sign the user out; only a rejected
      // refresh token should. Fall through to the cached token when
      // it might still work, otherwise keep the session for a retry.
      return _accessToken;
    }

    // Refresh was rejected (revoked / expired grant): clear session.
    await _clearSession();
    return null;
  }

  @override
  Future<void> signOut() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _dio.post<dynamic>(
          _revokeUrl,
          data: {'token': refreshToken},
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      } catch (_) {
        // Revocation is best effort; local cleanup still happens.
      }
    }
    await _clearSession();
  }

  @override
  Future<Map<String, dynamic>> innertubePost(
    String endpoint,
    Map<String, dynamic> body, {
    String clientName = 'WEB',
    String? clientVersion,
    String clientNameId = '1',
  }) async {
    final version = clientVersion ?? _webClientVersion;
    final token = await getValidAccessToken();
    final response = await _dio.post<dynamic>(
      '$_innertubeBase/$endpoint?prettyPrint=false',
      data: {
        'context': {
          'client': {
            'clientName': clientName,
            'clientVersion': version,
            'hl': 'en',
            'gl': 'US',
          },
        },
        ...body,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          // OAuth-authenticated Innertube requests must carry a
          // request timestamp; Google rejects them with HTTP 400
          // without it (ytmusicapi does the same for OAuth auth).
          if (token != null)
            'X-Goog-Request-Time':
                (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          'X-YouTube-Client-Name': clientNameId,
          'X-YouTube-Client-Version': version,
        },
      ),
    );
    final data = response.data;
    if (response.statusCode == 200 && data is Map<String, dynamic>) {
      return data;
    }
    var detail = '';
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        final status = error['status'];
        if (message is String && message.isNotEmpty) detail = ' $message';
        if (status is String && status.isNotEmpty) detail += ' ($status)';
      }
    }
    throw YoutubeAuthException(
      'Innertube $endpoint failed (HTTP ${response.statusCode}).$detail',
    );
  }

  Future<void> _storeTokens(
    Map<String, dynamic> data, {
    String? keepRefreshToken,
  }) async {
    _accessToken = data['access_token'] as String?;
    final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
    _accessTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

    final refreshToken = (data['refresh_token'] as String?) ?? keepRefreshToken;
    if (_accessToken != null) {
      await _storage.write(key: _kAccessToken, value: _accessToken);
    }
    await _storage.write(
      key: _kAccessTokenExpiry,
      value: _accessTokenExpiry!.millisecondsSinceEpoch.toString(),
    );
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  /// Best-effort channel lookup. Sign-in success is the stored
  /// tokens, not this lookup: the Data API call can fail for TV
  /// tokens (its quota belongs to the OAuth client's project) and
  /// accounts without a created channel return no items, so both
  /// failures fall back to Innertube `account/accounts_list` with
  /// the TV client, and callers fall back further to a placeholder
  /// account instead of failing the whole sign-in.
  Future<YoutubeAccount?> _fetchAccount(String accessToken) async {
    try {
      final response = await _dio.get<dynamic>(
        _channelsUrl,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>? ?? const [];
        if (items.isNotEmpty) {
          return YoutubeAccount.fromChannelItem(
            items.first as Map<String, dynamic>,
          );
        }
        debugPrint('[InnertubeAuth] channels.list returned no channel');
      } else {
        debugPrint(
          '[InnertubeAuth] channels.list failed: HTTP '
          '${response.statusCode} ${data is Map ? data['error'] : ''}',
        );
      }
    } catch (e) {
      debugPrint('[InnertubeAuth] channels.list error: $e');
    }

    try {
      final data = await innertubePost(
        'account/accounts_list',
        const {},
        clientName: 'TVHTML5',
        clientVersion: _tvClientVersion,
        clientNameId: '7',
      );
      final account = YoutubeAccount.fromAccountsListResponse(data);
      if (account != null) return account;
      debugPrint('[InnertubeAuth] accounts_list had no account item');
    } catch (e) {
      debugPrint('[InnertubeAuth] accounts_list error: $e');
    }
    return null;
  }

  static const _fallbackAccount = YoutubeAccount(
    channelId: '',
    title: 'YouTube account',
  );

  // --- Phase 2: like / subscribe on the real account ---
  //
  // Device-flow (TV OAuth) tokens are only accepted by YouTube's TV
  // client: the WEB client answers HTTP 400 for signed-in calls made
  // with them. All Phase 2 calls therefore use TVHTML5, like the
  // accounts_list lookup in Phase 1.

  static const _tvClientName = 'TVHTML5';
  static const _tvClientNameId = '7';

  final Map<String, (VideoEngagement, DateTime)> _engagementCache = {};

  @override
  Future<VideoEngagement?> fetchEngagement(String videoId) async {
    if (!isSignedIn) return null;
    final cached = _engagementCache[videoId];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < const Duration(minutes: 5)) {
      return cached.$1;
    }
    try {
      final data = await innertubePost(
        'next',
        {'videoId': videoId, 'contentCheckOk': true, 'racyCheckOk': true},
        clientName: _tvClientName,
        clientVersion: _tvClientVersion,
        clientNameId: _tvClientNameId,
      );
      final engagement = VideoEngagement.fromNextResponse(data);
      _engagementCache[videoId] = (engagement, DateTime.now());
      return engagement;
    } catch (e) {
      debugPrint('[InnertubeAuth] fetchEngagement failed: $e');
      return null;
    }
  }

  @override
  Future<void> rateVideo(
    String videoId,
    VideoRating rating, {
    VideoEngagement? engagement,
  }) async {
    final (endpoint, params) = switch (rating) {
      VideoRating.like => ('like/like', engagement?.likeParams),
      VideoRating.dislike => ('like/dislike', engagement?.dislikeParams),
      VideoRating.none => ('like/removelike', engagement?.removeLikeParams),
    };
    await innertubePost(
      endpoint,
      {
        'target': {'videoId': videoId},
        if (params != null) 'params': params,
      },
      clientName: _tvClientName,
      clientVersion: _tvClientVersion,
      clientNameId: _tvClientNameId,
    );
    final cached = _engagementCache[videoId];
    if (cached != null) {
      _engagementCache[videoId] = (
        cached.$1.copyWith(rating: rating),
        cached.$2,
      );
    }
  }

  @override
  Future<void> setSubscribed(
    String channelId,
    bool subscribe, {
    String? params,
  }) async {
    await innertubePost(
      subscribe ? 'subscription/subscribe' : 'subscription/unsubscribe',
      {
        'channelIds': [channelId],
        // Fixed params from YouTube's own subscribe-button commands,
        // used when the watch response did not provide its own.
        'params': params ?? (subscribe ? 'EgIIAhgA' : 'CgIIAhgA'),
      },
      clientName: _tvClientName,
      clientVersion: _tvClientVersion,
      clientNameId: _tvClientNameId,
    );
  }

  @override
  Future<void> syncSubscription(String channelId, bool subscribe) async {
    if (!isSignedIn) return;
    try {
      await setSubscribed(channelId, subscribe);
    } catch (e) {
      debugPrint('[InnertubeAuth] syncSubscription failed: $e');
    }
  }

  Future<void> _clearSession() async {
    _account = null;
    _accessToken = null;
    _accessTokenExpiry = null;
    _engagementCache.clear();
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kAccessTokenExpiry);
    await _storage.delete(key: _kAccountJson);
    notifyListeners();
  }
}
