enum MomentVisibility { public, friendsOnly, private }

class MomentComment {
  const MomentComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MomentComment.fromJson(Map<String, dynamic> json) {
    return MomentComment(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseMomentDateTime(json['createdAt']),
    );
  }
}

class Moment {
  const Moment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.mediaPaths,
    required this.createdAt,
    required this.visibility,
    required this.location,
    required this.likeCount,
    required this.isLiked,
    required this.comments,
    this.mediaThumbnails = const {},
    this.localMediaPaths = const {},
    this.localThumbnailPaths = const {},
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final List<String> mediaPaths;
  final DateTime createdAt;
  final MomentVisibility visibility;
  final String? location;
  final int likeCount;
  final bool isLiked;
  final List<MomentComment> comments;
  final Map<String, String> mediaThumbnails;
  final Map<String, String> localMediaPaths;
  final Map<String, String> localThumbnailPaths;

  Moment copyWith({
    int? likeCount,
    bool? isLiked,
    List<MomentComment>? comments,
    Map<String, String>? mediaThumbnails,
    Map<String, String>? localMediaPaths,
    Map<String, String>? localThumbnailPaths,
  }) {
    return Moment(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      mediaPaths: mediaPaths,
      createdAt: createdAt,
      visibility: visibility,
      location: location,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      comments: comments ?? this.comments,
      mediaThumbnails: mediaThumbnails ?? this.mediaThumbnails,
      localMediaPaths: localMediaPaths ?? this.localMediaPaths,
      localThumbnailPaths: localThumbnailPaths ?? this.localThumbnailPaths,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatarUrl': authorAvatarUrl,
    'content': content,
    'mediaPaths': mediaPaths,
    'createdAt': createdAt.toIso8601String(),
    'visibility': visibility.name,
    'location': location,
    'likeCount': likeCount,
    'isLiked': isLiked,
    'comments': comments.map((comment) => comment.toJson()).toList(),
    if (mediaThumbnails.isNotEmpty) 'mediaThumbnails': mediaThumbnails,
    if (localMediaPaths.isNotEmpty) 'localMediaPaths': localMediaPaths,
    if (localThumbnailPaths.isNotEmpty)
      'localThumbnailPaths': localThumbnailPaths,
  };

  factory Moment.fromJson(Map<String, dynamic> json) {
    final visibility = _parseMomentVisibility(json['visibility']);
    final rawComments = json['comments'];
    final rawMediaPaths = json['mediaPaths'];
    final rawMediaItems = json['mediaItems'];
    final mediaThumbnails = <String, String>{};
    if (rawMediaItems is List) {
      for (final rawItem in rawMediaItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final url = item['url']?.toString() ?? '';
        final thumbnailUrl = item['thumbnailUrl']?.toString() ?? '';
        if (url.isNotEmpty && thumbnailUrl.isNotEmpty) {
          mediaThumbnails[url] = thumbnailUrl;
        }
      }
    }
    mediaThumbnails.addAll(_parseStringMap(json['mediaThumbnails']));
    return Moment(
      id: json['id']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      authorAvatarUrl: json['authorAvatarUrl']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mediaPaths: rawMediaPaths is List
          ? rawMediaPaths.map((path) => path.toString()).toList()
          : const [],
      createdAt: _parseMomentDateTime(json['createdAt']),
      visibility: visibility,
      location: json['location']?.toString(),
      likeCount: json['likeCount'] is num
          ? (json['likeCount'] as num).toInt()
          : int.tryParse(json['likeCount']?.toString() ?? '') ?? 0,
      isLiked: json['isLiked'] == true,
      comments: rawComments is List
          ? rawComments
                .whereType<Map>()
                .map(
                  (comment) => MomentComment.fromJson(
                    Map<String, dynamic>.from(comment),
                  ),
                )
                .toList()
          : const [],
      mediaThumbnails: Map<String, String>.unmodifiable(mediaThumbnails),
      localMediaPaths: _parseStringMap(json['localMediaPaths']),
      localThumbnailPaths: _parseStringMap(json['localThumbnailPaths']),
    );
  }
}

Map<String, String> _parseStringMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, String>.unmodifiable({
    for (final entry in value.entries)
      if (entry.key.toString().isNotEmpty && entry.value.toString().isNotEmpty)
        entry.key.toString(): entry.value.toString(),
  });
}

DateTime _parseMomentDateTime(Object? value) {
  if (value is num) {
    final raw = value.toInt();
    final milliseconds = raw.abs() < 100000000000 ? raw * 1000 : raw;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  final text = value?.toString() ?? '';
  final numeric = int.tryParse(text);
  if (numeric != null) return _parseMomentDateTime(numeric);
  return DateTime.tryParse(text) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

MomentVisibility _parseMomentVisibility(Object? value) {
  final index = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (index != null && index >= 0 && index < MomentVisibility.values.length) {
    return MomentVisibility.values[index];
  }
  final name = value?.toString();
  return MomentVisibility.values.firstWhere(
    (visibility) => visibility.name == name,
    orElse: () => MomentVisibility.public,
  );
}

class MomentDraft {
  const MomentDraft({
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.content,
    required this.mediaPaths,
    this.mediaThumbnailUrls = const {},
    this.localMediaPaths = const {},
    this.localThumbnailPaths = const {},
    required this.visibility,
    this.location,
  });

  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final List<String> mediaPaths;
  final Map<String, String> mediaThumbnailUrls;
  final Map<String, String> localMediaPaths;
  final Map<String, String> localThumbnailPaths;
  final MomentVisibility visibility;
  final String? location;
}
