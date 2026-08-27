import 'nearby_merchant.dart';

enum MerchantReviewReaction { none, like, dislike }

class MerchantReviewComment {
  const MerchantReviewComment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId = '',
    this.displayName = '',
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

  factory MerchantReviewComment.fromJson(Map<String, dynamic> json) {
    return MerchantReviewComment(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _asDateTime(json['createdAt']),
    );
  }
}

class MerchantReview {
  const MerchantReview({
    required this.merchant,
    required this.addedAt,
    this.entryId = '',
    this.ownerUserName = '',
    this.likes = 0,
    this.dislikes = 0,
    this.reaction = MerchantReviewReaction.none,
    this.comments = const [],
  });

  final NearbyMerchant merchant;
  final DateTime addedAt;
  final String entryId;
  final String ownerUserName;
  final int likes;
  final int dislikes;
  final MerchantReviewReaction reaction;
  final List<MerchantReviewComment> comments;

  MerchantReview copyWith({
    NearbyMerchant? merchant,
    DateTime? addedAt,
    String? entryId,
    String? ownerUserName,
    int? likes,
    int? dislikes,
    MerchantReviewReaction? reaction,
    List<MerchantReviewComment>? comments,
  }) {
    return MerchantReview(
      merchant: merchant ?? this.merchant,
      addedAt: addedAt ?? this.addedAt,
      entryId: entryId ?? this.entryId,
      ownerUserName: ownerUserName ?? this.ownerUserName,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      reaction: reaction ?? this.reaction,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'ownerUserName': ownerUserName,
    'merchant': _merchantToJson(merchant),
    'addedAt': addedAt.toIso8601String(),
    'likes': likes,
    'dislikes': dislikes,
    'reaction': reaction.name,
    'comments': comments.map((item) => item.toJson()).toList(),
  };

  factory MerchantReview.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'];
    final reactionName = json['reaction']?.toString();
    return MerchantReview(
      entryId: json['entryId']?.toString() ?? '',
      ownerUserName: json['ownerUserName']?.toString() ?? '',
      merchant: _merchantFromJson(
        Map<String, dynamic>.from(json['merchant'] as Map? ?? const {}),
      ),
      addedAt: _asDateTime(json['addedAt'], fallback: DateTime.now()),
      likes: _asInt(json['likes']),
      dislikes: _asInt(json['dislikes']),
      reaction: MerchantReviewReaction.values.firstWhere(
        (item) => item.name == reactionName,
        orElse: () => MerchantReviewReaction.none,
      ),
      comments: rawComments is List
          ? rawComments
                .whereType<Map>()
                .map(
                  (item) => MerchantReviewComment.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

List<MerchantReview> sortMerchantReviews(Iterable<MerchantReview> source) {
  final result = source.toList(growable: false);
  result.sort((left, right) {
    final likes = right.likes.compareTo(left.likes);
    if (likes != 0) return likes;

    final dislikes = left.dislikes.compareTo(right.dislikes);
    if (dislikes != 0) return dislikes;

    final comments = right.comments.length.compareTo(left.comments.length);
    if (comments != 0) return comments;
    return right.addedAt.compareTo(left.addedAt);
  });
  return result;
}

Map<String, dynamic> _merchantToJson(NearbyMerchant merchant) => {
  'id': merchant.id,
  'name': merchant.name,
  'address': merchant.address,
  'category': merchant.category,
  'distanceMeters': merchant.distanceMeters,
  'rating': merchant.rating,
  'imageUrl': merchant.imageUrl,
  'imageUrls': merchant.imageUrls,
  'phone': merchant.phone,
  'openingHours': merchant.openingHours,
  'price': merchant.price,
  'detailUrl': merchant.detailUrl,
  'imageCount': merchant.imageCount,
  'latitude': merchant.latitude,
  'longitude': merchant.longitude,
};

NearbyMerchant _merchantFromJson(Map<String, dynamic> json) => NearbyMerchant(
  id: json['id']?.toString() ?? '',
  name: json['name']?.toString() ?? '',
  address: json['address']?.toString() ?? '',
  category: json['category']?.toString() ?? '',
  distanceMeters: _asNullableInt(json['distanceMeters']),
  rating: _asNullableDouble(json['rating']),
  imageUrl: json['imageUrl']?.toString() ?? '',
  imageUrls: (json['imageUrls'] as List? ?? const [])
      .map((item) => item.toString())
      .toList(growable: false),
  phone: json['phone']?.toString() ?? '',
  openingHours: json['openingHours']?.toString() ?? '',
  price: _asNullableDouble(json['price']),
  detailUrl: json['detailUrl']?.toString() ?? '',
  imageCount: _asInt(json['imageCount']),
  latitude: _asNullableDouble(json['latitude']),
  longitude: _asNullableDouble(json['longitude']),
);

int _asInt(dynamic value) => value is num ? value.toInt() : 0;

int? _asNullableInt(dynamic value) => value is num ? value.toInt() : null;

double? _asNullableDouble(dynamic value) =>
    value is num ? value.toDouble() : null;

DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final raw = value?.toString() ?? '';
  final millis = int.tryParse(raw);
  if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime.tryParse(raw) ??
      fallback ??
      DateTime.fromMillisecondsSinceEpoch(0);
}
