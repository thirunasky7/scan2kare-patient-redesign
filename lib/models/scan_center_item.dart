class StaticHospital {
  final int id;
  final String name;
  final String address;
  final String image;
  final String type;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviews;
  final double distance;
  final String time;
  final String profileImage;

  const StaticHospital({
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

  factory StaticHospital.fromJson(Map<String, dynamic> json) {
    return StaticHospital(
      id: json['id'],
      name: json['hospital_name'] ?? '',
      address: json['address'] ?? '',
      image: json['hospital_image'] ??
          'https://scan2kare.com/public/app-images/hospital-default.png',
      profileImage: json['profile_image'] ??
          'https://scan2kare.com/public/app-images/hospital-default.png',
      type: json['hospital_type'] ?? '',
      latitude: double.tryParse(json['latitude'].toString()) ?? 0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0,
      rating: 4.5,
      reviews: 0,
      distance: double.tryParse(json['distance'].toString()) ?? 0,
      time: '',
    );
  }
}
