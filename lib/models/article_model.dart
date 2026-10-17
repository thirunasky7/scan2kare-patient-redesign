class Article {
  final int id;
  final String title;
  final String description;
  final String image;
  final String author;
  final String date;
  final int categoryId;
   final String? categoryName;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.author,
    required this.date,
    required this.categoryId,
    this.categoryName,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['short_description'] ?? '',
      image: 'https://scan2kare.com/public/storage/blogs/FGZpkrpWosDUJnOWfnCdMVWpCd7qeM8Fjs9Qu1se.webp',
      author: json['author_name'] ?? '',
      date: json['published_date'] ?? '',
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category']?['category_name'],
    );
  }
}
