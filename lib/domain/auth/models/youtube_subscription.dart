/// One channel the signed-in account is subscribed to on YouTube,
/// parsed from Innertube responses (`browse` FEchannels or `guide`).
class YoutubeSubscription {
  const YoutubeSubscription({
    required this.channelId,
    required this.title,
    this.avatarUrl,
  });

  final String channelId;
  final String title;
  final String? avatarUrl;

  /// Parses a `browse` FEchannels response: channel renderers with
  /// a channelId, title, and thumbnail, wherever they sit in the
  /// section tree.
  static List<YoutubeSubscription> fromChannelsFeedResponse(
    Map<String, dynamic> json,
  ) {
    final found = <String, YoutubeSubscription>{};

    void visit(Object? node) {
      if (node is Map<String, dynamic>) {
        for (final key in const ['channelRenderer', 'gridChannelRenderer']) {
          final renderer = node[key];
          if (renderer is Map<String, dynamic>) {
            final channelId = renderer['channelId'];
            if (channelId is String && channelId.startsWith('UC')) {
              found[channelId] = YoutubeSubscription(
                channelId: channelId,
                title: _textOf(renderer['title']) ?? channelId,
                avatarUrl: _thumbnailOf(renderer['thumbnail']),
              );
            }
          }
        }

        // Newer FEchannels layout: channels as lockups.
        final lockup = node['lockupViewModel'];
        if (lockup is Map<String, dynamic>) {
          final contentId = lockup['contentId'];
          final contentType = lockup['contentType'];
          if (contentId is String &&
              contentId.startsWith('UC') &&
              (contentType == null ||
                  contentType.toString().contains('CHANNEL'))) {
            String? title;
            final metadata = lockup['metadata'];
            if (metadata is Map<String, dynamic>) {
              final meta = metadata['lockupMetadataViewModel'];
              if (meta is Map<String, dynamic>) {
                title = _textOf(meta['title']);
              }
            }
            found[contentId] = YoutubeSubscription(
              channelId: contentId,
              title: title ?? contentId,
              avatarUrl: _lockupAvatar(lockup),
            );
          }
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
    return found.values.toList();
  }

  /// Parses a `guide` response: guide entries whose browse endpoint
  /// points at a channel.
  static List<YoutubeSubscription> fromGuideResponse(
    Map<String, dynamic> json,
  ) {
    final found = <String, YoutubeSubscription>{};

    void visit(Object? node) {
      if (node is Map<String, dynamic>) {
        final entry = node['guideEntryRenderer'];
        if (entry is Map<String, dynamic>) {
          final endpoint = entry['navigationEndpoint'];
          if (endpoint is Map<String, dynamic>) {
            final browse = endpoint['browseEndpoint'];
            if (browse is Map<String, dynamic>) {
              final browseId = browse['browseId'];
              if (browseId is String && browseId.startsWith('UC')) {
                found[browseId] = YoutubeSubscription(
                  channelId: browseId,
                  title: _textOf(entry['formattedTitle']) ?? browseId,
                  avatarUrl: _thumbnailOf(entry['thumbnail']),
                );
              }
            }
          }
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
    return found.values.toList();
  }

  static String? _textOf(Object? node) {
    if (node is String) return node;
    if (node is Map<String, dynamic>) {
      final content = node['content'];
      if (content is String) return content;
      final simple = node['simpleText'];
      if (simple is String) return simple;
      final runs = node['runs'];
      if (runs is List) {
        final buffer = StringBuffer();
        for (final run in runs) {
          if (run is Map<String, dynamic> && run['text'] is String) {
            buffer.write(run['text']);
          }
        }
        if (buffer.isNotEmpty) return buffer.toString();
      }
    }
    return null;
  }

  static String? _lockupAvatar(Map<String, dynamic> lockup) {
    final image = lockup['contentImage'];
    if (image is Map<String, dynamic>) {
      for (final key in const ['avatarViewModel', 'thumbnailViewModel']) {
        final viewModel = image[key];
        if (viewModel is Map<String, dynamic>) {
          final inner = viewModel['image'];
          final url = _thumbnailOf(inner) ?? _sourcesOf(inner);
          if (url != null) return url;
        }
      }
    }
    return null;
  }

  static String? _sourcesOf(Object? node) {
    if (node is Map<String, dynamic>) {
      final sources = node['sources'];
      if (sources is List && sources.isNotEmpty) {
        final last = sources.last;
        if (last is Map<String, dynamic> && last['url'] is String) {
          var url = last['url'] as String;
          if (url.startsWith('//')) url = 'https:$url';
          return url;
        }
      }
    }
    return null;
  }

  static String? _thumbnailOf(Object? node) {
    if (node is Map<String, dynamic>) {
      final thumbs = node['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        final last = thumbs.last;
        if (last is Map<String, dynamic> && last['url'] is String) {
          var url = last['url'] as String;
          if (url.startsWith('//')) url = 'https:$url';
          return url;
        }
      }
    }
    return null;
  }
}
