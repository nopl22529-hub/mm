import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/core/player/global_player_controller.dart';
import 'package:fluxtube/domain/auth/models/video_engagement.dart';
import 'package:fluxtube/domain/subscribes/models/subscribe.dart';
import 'package:fluxtube/domain/watch/models/newpipe/newpipe_watch_resp.dart';
import 'package:fluxtube/generated/l10n.dart';
import 'package:fluxtube/infrastructure/auth/innertube_auth_impl.dart';
import 'package:fluxtube/widgets/common_video_description_widget.dart';
import 'package:go_router/go_router.dart';

class NewPipeChannelInfoSection extends StatefulWidget {
  const NewPipeChannelInfoSection({
    super.key,
    required this.watchInfo,
    required this.locals,
    required this.state,
  });

  final NewPipeWatchResp watchInfo;
  final S locals;
  final WatchState state;

  @override
  State<NewPipeChannelInfoSection> createState() =>
      _NewPipeChannelInfoSectionState();
}

class _NewPipeChannelInfoSectionState extends State<NewPipeChannelInfoSection> {
  VideoEngagement? _engagement;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    final auth = InnertubeAuthImpl();
    final videoId = widget.watchInfo.id;
    if (!auth.isSignedIn || videoId == null || videoId.isEmpty) return;
    // Shares the cached `next` response with the like section.
    final engagement = await auth.fetchEngagement(videoId);
    if (mounted && engagement != null) {
      setState(() => _engagement = engagement);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchInfo = widget.watchInfo;
    final locals = widget.locals;
    final state = widget.state;
    return Visibility(
      visible: !state.isTapComments,
      child: BlocBuilder<SubscribeBloc, SubscribeState>(
        builder: (context, subscribeState) {
          final String? channelId = _extractChannelId(watchInfo.uploaderUrl);
          if (channelId == null) return const SizedBox();

          final bool localSubscribed =
              subscribeState.channelInfo?.id == channelId;
          // When signed in and YouTube told us the real status, trust
          // it over the local profile (the user may have subscribed
          // on youtube.com or another device).
          final bool isSubscribed =
              _engagement?.isSubscribed ?? localSubscribed;

          return GestureDetector(
            onTap: () {
              // Enable PiP mode when navigating away from watch screen
              final settingsState = context.read<SettingsBloc>().state;
              if (!settingsState.isPipDisabled) {
                GlobalPlayerController().enterPipMode();
                BlocProvider.of<WatchBloc>(context)
                    .add(WatchEvent.togglePip(value: true));
              }
              context.pushNamed(
                'channel',
                pathParameters: {'channelId': channelId},
                queryParameters: {'avatarUrl': watchInfo.uploaderAvatarUrl},
              );
            },
            child: SubscribeRowWidget(
              subscribed: isSubscribed,
              uploaderUrl: watchInfo.uploaderAvatarUrl,
              subcount: watchInfo.uploaderSubscriberCount?.toString(),
              uploader: watchInfo.uploaderName ?? locals.noUploaderName,
              isVerified: watchInfo.uploaderVerified ?? false,
              onSubscribeTap: () {
                final auth = InnertubeAuthImpl();
                if (isSubscribed) {
                  BlocProvider.of<SubscribeBloc>(context)
                      .add(SubscribeEvent.deleteSubscribeInfo(id: channelId));
                  auth.syncSubscription(channelId, false);
                } else {
                  BlocProvider.of<SubscribeBloc>(context).add(
                    SubscribeEvent.addSubscribe(
                      channelInfo: Subscribe(
                        id: channelId,
                        channelName:
                            watchInfo.uploaderName ?? locals.noUploaderName,
                        isVerified: watchInfo.uploaderVerified ?? false,
                        avatarUrl: watchInfo.uploaderAvatarUrl,
                      ),
                    ),
                  );
                  auth.syncSubscription(channelId, true);
                }
                setState(() {
                  _engagement = (_engagement ?? const VideoEngagement())
                      .copyWith(isSubscribed: !isSubscribed);
                });
              },
            ),
          );
        },
      ),
    );
  }

  String? _extractChannelId(String? uploaderUrl) {
    if (uploaderUrl == null) return null;
    final uri = Uri.tryParse(uploaderUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final channelIndex = uri.pathSegments.indexOf('channel');
      if (channelIndex != -1 && channelIndex + 1 < uri.pathSegments.length) {
        return uri.pathSegments[channelIndex + 1];
      }
    }
    return null;
  }
}
