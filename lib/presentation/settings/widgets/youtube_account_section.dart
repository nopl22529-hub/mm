import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxtube/core/constants.dart';
import 'package:fluxtube/domain/auth/models/device_code_response.dart';
import 'package:fluxtube/domain/auth/youtube_auth_service.dart';
import 'package:fluxtube/infrastructure/auth/innertube_auth_impl.dart';
import 'package:fluxtube/presentation/settings/widgets/settings_components.dart';
import 'package:url_launcher/url_launcher.dart';

/// YouTube account sign-in (Innertube, Phase 1).
///
/// Unlike [GoogleAccountCard] above it in Settings — which only
/// connects a Google *identity* — this section authorizes FluxTube
/// to act as the user's YouTube channel via the TV device flow, so
/// later phases can like, subscribe, comment, and sync history.
///
/// Strings are plain English for now; move them into the ARB files
/// and regenerate localizations before a public release.
class YoutubeAccountSection extends StatelessWidget {
  const YoutubeAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = InnertubeAuthImpl();
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final account = auth.account;
        return SettingsSectionCard(
          title: 'YOUTUBE ACCOUNT',
          children: [
            if (auth.isRestoring && account == null)
              const SettingsActionTile(
                icon: Icons.account_circle_outlined,
                title: 'YouTube account',
                subtitle: 'Restoring session…',
                trailing: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (account == null)
              SettingsActionTile(
                icon: Icons.account_circle_outlined,
                title: 'Sign in to YouTube',
                subtitle: 'Like, subscribe, comment and sync history with your real account',
                onTap: () => _startSignIn(context),
              )
            else ...[
              SettingsActionTile(
                icon: Icons.account_circle,
                title: account.title.isEmpty
                    ? 'YouTube account'
                    : account.title,
                subtitle: account.handle ?? account.channelId,
                trailing: account.avatarUrl == null
                    ? null
                    : CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(account.avatarUrl!),
                      ),
              ),
              SettingsActionTile(
                icon: Icons.logout,
                title: 'Sign out of YouTube',
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _startSignIn(BuildContext context) async {
    final auth = InnertubeAuthImpl();
    DeviceCodeResponse code;
    try {
      code = await auth.requestDeviceCode();
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, 'Could not start YouTube sign-in. $e');
      }
      return;
    }
    if (!context.mounted) return;
    final signedIn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeviceCodeDialog(code: code),
    );
    if (signedIn == true && context.mounted) {
      _showMessage(context, 'Signed in to YouTube.');
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of YouTube?'),
        content: const Text(
          'FluxTube will stop acting as your YouTube channel. '
          'Local profiles, subscriptions and history on this device are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await InnertubeAuthImpl().signOut();
    if (context.mounted) {
      _showMessage(context, 'Signed out of YouTube.');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Shows the device code and polls Google until the user approves.
class _DeviceCodeDialog extends StatefulWidget {
  const _DeviceCodeDialog({required this.code});

  final DeviceCodeResponse code;

  @override
  State<_DeviceCodeDialog> createState() => _DeviceCodeDialogState();
}

class _DeviceCodeDialogState extends State<_DeviceCodeDialog> {
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    try {
      await InnertubeAuthImpl().pollForSignIn(
        widget.code,
        isCancelled: () => _cancelled,
      );
      if (mounted && !_cancelled) Navigator.pop(context, true);
    } on YoutubeAuthException catch (e) {
      if (mounted && !_cancelled) {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted && !_cancelled) {
        setState(() => _error = 'YouTube sign-in failed. $e');
      }
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Sign in to YouTube'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'On your phone or computer, open the link below and enter this code:',
          ),
          AppSpacing.height16,
          Center(
            child: SelectableText(
              widget.code.userCode,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          AppSpacing.height8,
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: widget.code.userCode),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Code copied.')));
                }
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy code'),
            ),
          ),
          AppSpacing.height8,
          Center(
            child: FilledButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(widget.code.verificationUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(widget.code.verificationUrl),
            ),
          ),
          AppSpacing.height16,
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Waiting for approval…')),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
