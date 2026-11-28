import 'package:fluxtube/domain/auth/models/device_code_response.dart';
import 'package:fluxtube/domain/auth/models/youtube_account.dart';

/// Thrown when a YouTube sign-in step fails for a reason the UI can
/// show to the user (expired code, denied access, network, ...).
class YoutubeAuthException implements Exception {
  YoutubeAuthException(this.message);

  final String message;

  @override
  String toString() => 'YoutubeAuthException: $message';
}

/// YouTube account authorization for Innertube actions.
///
/// Phase 1 covers sign-in only: the TV device flow, secure token
/// storage, silent refresh, and fetching the signed-in channel.
/// Like / subscribe / comment / history build on
/// [getValidAccessToken] and [innertubePost] in later phases.
abstract class YoutubeAuthService {
  /// The signed-in channel, or null when signed out.
  YoutubeAccount? get account;

  bool get isSignedIn;

  /// Restores a previous session from secure storage, refreshing the
  /// access token when needed. Safe to call on every app start;
  /// failures leave the user signed out instead of throwing.
  Future<void> restoreSession();

  /// Starts the device flow: returns the code the user must enter at
  /// the verification URL.
  Future<DeviceCodeResponse> requestDeviceCode();

  /// Polls Google until the user approves [deviceCode], then stores
  /// the tokens and loads the account.
  ///
  /// Throws [YoutubeAuthException] when the code expires, access is
  /// denied, or polling is cancelled via [isCancelled] returning true.
  Future<YoutubeAccount> pollForSignIn(
    DeviceCodeResponse deviceCode, {
    bool Function()? isCancelled,
  });

  /// Revokes the refresh token (best effort) and clears all stored
  /// credentials.
  Future<void> signOut();

  /// A currently valid OAuth access token, refreshed silently when it
  /// is about to expire. Null when signed out or refresh fails (in
  /// which case the session is cleared).
  Future<String?> getValidAccessToken();

  /// POSTs to an Innertube endpoint (`youtubei/v1/<endpoint>`) with
  /// the signed-in user's bearer token and a WEB client context.
  ///
  /// Foundation for later phases (history, like, subscribe, comment).
  /// Returns the decoded JSON object, or throws [YoutubeAuthException]
  /// on HTTP / network failure.
  Future<Map<String, dynamic>> innertubePost(
    String endpoint,
    Map<String, dynamic> body,
  );
}
