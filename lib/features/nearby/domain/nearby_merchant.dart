class NearbyMerchant {
  const NearbyMerchant({
    required this.id,
    required this.name,
    this.address = '',
    this.category = '',
    this.distanceMeters,
    this.rating,
    this.imageUrl = '',
    this.imageUrls = const [],
    this.phone = '',
    this.openingHours = '',
    this.price,
    this.detailUrl = '',
    this.imageCount = 0,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final String category;
  final int? distanceMeters;
  final double? rating;
  final String imageUrl;
  final List<String> imageUrls;
  final String phone;
  final String openingHours;
  final double? price;
  final String detailUrl;
  final int imageCount;
  final double? latitude;
  final double? longitude;

  List<String> get availableImageUrls {
    final values = <String>{};
    if (imageUrl.trim().isNotEmpty) values.add(imageUrl.trim());
    values.addAll(
      imageUrls.map((item) => item.trim()).where((item) => item.isNotEmpty),
    );
    return List<String>.unmodifiable(values);
  }
}

class NearbyMerchantsResult {
  const NearbyMerchantsResult({
    required this.currentCity,
    required this.merchants,
  });

  final String currentCity;
  final List<NearbyMerchant> merchants;
}
