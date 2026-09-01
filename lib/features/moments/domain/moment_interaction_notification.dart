enum MomentInteractionType { like, comment }

class MomentInteractionNotification {
  const MomentInteractionNotification({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.actorAvatarUrl,
    required this.momentId,
    required this.type,
    required this.commentContent,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String actorUserId;
  final String actorName;
  final String actorAvatarUrl;
  final String momentId;
  final MomentInteractionType type;
  final String commentContent;
  final bool isRead;
  final DateTime createdAt;

  String get displayActorName =>
      actorName.trim().isEmpty ? actorUserId : actorName.trim();

  String get actionText =>
      type == MomentInteractionType.like ? '点赞了你的动态' : '评论了你的动态';

  MomentInteractionNotification copyWith({bool? isRead}) {
    return MomentInteractionNotification(
      id: id,
      actorUserId: actorUserId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      momentId: momentId,
      type: type,
      commentContent: commentContent,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationId': id,
    'actorUserId': actorUserId,
    'actorName': actorName,
    'actorAvatarUrl': actorAvatarUrl,
    'momentId': momentId,
    'interactionType': type.name,
    'commentContent': commentContent,
    'isRead': isRead,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory MomentInteractionNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['interactionType']?.toString();
    return MomentInteractionNotification(
      id: json['notificationId']?.toString() ?? '',
      actorUserId: json['actorUserId']?.toString() ?? '',
      actorName: json['actorName']?.toString() ?? '',
      actorAvatarUrl: json['actorAvatarUrl']?.toString() ?? '',
      momentId: json['momentId']?.toString() ?? '',
      type: rawType == 'comment'
          ? MomentInteractionType.comment
          : MomentInteractionType.like,
      commentContent: json['commentContent']?.toString() ?? '',
      isRead: json['isRead'] == true || json['isRead']?.toString() == '1',
      createdAt: _readDateTime(json['createdAt']),
    );
  }
}

DateTime _readDateTime(Object? value) {
  final numeric = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (numeric != null) {
    final milliseconds = numeric.abs() < 100000000000
        ? numeric * 1000
        : numeric;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
