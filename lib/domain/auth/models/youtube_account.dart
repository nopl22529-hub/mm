/// The signed-in user's YouTube channel, as returned by the YouTube
/// Data API `channels.list?mine=true` call made with the OAuth access
/// token from the TV device flow.
///
/// This is the account that Innertube actions (like, subscribe,
/// comment, history — later phases) will act as.
class YoutubeAccount {
  const YoutubeAccount({
    required this.channelId,
    required this.title,
    this.handle,
    this.avatarUrl,
  });

  final String channelId;
  final String title;

  /// Channel handle including the leading `@`, when YouTube returns one.
  final String? handle;
  final String? avatarUrl;

  /// Parses one item of a `channels.list` response.
  factory YoutubeAccount.fromChannelItem(Map<String, dynamic> item) {
    final snippet = item['snippet'] as Map<String, dynamic>? ?? const {};
    final thumbnails =
        snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
    final defaultThumb =
        thumbnails['default'] as Map<String, dynamic>? ?? const {};
    return YoutubeAccount(
      channelId: item['id'] as String? ?? '',
      title: snippet['title'] as String? ?? '',
      handle: snippet['customUrl'] as String?,
      avatarUrl: defaultThumb['url'] as String?,
    );
  }

  /// Parses an Innertube `account/accounts_list` response (TV client,
  /// the same call YouTube.js `account.getInfo()` makes for OAuth
  /// sessions). Returns null when no account item is present.
  ///
  /// The response is deeply nested renderers, so this searches the
  /// tree for the first `accountItemRenderer` instead of depending on
  /// one exact path that YouTube can rearrange.
  static YoutubeAccount? fromAccountsListResponse(Map<String, dynamic> json) {
    final renderer = _findRenderer(json, 'accountItemRenderer');
    if (renderer == null) return null;

    final title = _textOf(renderer['accountName']) ?? '';
    final handle = _textOf(renderer['channelHandle']);
    final photo = renderer['accountPhoto'] as Map<String, dynamic>?;
    final thumbs = photo?['thumbnails'] as List<dynamic>? ?? const [];
    String? avatarUrl;
    if (thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map<String, dynamic>) avatarUrl = last['url'] as String?;
    }

    return YoutubeAccount(
      channelId: _findChannelId(renderer) ?? '',
      title: title,
      handle: (handle == null || handle.isEmpty) ? null : handle,
      avatarUrl: avatarUrl,
    );
  }

  static Map<String, dynamic>? _findRenderer(Object? node, String key) {
    if (node is Map<String, dynamic>) {
      final value = node[key];
      if (value is Map<String, dynamic>) return value;
      for (final child in node.values) {
        final found = _findRenderer(child, key);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final child in node) {
        final found = _findRenderer(child, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _findChannelId(Object? node) {
    if (node is Map<String, dynamic>) {
      final browseId = node['browseId'];
      if (browseId is String && browseId.startsWith('UC')) return browseId;
      for (final child in node.values) {
        final found = _findChannelId(child);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final child in node) {
        final found = _findChannelId(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Innertube text objects are either `{simpleText: ...}` or
  /// `{runs: [{text: ...}, ...]}`.
  static String? _textOf(Object? node) {
    if (node is Map<String, dynamic>) {
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
        final text = buffer.toString();
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'title': title,
    'handle': handle,
    'avatarUrl': avatarUrl,
  };

  factory YoutubeAccount.fromJson(Map<String, dynamic> json) {
    return YoutubeAccount(
      channelId: json['channelId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is YoutubeAccount &&
      other.channelId == channelId &&
      other.title == title &&
      other.handle == handle &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(channelId, title, handle, avatarUrl);
}
