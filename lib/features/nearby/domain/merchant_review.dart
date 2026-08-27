import 'nearby_merchant.dart';

enum MerchantReviewReaction { none, like, dislike }

class MerchantReviewComment {
  const MerchantReviewComment({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MerchantReviewComment.fromJson(Map<String, dynamic> json) {
    return MerchantReviewComment(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class MerchantReview {
  const MerchantReview({
    required this.merchant,
    required this.addedAt,
    this.likes = 0,
    this.dislikes = 0,
    this.reaction = MerchantReviewReaction.none,
    this.comments = const [],
  });

  final NearbyMerchant merchant;
  final DateTime addedAt;
  final int likes;
  final int dislikes;
  final MerchantReviewReaction reaction;
  final List<MerchantReviewComment> comments;

  MerchantReview copyWith({
    NearbyMerchant? merchant,
    DateTime? addedAt,
    int? likes,
    int? dislikes,
    MerchantReviewReaction? reaction,
    List<MerchantReviewComment>? comments,
  }) {
    return MerchantReview(
      merchant: merchant ?? this.merchant,
      addedAt: addedAt ?? this.addedAt,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      reaction: reaction ?? this.reaction,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toJson() => {
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
      merchant: _merchantFromJson(
        Map<String, dynamic>.from(json['merchant'] as Map? ?? const {}),
      ),
      addedAt:
          DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
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
