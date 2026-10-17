class Department {
  final int id;
  final String name;

  Department({
    required this.id,
    required this.name,
  });

  factory Department.fromApi(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['department_name'],
    );
  }
}
