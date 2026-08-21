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
