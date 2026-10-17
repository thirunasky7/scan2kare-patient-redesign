class HospitalItem {
  final int id;
  final String name;
  final String address;
  final String image;
  final String type;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviews;
  final double distance; // keep double
  final String time;
  final String profileImage;

  const HospitalItem({
    required this.id,
    required this.name,
    required this.address,
    required this.image,
    required this.type,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.profileImage,
  });

  factory HospitalItem.fromJson(Map<String, dynamic> json) {
    final double dist =
        double.tryParse(json['distance']?.toString() ?? '2.5') ?? 2.5;

    return HospitalItem(
      id: json['id'] ?? 0,
      name: json['hospital_name'] ?? 'Unknown Hospital',
      address: json['address'] ?? 'Address not available',
      image: json['hospital_image'] ??
          'https://scan2kare.com/public/app-images/hospital-default.png',
      type: json['hospital_type'] ?? 'Multi specialty',
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString()) ?? 4.5
          : 4.5,
      reviews: json['reviews'] ?? 50,
      distance: dist,
      time: "${(dist / 40 * 60).round()} min",
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      profileImage: json['profile_image'] ??
          'https://scan2kare.com/public/app-images/hospital-default.png',
    );
  }
}
