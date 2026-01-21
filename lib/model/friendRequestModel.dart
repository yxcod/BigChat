enum RequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  int? requestId;
  String? userName;
  String? nickName;
  String? verificationMessage;
  DateTime? requestTime;
  RequestStatus? status;

  FriendRequestModel({
    required this.requestId,
    required this.userName,
    required this.nickName,
    required this.verificationMessage,
    required this.requestTime,
    this.status = RequestStatus.pending,
  });

  factory FriendRequestModel.fromJSON(Map<String, dynamic> json) {
    return FriendRequestModel(
      requestId: json["id"] ?? 0,
      userName: json["fromUserId"] ?? "",
      nickName: json["nickName"] ?? "",
      verificationMessage: json["applyMsg"] ?? "",
      requestTime: json["createTime"] != null
          ? DateTime.fromMillisecondsSinceEpoch(json["createTime"])
          : DateTime.now(),
    );
  }
}

class RecentFriendModel {
  String? userName;
  String? nickName;
  int? addTime;
  String? remarks;

  RecentFriendModel({
    required this.userName,
    required this.nickName,
    required this.addTime,
    this.remarks,
  });

  factory RecentFriendModel.fromJSON(Map<String, dynamic> json) {
    return RecentFriendModel(
      userName: json["userName"] ?? "",
      nickName: json["nickName"] ?? "",
      addTime: json["addTime"] ?? DateTime.now().millisecondsSinceEpoch,
      remarks: json["remarks"] ?? "",
    );
  }
}
