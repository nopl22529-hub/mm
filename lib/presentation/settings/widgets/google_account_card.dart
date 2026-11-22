import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Lets the user connect a Google identity to this local FluxTube install.
/// YouTube actions still use FluxTube's existing anonymous providers.
class GoogleAccountCard extends StatefulWidget {
  const GoogleAccountCard({super.key});

  @override
  State<GoogleAccountCard> createState() => _GoogleAccountCardState();
}

class _GoogleAccountCardState extends State<GoogleAccountCard> {
  static const _webClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;
  static GoogleSignInAccount? _lastKnownAccount;

  GoogleSignInAccount? _account = _lastKnownAccount;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authenticationSubscription;
  bool _isBusy = _lastKnownAccount == null;
  bool _isConfigured = false;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();
    _restoreAccount();
  }

  Future<void> _restoreAccount() async {
    try {
      _isAvailable = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      _isConfigured = defaultTargetPlatform == TargetPlatform.android
          ? _webClientId.isNotEmpty
          : defaultTargetPlatform == TargetPlatform.iOS &&
              _webClientId.isNotEmpty &&
              _iosClientId.isNotEmpty;
      if (!_isAvailable || !_isConfigured) {
        setState(() => _isBusy = false);
        return;
      }

      final signIn = GoogleSignIn.instance;
      await _ensureInitialized(signIn);
      _authenticationSubscription = signIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: _handleAuthenticationError,
      );
      if (mounted) setState(() => _isBusy = false);

      // The package documents authenticationEvents as the source of truth for
      // UI state. The lightweight-authentication Future can remain pending, so
      // don't await it here or the settings card can spin forever.
      unawaited(_attemptLightweightAuthentication(signIn));
    } catch (_) {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _ensureInitialized(GoogleSignIn signIn) {
    return _initialization ??= signIn.initialize(
      serverClientId: _webClientId,
      clientId:
          defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
    ).catchError((Object error) {
      // Allow a later screen visit to retry after a transient init failure.
      _initialization = null;
      throw error;
    });
  }

  Future<void> _attemptLightweightAuthentication(GoogleSignIn signIn) async {
    try {
      await signIn.attemptLightweightAuthentication();
    } catch (_) {
      // The authentication event stream reports successful state changes.
      // A missing prior session is normal and should leave the button usable.
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (!mounted) return;
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        setState(() {
          _account = user;
          _lastKnownAccount = user;
          _isBusy = false;
        });
      case GoogleSignInAuthenticationEventSignOut():
        setState(() {
          _account = null;
          _lastKnownAccount = null;
          _isBusy = false;
        });
    }
  }

  void _handleAuthenticationError(Object error, StackTrace stackTrace) {
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  void dispose() {
    _authenticationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signIn() async {
    final signIn = GoogleSignIn.instance;
    if (!signIn.supportsAuthenticate()) {
      _showMessage(S.of(context).googleSignInUnavailable);
      return;
    }

    setState(() => _isBusy = true);
    try {
      final account = await signIn.authenticate().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted) return;
      setState(() {
        _account = account;
        _lastKnownAccount = account;
        _isBusy = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (_account == null) {
        _showMessage(S.of(context).googleSignInFailed);
      }
    } on GoogleSignInException catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showMessage(S.of(context).googleSignInFailed);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showMessage(S.of(context).googleSignInFailed);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    try {
      await GoogleSignIn.instance.signOut();
      if (!mounted) return;
      setState(() {
        _account = null;
        _lastKnownAccount = null;
        _isBusy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _showMessage(S.of(context).googleSignInFailed);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locals = S.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.borderLg,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.surfaceContainerHigh,
            backgroundImage: _account?.photoUrl == null
                ? null
                : NetworkImage(_account!.photoUrl!),
            child: _account?.photoUrl == null
                ? Icon(Icons.account_circle_outlined, color: scheme.primary)
                : null,
          ),
          AppSpacing.width16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _account?.displayName ??
                      (_account == null
                          ? locals.googleSignIn
                          : locals.googleAccountConnected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (_account?.email case final email?) ...[
                  AppSpacing.height4,
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (!_isConfigured || !_isAvailable) ...[
                  AppSpacing.height4,
                  Text(
                    !_isAvailable
                        ? locals.googleSignInUnavailable
                        : locals.googleSignInSetupHint,
                    maxLines: 3,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.width8,
          if (_isBusy)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          else if (_account != null)
            IconButton(
              tooltip: locals.googleSignOut,
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            )
          else
            FilledButton.tonal(
              onPressed: _isConfigured && _isAvailable ? _signIn : null,
              child: Text(locals.googleSignIn),
            ),
        ],
      ),
    );
  }
}
