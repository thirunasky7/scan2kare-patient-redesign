import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article_model.dart';
import '../models/category_model.dart';
import '../models/video_category_model.dart';
import '../models/video_model.dart';
import '../config/api_config.dart';

class HealthHubService {
  static String get baseUrl => '${ApiConfig.baseUrl}/health-hub';

  /// Get token from storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  /// Fetch Articles + Categories
  static Future<Map<String, dynamic>> fetchData() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$baseUrl/articles"),
      headers: {"Accept": "application/json", "Authorization": "Bearer $token"},
    );

    if (response.statusCode != 200) {
      throw Exception("API Error ${response.statusCode}");
    }

    final decoded = jsonDecode(response.body);

    final articles = (decoded['data']['blogs']['data'] as List)
        .map((e) => Article.fromJson(e))
        .toList();

    final categories = (decoded['data']['categories'] as List)
        .map((e) => BlogCategory.fromJson(e))
        .toList();

    return {"articles": articles, "categories": categories};
  }

  /// Fetch Categories Only
  static Future<List<BlogCategory>> getCategories() async {
    final token = await getToken();

    final res = await http.get(
      Uri.parse("$baseUrl/blog-categories"),
      headers: {"Accept": "application/json", "Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load categories");
    }

    final data = jsonDecode(res.body);

    return (data['data'] as List).map((e) => BlogCategory.fromJson(e)).toList();
  }

  // Add to existing HealthHubService class

  /// Fetch Video Categories
  static Future<List<VideoCategory>> getVideoCategories() async {
    final token = await getToken();

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/video-categories"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode != 200) {
        // print("Video Categories API Error: ${response.statusCode}");
        // print("Response body: ${response.body}");
        throw Exception("Failed to load video categories");
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] == true && decoded['data'] != null) {
        return (decoded['data'] as List)
            .map((e) => VideoCategory.fromJson(e))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      // print("Error fetching video categories: $e");
      return [];
    }
  }

  /// Fetch Videos
  static Future<Map<String, dynamic>> fetchVideos(
      {int? categoryId, int page = 1}) async {
    final token = await getToken();

    try {
      String url = "$baseUrl/videos?page=$page";
      if (categoryId != null && categoryId > 0) {
        url += "&category_id=$categoryId";
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token"
        },
      );

      if (response.statusCode != 200) {
        //print("Videos API Error: ${response.statusCode}");
        // print("Response body: ${response.body}");
        throw Exception("Failed to load videos");
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] == true && decoded['data'] != null) {
        final videosData = decoded['data']['videos'];
        final categoriesData = decoded['data']['categories'];

        List<Video> videos = [];
        if (videosData['data'] != null) {
          videos = (videosData['data'] as List)
              .map((e) => Video.fromJson(e))
              .toList();
        }

        List<VideoCategory> categories = [];
        if (categoriesData != null) {
          categories = (categoriesData as List)
              .map((e) => VideoCategory.fromJson(e))
              .toList();
        }

        return {
          "videos": videos,
          "categories": categories,
          "currentPage": videosData['current_page'] ?? 1,
          "lastPage": videosData['last_page'] ?? 1,
          "total": videosData['total'] ?? 0,
        };
      } else {
        return {
          "videos": [],
          "categories": [],
          "currentPage": 1,
          "lastPage": 1,
          "total": 0,
        };
      }
    } catch (e) {
      // print("Error fetching videos: $e");
      return {
        "videos": [],
        "categories": [],
        "currentPage": 1,
        "lastPage": 1,
        "total": 0,
      };
    }
  }
}
