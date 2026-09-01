enum GroupResourceType { file, album }

class GroupResource {
  const GroupResource({
    required this.id,
    required this.groupId,
    required this.type,
    required this.originalName,
    required this.mimeType,
    required this.fileSize,
    required this.uploaderId,
    required this.createdAt,
    required this.canDelete,
    this.localPath,
  });

  final int id;
  final int groupId;
  final GroupResourceType type;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final String uploaderId;
  final DateTime createdAt;
  final bool canDelete;
  final String? localPath;

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');

  factory GroupResource.fromJson(Map<String, dynamic> json) {
    int intValue(Object? value) => value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    final timestamp = intValue(json['createdAt']);
    return GroupResource(
      id: intValue(json['resourceId']),
      groupId: intValue(json['groupId']),
      type: intValue(json['resourceType']) == 2
          ? GroupResourceType.album
          : GroupResourceType.file,
      originalName: json['originalName']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
      fileSize: intValue(json['fileSize']),
      uploaderId: json['uploaderId']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      canDelete: json['canDelete'] == true,
      localPath: json['localPath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'resourceId': id,
    'groupId': groupId,
    'resourceType': type == GroupResourceType.file ? 1 : 2,
    'originalName': originalName,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'uploaderId': uploaderId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'canDelete': canDelete,
    if (localPath?.isNotEmpty == true) 'localPath': localPath,
  };

  GroupResource copyWith({String? localPath}) => GroupResource(
    id: id,
    groupId: groupId,
    type: type,
    originalName: originalName,
    mimeType: mimeType,
    fileSize: fileSize,
    uploaderId: uploaderId,
    createdAt: createdAt,
    canDelete: canDelete,
    localPath: localPath ?? this.localPath,
  );
}
