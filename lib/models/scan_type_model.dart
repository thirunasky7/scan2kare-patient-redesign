class ScanType {
  final int id;
  final String name;
  final String description;
  final String category;

  ScanType({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
  });

  factory ScanType.fromJson(Map<String, dynamic> json) {
    return ScanType(
      id: int.tryParse('${json['id']}') ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
    );
  }
}
