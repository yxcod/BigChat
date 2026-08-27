class NearbyMerchant {
  const NearbyMerchant({
    required this.id,
    required this.name,
    this.address = '',
    this.category = '',
    this.distanceMeters,
    this.rating,
    this.imageUrl = '',
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
  final double? latitude;
  final double? longitude;
}

class NearbyMerchantsResult {
  const NearbyMerchantsResult({
    required this.currentCity,
    required this.merchants,
  });

  final String currentCity;
  final List<NearbyMerchant> merchants;
}
