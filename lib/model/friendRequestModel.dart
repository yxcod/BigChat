import '../core/parsing/json_value_parser.dart';

enum RequestStatus { pending, accepted, rejected, expired }

enum FriendRequestDirection { incoming, outgoing }

class FriendRequestModel {
  int? requestId;
  String? userName;
  String? nickName;
  String? fromUserId;
  String? toUserId;
  String? verificationMessage;
  DateTime? requestTime;
  RequestStatus? status;
  FriendRequestDirection direction;

  FriendRequestModel({
    required this.requestId,
    required this.userName,
    required this.nickName,
    this.fromUserId,
    this.toUserId,
    required this.verificationMessage,
    required this.requestTime,
    this.status = RequestStatus.pending,
    this.direction = FriendRequestDirection.incoming,
  });

  bool get isIncoming => direction == FriendRequestDirection.incoming;
  bool get canRespond => isIncoming && status == RequestStatus.pending;

  factory FriendRequestModel.fromJSON(
    Map<String, dynamic> json, {
    String currentUserName = '',
  }) {
    final fromUserId = JsonValueParser.stringValue(json['fromUserId']);
    final toUserId = JsonValueParser.stringValue(json['toUserId']);
    final explicitDirection = JsonValueParser.stringValue(json['direction']);
    final incoming =
        explicitDirection == 'incoming' ||
        (explicitDirection.isEmpty && toUserId == currentUserName);
    final statusValue = JsonValueParser.intValue(json['status']);
    final status = switch (statusValue) {
      1 => RequestStatus.accepted,
      2 => RequestStatus.rejected,
      6 => RequestStatus.expired,
      _ => RequestStatus.pending,
    };
    final counterpartUserName = JsonValueParser.stringValue(
      json['userName'],
      fallback: incoming ? fromUserId : toUserId,
    );
    final counterpartNickname = JsonValueParser.stringValue(
      json['nickName'],
      fallback: incoming
          ? JsonValueParser.stringValue(json['fromNickName'])
          : JsonValueParser.stringValue(json['toNickName']),
    );
    return FriendRequestModel(
      requestId: JsonValueParser.intValue(json["id"]),
      userName: counterpartUserName,
      nickName: counterpartNickname,
      fromUserId: fromUserId,
      toUserId: toUserId,
      verificationMessage: JsonValueParser.stringValue(json["applyMsg"]),
      requestTime: json["createTime"] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              JsonValueParser.timestampMillis(json["createTime"]),
            )
          : DateTime.now(),
      status: status,
      direction: incoming
          ? FriendRequestDirection.incoming
          : FriendRequestDirection.outgoing,
    );
  }
}

class RecentFriendModel {
  int? requestId;
  String? userName;
  String? nickName;
  int? addTime;
  String? remarks;
  String? verificationMessage;
  RequestStatus status;
  FriendRequestDirection direction;

  RecentFriendModel({
    this.requestId,
    required this.userName,
    required this.nickName,
    required this.addTime,
    this.remarks,
    this.verificationMessage,
    this.status = RequestStatus.accepted,
    this.direction = FriendRequestDirection.incoming,
  });

  bool get isIncoming => direction == FriendRequestDirection.incoming;

  String get eventKey => '${requestId ?? 0}:${status.name}:${addTime ?? 0}';

  factory RecentFriendModel.fromJSON(
    Map<String, dynamic> json, {
    String currentUserName = '',
  }) {
    final toUserId = JsonValueParser.stringValue(json['toUserId']);
    final explicitDirection = JsonValueParser.stringValue(json['direction']);
    final incoming =
        explicitDirection == 'incoming' ||
        (explicitDirection.isEmpty && toUserId == currentUserName);
    final status = switch (JsonValueParser.intValue(json['status'])) {
      2 => RequestStatus.rejected,
      6 => RequestStatus.expired,
      0 => RequestStatus.pending,
      _ => RequestStatus.accepted,
    };
    return RecentFriendModel(
      requestId: JsonValueParser.intValue(json['id']),
      userName: JsonValueParser.stringValue(json["userName"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      addTime: JsonValueParser.timestampMillis(
        json["updateTime"] ?? json["addTime"],
        fallback: DateTime.now().millisecondsSinceEpoch,
      ),
      remarks: JsonValueParser.stringValue(json["remarks"]),
      verificationMessage: JsonValueParser.stringValue(json['applyMsg']),
      status: status,
      direction: incoming
          ? FriendRequestDirection.incoming
          : FriendRequestDirection.outgoing,
    );
  }
}
