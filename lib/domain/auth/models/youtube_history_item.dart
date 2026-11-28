/// One video from the signed-in account's YouTube watch history,
/// parsed from an Innertube `browse` FEhistory response.
class YoutubeHistoryItem {
  const YoutubeHistoryItem({
    required this.videoId,
    required this.title,
    this.channelName,
    this.channelId,
    this.thumbnailUrl,
    this.viewsText,
    this.publishedText,
    this.durationText,
  });

  final String videoId;
  final String title;
  final String? channelName;
  final String? channelId;
  final String? thumbnailUrl;
  final String? viewsText;
  final String? publishedText;
  final String? durationText;

  /// Parses FEhistory responses across layouts: classic
  /// `videoRenderer`, newer `lockupViewModel`, and TV
  /// `tileRenderer`. Order is preserved, duplicates dropped.
  static List<YoutubeHistoryItem> fromHistoryResponse(
    Map<String, dynamic> json,
  ) {
    final items = <YoutubeHistoryItem>[];
    final seen = <String>{};

    void add(YoutubeHistoryItem item) {
      if (item.videoId.isNotEmpty && seen.add(item.videoId)) {
        items.add(item);
      }
    }

    void visit(Object? node) {
      if (node is Map<String, dynamic>) {
        final video = node['videoRenderer'] ?? node['compactVideoRenderer'];
        if (video is Map<String, dynamic>) {
          final videoId = video['videoId'];
          if (videoId is String) {
            add(
              YoutubeHistoryItem(
                videoId: videoId,
                title: _textOf(video['title']) ?? videoId,
                channelName: _textOf(video['ownerText']) ??
                    _textOf(video['longBylineText']),
                channelId: _browseIdOf(video['ownerText']) ??
                    _browseIdOf(video['longBylineText']),
                thumbnailUrl: _thumbnailOf(video['thumbnail']),
                viewsText: _textOf(video['viewCountText']) ??
                    _textOf(video['shortViewCountText']),
                publishedText: _textOf(video['publishedTimeText']),
                durationText: _textOf(video['lengthText']),
              ),
            );
          }
        }

        final lockup = node['lockupViewModel'];
        if (lockup is Map<String, dynamic>) {
          final contentId = lockup['contentId'];
          final contentType = lockup['contentType'];
          if (contentId is String &&
              (contentType == null ||
                  contentType.toString().contains('VIDEO'))) {
            final metadata = lockup['metadata'];
            String? title;
            String? channelName;
            String? channelId;
            if (metadata is Map<String, dynamic>) {
              final meta = metadata['lockupMetadataViewModel'];
              if (meta is Map<String, dynamic>) {
                title = _textOf(meta['title']);
                final rows = meta['metadata'];
                if (rows is Map<String, dynamic>) {
                  final contentMetadata = rows['contentMetadataViewModel'];
                  if (contentMetadata is Map<String, dynamic>) {
                    final metadataRows = contentMetadata['metadataRows'];
                    if (metadataRows is List && metadataRows.isNotEmpty) {
                      final first = metadataRows.first;
                      if (first is Map<String, dynamic>) {
                        final parts = first['metadataParts'];
                        if (parts is List && parts.isNotEmpty) {
                          final part = parts.first;
                          if (part is Map<String, dynamic>) {
                            channelName = _textOf(part['text']);
                            channelId = _browseIdOf(part['text']);
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            add(
              YoutubeHistoryItem(
                videoId: contentId,
                title: title ?? contentId,
                channelName: channelName,
                channelId: channelId,
                thumbnailUrl: _lockupThumbnail(lockup),
              ),
            );
          }
        }

        final tile = node['tileRenderer'];
        if (tile is Map<String, dynamic>) {
          final contentId = tile['contentId'];
          if (contentId is String && contentId.length == 11) {
            final metadata = tile['metadata'];
            String? title;
            String? channelName;
            if (metadata is Map<String, dynamic>) {
              final tileMeta = metadata['tileMetadataRenderer'];
              if (tileMeta is Map<String, dynamic>) {
                title = _textOf(tileMeta['title']);
                final lines = tileMeta['lines'];
                if (lines is List && lines.isNotEmpty) {
                  final first = lines.first;
                  if (first is Map<String, dynamic>) {
                    final renderer = first['lineRenderer'];
                    if (renderer is Map<String, dynamic>) {
                      final items = renderer['items'];
                      if (items is List && items.isNotEmpty) {
                        final item = items.first;
                        if (item is Map<String, dynamic>) {
                          final lineItem = item['lineItemRenderer'];
                          if (lineItem is Map<String, dynamic>) {
                            channelName = _textOf(lineItem['text']);
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
            add(
              YoutubeHistoryItem(
                videoId: contentId,
                title: title ?? contentId,
                channelName: channelName,
                thumbnailUrl: _tileThumbnail(tile),
              ),
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

    // Last resort for layouts none of the renderers above match:
    // any node carrying an 11-char videoId plus a title.
    if (items.isEmpty) {
      void scan(Object? node) {
        if (node is Map<String, dynamic>) {
          final videoId = node['videoId'];
          if (videoId is String && videoId.length == 11) {
            add(YoutubeHistoryItem(
              videoId: videoId,
              title: _textOf(node['title']) ?? videoId,
              channelName: _textOf(node['ownerText']) ??
                  _textOf(node['longBylineText']) ??
                  _textOf(node['shortBylineText']),
              channelId: _browseIdOf(node['ownerText']) ??
                  _browseIdOf(node['longBylineText']) ??
                  _browseIdOf(node['shortBylineText']),
              thumbnailUrl: _thumbnailOf(node['thumbnail']),
              viewsText: _textOf(node['viewCountText']) ??
                  _textOf(node['shortViewCountText']),
              publishedText: _textOf(node['publishedTimeText']),
              durationText: _textOf(node['lengthText']),
            ));
          }
          for (final child in node.values) {
            scan(child);
          }
        } else if (node is List) {
          for (final child in node) {
            scan(child);
          }
        }
      }

      scan(json);
    }

    return items;
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

  static String? _browseIdOf(Object? node) {
    if (node is Map<String, dynamic>) {
      final runs = node['runs'];
      if (runs is List) {
        for (final run in runs) {
          if (run is Map<String, dynamic>) {
            final endpoint = run['navigationEndpoint'];
            if (endpoint is Map<String, dynamic>) {
              final browse = endpoint['browseEndpoint'];
              if (browse is Map<String, dynamic>) {
                final browseId = browse['browseId'];
                if (browseId is String && browseId.startsWith('UC')) {
                  return browseId;
                }
              }
            }
          }
        }
      }
      final endpoint = node['navigationEndpoint'];
      if (endpoint is Map<String, dynamic>) {
        final browse = endpoint['browseEndpoint'];
        if (browse is Map<String, dynamic>) {
          final browseId = browse['browseId'];
          if (browseId is String && browseId.startsWith('UC')) {
            return browseId;
          }
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

  static String? _lockupThumbnail(Map<String, dynamic> lockup) {
    final image = lockup['contentImage'];
    if (image is Map<String, dynamic>) {
      final thumbnail = image['thumbnailViewModel'];
      if (thumbnail is Map<String, dynamic>) {
        final inner = thumbnail['image'];
        return _thumbnailOf(inner);
      }
    }
    return null;
  }

  static String? _tileThumbnail(Map<String, dynamic> tile) {
    final header = tile['header'];
    if (header is Map<String, dynamic>) {
      final tileHeader = header['tileHeaderRenderer'];
      if (tileHeader is Map<String, dynamic>) {
        return _thumbnailOf(tileHeader['thumbnail']);
      }
    }
    return null;
  }
}
