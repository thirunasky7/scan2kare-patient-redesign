import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../utils/token_storage.dart';
import '../scan_categories_screen.dart';
import '../../config/api_config.dart';

/// Deep-link entry: /view-diagnostic-center-detail/:code
class DiagnosticCenterScreen extends StatefulWidget {
  final String code;

  const DiagnosticCenterScreen({super.key, required this.code});

  @override
  State<DiagnosticCenterScreen> createState() => _DiagnosticCenterScreenState();
}

class _DiagnosticCenterScreenState extends State<DiagnosticCenterScreen> {
  final Dio _dio = Dio();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await _dio.get(
        "${ApiConfig.baseUrl}/hospital-detail/${widget.code}",
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode != 200 || response.data?['data'] == null) {
        throw Exception('Diagnostic center not found');
      }

      final centerData =
          response.data['data']['hospital'] ?? response.data['data'];
      final centerId =
          int.tryParse(centerData['id']?.toString() ?? widget.code) ?? 0;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScanCategoriesScreen(
            centerId: centerId,
            centerName: centerData['hospital_name']?.toString() ??
                centerData['name']?.toString() ??
                'Diagnostic Center',
            centerAddress: centerData['address']?.toString() ??
                'Address not available',
            fromDeepLink: true,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data?['message']?.toString() ??
            e.message ??
            'Failed to load diagnostic center';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic Center')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
