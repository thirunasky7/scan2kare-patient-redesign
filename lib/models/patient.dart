class Patient {
  final int id;
  final String name;
  final String phone;
  final String relationship;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
    );
  }
}
