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
