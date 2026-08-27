class SpaceGuestbookMessage {
  const SpaceGuestbookMessage({
    required this.id,
    required this.ownerUserName,
    required this.authorUserName,
    required this.authorNickName,
    required this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String ownerUserName;
  final String authorUserName;
  final String authorNickName;
  final String authorAvatarUrl;
  final String content;
  final DateTime createdAt;
}

class UserSpaceData {
  const UserSpaceData({
    required this.ownerUserName,
    required this.isOwner,
    this.coverImageUrl = '',
    this.messages = const [],
  });

  final String ownerUserName;
  final bool isOwner;
  final String coverImageUrl;
  final List<SpaceGuestbookMessage> messages;

  UserSpaceData copyWith({
    String? coverImageUrl,
    List<SpaceGuestbookMessage>? messages,
  }) {
    return UserSpaceData(
      ownerUserName: ownerUserName,
      isOwner: isOwner,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      messages: messages ?? this.messages,
    );
  }
}
