import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_banner.dart';

class BannerService {
  static const String home = 'home';
  static const String healthHub = 'health_hub';

  static Future<List<AppBanner>> fetchBanners(String placement) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/banners')
        .replace(queryParameters: {'placement': placement});

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return [];

    final data = decoded['data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((e) => AppBanner.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => b.image.isNotEmpty)
        .toList();
  }
}
