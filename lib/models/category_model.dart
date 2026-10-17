class BlogCategory {
  final int id;
  final String name;

  BlogCategory({
    required this.id,
    required this.name,
  });

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    return BlogCategory(
      id: json['id'],
      name: json['category_name'],
    );
  }
}
