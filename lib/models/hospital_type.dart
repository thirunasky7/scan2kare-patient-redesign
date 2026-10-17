class HospitalType {
  final int id;
  final String name;
  final String slug;
  final String image;
  final int hospitalsCount;

  HospitalType({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.hospitalsCount,
  });

  factory HospitalType.fromJson(Map<String, dynamic> json) {
    return HospitalType(
      id: json['id'] ?? 0, // Provide default value if null
      name: json['name']?.toString() ?? 'Unknown', // Handle null with default
      slug: json['slug']?.toString() ?? 'unknown',
      image: json['image']?.toString() ??
          'https://scan2kare.com/public/app-images/hospital-default.png', // Default image
      hospitalsCount: json['hospitals_count'] ?? 0,
    );
  }
}
