class Doctor {
  final int id;
  final String name;
  final int departmentId;
  final String department;
  final int specializationId;
  final String specialization;
  final double rating;
  final String imagePath;
  final String description;
  final int patient_count;
  final int experienceYears;
  final String phone;

  Doctor({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.department,
    required this.specializationId,
    required this.specialization,
    required this.rating,
    required this.imagePath,
    required this.description,
    required this.patient_count,
    this.experienceYears = 1,
    this.phone = '',
  });

  factory Doctor.fromApi(
    Map<String, dynamic> json,
    Map<int, String> specializationMap,
  ) {
    final rawSpec = (json['specialization'] ?? '').toString().trim();
    final int specId = int.tryParse(
          json['specialization_id']?.toString() ?? '',
        ) ??
        int.tryParse(rawSpec) ??
        0;

    // Prefer API-resolved name; fall back to map / alternate keys.
    String specializationName = '';
    if (rawSpec.isNotEmpty && int.tryParse(rawSpec) == null) {
      specializationName = rawSpec;
    }
    if (specializationName.isEmpty && specId > 0) {
      specializationName = specializationMap[specId] ?? '';
    }
    if (specializationName.isEmpty) {
      specializationName = (json['specialization_name'] ??
              json['specialty'] ??
              '')
          .toString()
          .trim();
    }
    if (specializationName.isEmpty) {
      specializationName = 'General';
    }

    final experienceYears = _parseExperienceYears(
      json['experience_years'] ?? json['experience'],
    );

    // Patient-facing contact: hospital number (not the doctor's personal phone).
    final nestedHospital =
        json['hospital'] is Map ? Map<String, dynamic>.from(json['hospital'] as Map) : null;
    final phone = [
      json['hospital_phone'],
      nestedHospital?['mobile_no'],
      nestedHospital?['phone'],
      nestedHospital?['contact_number'],
    ]
        .map((raw) => raw?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return Doctor(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['doctor_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown Doctor',
      departmentId: int.tryParse(json['department_id']?.toString() ?? '0') ?? 0,
      department: (json['department_name'] ?? '').toString().trim().isNotEmpty
          ? json['department_name'].toString().trim()
          : 'General',
      specializationId: specId,
      specialization: specializationName,
      rating: double.tryParse(json['rating']?.toString() ?? '4.5') ?? 4.5,
      imagePath: json['profile_image']?.toString() ??
          'assets/logo-icon.png',
      description: json['description']?.toString() ?? '',
      patient_count:
          int.tryParse(json['patient_count']?.toString() ?? '0') ?? 0,
      experienceYears: experienceYears,
      phone: phone,
    );
  }

  static int _parseExperienceYears(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value > 0 ? value : 1;
    if (value is num) {
      final years = value.toInt();
      return years > 0 ? years : 1;
    }
    final parsed = int.tryParse(value.toString().trim());
    return (parsed != null && parsed > 0) ? parsed : 1;
  }
}
