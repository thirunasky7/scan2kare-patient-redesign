import 'scan_type_model.dart';

class ScanCategory {
  final int id;
  final String title;
  final String description;
  final int totalTests;
  final List<ScanType> scanTypes;

  ScanCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.totalTests,
    this.scanTypes = const [],
  });

  factory ScanCategory.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['scan_types'];
    final scanTypes = rawTypes is List
        ? rawTypes
            .whereType<Map>()
            .map((e) => ScanType.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ScanType>[];

    return ScanCategory(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      totalTests: json['totalTests'] ?? 0,
      scanTypes: scanTypes,
    );
  }
}
