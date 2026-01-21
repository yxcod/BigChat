class FriendInfoModel {
  String? userName;
  String? nickName;
  String? remarks;
  String? avatar;
  String? signature;
  bool? isOnline;
  FriendInfoModel({
    required this.userName,
    required this.nickName,
    required this.remarks,
    required this.avatar,
    required this.signature,
    required this.isOnline,
  });
  factory FriendInfoModel.formJSON(Map<String, dynamic> json) {
    return FriendInfoModel(
      userName: json["userName"] ?? "",
      nickName: json["nickName"] ?? "",
      remarks: json["remark"] ?? "",
      avatar: json["avatar"] ?? "",
      signature: json["signature"] ?? "",
      isOnline: json["onlineStatus"] ?? false,
    );
  }
}
