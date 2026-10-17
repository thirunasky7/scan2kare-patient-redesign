import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../utils/token_storage.dart';
import '../doctors_screen.dart';
import '../../config/api_config.dart';

/// Deep-link entry: /view-hospital-details/:code
class HospitalDetailsScreen extends StatefulWidget {
  final String code;

  const HospitalDetailsScreen({super.key, required this.code});

  @override
  State<HospitalDetailsScreen> createState() => _HospitalDetailsScreenState();
}

class _HospitalDetailsScreenState extends State<HospitalDetailsScreen> {
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

      if (response.statusCode != 200 ||
          response.data?['data']?['hospital'] == null) {
        throw Exception('Hospital not found');
      }

      final hospital = response.data['data']['hospital'];
      final hospitalIdInt = int.tryParse(widget.code) ?? 0;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DoctorListScreen(
            hospitalId: hospitalIdInt,
            hospitalIdString: widget.code,
            hospitalName:
                hospital['hospital_name']?.toString() ?? 'Hospital',
            hospitalAddress:
                hospital['address']?.toString() ?? 'Address not available',
            fromDeepLink: true,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data?['message']?.toString() ??
            e.message ??
            'Failed to load hospital';
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
        appBar: AppBar(title: const Text('Hospital')),
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
