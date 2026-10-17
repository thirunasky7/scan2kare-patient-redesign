class Opinion {
  final int id;
  final String firstName;
  final String lastName;
  final String createdAt;

  Opinion({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
  });

  factory Opinion.fromJson(Map<String, dynamic> json) {
    return Opinion(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
