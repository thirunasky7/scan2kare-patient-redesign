import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/opinion_model.dart';

class OpinionService {
  static String get url => '${ApiConfig.baseUrl}/health-hub/opinions/submit';

  static Future<bool> submitOpinion(
      {required String firstName,
      required String phone,
      required String email,
      required String address,
      String? category,
      String? network,
      String? notes,
      File? report}) async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse(url));

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        "first_name": firstName,
        "phone": phone,
        "email": email,
        "address": address,
        if (category != null && category.trim().isNotEmpty)
          "category": category,
        if (network != null && network.trim().isNotEmpty) "network": network,
        if (notes != null && notes.trim().isNotEmpty) "notes": notes,
      });

      if (report != null) {
        request.files
            .add(await http.MultipartFile.fromPath('report', report.path));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw Exception('Server Error: $responseBody');
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Opinion>> fetchOpinions() async {
    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final response = await dio.get(
      '${ApiConfig.baseUrl}/health-hub/opinions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      final List data = response.data['data'];
      return data.map((e) => Opinion.fromJson(e)).toList();
    }
    throw Exception('Failed to load opinions');
  }
}
