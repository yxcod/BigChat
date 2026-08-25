class NearbyPlace {
  const NearbyPlace({
    required this.name,
    this.address = '',
    this.distanceMeters,
  });

  final String name;
  final String address;
  final int? distanceMeters;
}

class NearbyPlacesResult {
  const NearbyPlacesResult({required this.currentCity, required this.places});

  final String currentCity;
  final List<NearbyPlace> places;
}
