import 'video_category_model.dart';

class Video {
  int? id;
  String? title;
  String? youtubeUrl;
  String? youtubeVideoId;
  String? thumbnail;
  String? authorName;
  String? publishedDate;
  String? status;
  VideoCategory? category;
  String? createdAt;

  Video({
    this.id,
    this.title,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.thumbnail,
    this.authorName,
    this.publishedDate,
    this.status,
    this.category,
    this.createdAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    // Extract YouTube video ID if not provided
    String? videoId = json['youtube_video_id'];

    // If video ID is not provided but URL is, extract from URL
    if ((videoId == null || videoId.isEmpty) && json['youtube_url'] != null) {
      videoId = _extractYoutubeId(json['youtube_url']);
      print('Extracted video ID from URL in model: $videoId');
    }

    return Video(
      id: json['id'],
      title: json['title'],
      youtubeUrl: json['youtube_url'],
      youtubeVideoId: videoId,
      thumbnail: json['thumbnail'] ??
          (videoId != null
              ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
              : null),
      authorName: json['author_name'],
      publishedDate: json['published_date'],
      status: json['status'],
      category: json['category'] != null
          ? VideoCategory(
              id: json['category']['id'],
              categoryName: json['category']['name'],
            )
          : null,
      createdAt: json['created_at'],
    );
  }

  static String? _extractYoutubeId(String url) {
    if (url.isEmpty) return null;

    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }
}
