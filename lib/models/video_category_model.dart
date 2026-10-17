class VideoCategory {
  int? id;
  String? categoryName;
  String? slug;
  bool? status;
  String? createdAt;
  String? updatedAt;
  int? healthVideosCount;

  VideoCategory({
    this.id,
    this.categoryName,
    this.slug,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.healthVideosCount,
  });

  factory VideoCategory.fromJson(Map<String, dynamic> json) {
    return VideoCategory(
      id: json['id'],
      categoryName: json['category_name'],
      slug: json['slug'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      healthVideosCount: json['health_videos_count'],
    );
  }
}
