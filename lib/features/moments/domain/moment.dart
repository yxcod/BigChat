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

  Moment copyWith({
    int? likeCount,
    bool? isLiked,
    List<MomentComment>? comments,
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
  };

  factory Moment.fromJson(Map<String, dynamic> json) {
    final visibility = _parseMomentVisibility(json['visibility']);
    final rawComments = json['comments'];
    final rawMediaPaths = json['mediaPaths'];
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
    );
  }
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
    required this.visibility,
    this.location,
  });

  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String content;
  final List<String> mediaPaths;
  final MomentVisibility visibility;
  final String? location;
}
