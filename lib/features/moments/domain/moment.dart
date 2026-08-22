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
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
    final visibilityName = json['visibility']?.toString();
    final visibility = MomentVisibility.values.firstWhere(
      (value) => value.name == visibilityName,
      orElse: () => MomentVisibility.public,
    );
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
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
