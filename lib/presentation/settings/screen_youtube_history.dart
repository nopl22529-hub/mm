import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxtube/application/application.dart';
import 'package:fluxtube/domain/auth/models/youtube_history_item.dart';
import 'package:fluxtube/domain/watch/models/basic_info.dart';
import 'package:fluxtube/infrastructure/auth/innertube_auth_impl.dart';
import 'package:go_router/go_router.dart';

/// The signed-in account's real YouTube watch history (FEhistory),
/// as opposed to FluxTube's local on-device history.
class YoutubeHistoryScreen extends StatefulWidget {
  const YoutubeHistoryScreen({super.key});

  @override
  State<YoutubeHistoryScreen> createState() => _YoutubeHistoryScreenState();
}

class _YoutubeHistoryScreenState extends State<YoutubeHistoryScreen> {
  late Future<List<YoutubeHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = InnertubeAuthImpl().fetchHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = InnertubeAuthImpl().fetchHistory();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube history')),
      body: FutureBuilder<List<YoutubeHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your YouTube history.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final items = snapshot.data ?? const <YoutubeHistoryItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Text('No watch history on this YouTube account.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: item.thumbnailUrl == null
                      ? const SizedBox(
                          width: 96,
                          height: 54,
                          child: Icon(Icons.smart_display_outlined),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.thumbnailUrl!,
                            width: 96,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 96,
                              height: 54,
                              child: Icon(Icons.smart_display_outlined),
                            ),
                          ),
                        ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (item.channelName != null) item.channelName!,
                      if (item.viewsText != null) item.viewsText!,
                      if (item.publishedText != null) item.publishedText!,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: item.durationText == null
                      ? null
                      : Text(item.durationText!),
                  onTap: () {
                    BlocProvider.of<WatchBloc>(context).add(
                      WatchEvent.setSelectedVideoBasicDetails(
                        details: VideoBasicInfo(
                          id: item.videoId,
                          title: item.title,
                          thumbnailUrl: item.thumbnailUrl ?? '',
                          channelName: item.channelName ?? '',
                          channelId: item.channelId ?? '',
                        ),
                      ),
                    );
                    context.pushNamed(
                      'watch',
                      pathParameters: {
                        'videoId': item.videoId,
                        'channelId': item.channelId ?? '',
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
