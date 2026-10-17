import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/doctor.dart';
import '../../utils/token_storage.dart';
import '../doctor_profile_screen.dart';
import '../../config/api_config.dart';

/// Deep-link entry: /view-doctor-profile/:code
class DoctorProfileLoaderScreen extends StatefulWidget {
  final String code;

  const DoctorProfileLoaderScreen({super.key, required this.code});

  @override
  State<DoctorProfileLoaderScreen> createState() =>
      _DoctorProfileLoaderScreenState();
}

class _DoctorProfileLoaderScreenState extends State<DoctorProfileLoaderScreen> {
  final Dio _dio = Dio();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ctx = await _fetchDoctorContext(widget.code);
      if (!mounted || ctx == null) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DoctorProfileScreen(
            doctor: ctx.doctor,
            hospitalName: ctx.hospitalName,
            hospitalAddress: ctx.hospitalAddress,
            hospitalId: ctx.hospitalId,
            fromDeepLink: true,
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.response?.data?['message']?.toString() ??
            e.message ??
            'Failed to load doctor';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<_DoctorContext?> _fetchDoctorContext(String doctorId) async {
    final token = await TokenStorage.getToken();
    final response = await _dio.get(
      "${ApiConfig.baseUrl}/doctor-detail/$doctorId",
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode != 200 || response.data?['data'] == null) {
      throw Exception('Doctor not found');
    }

    final doctorData =
        response.data['data']['doctor'] ?? response.data['data'];
    if (doctorData == null) throw Exception('Doctor data not found');

    final Map<int, String> specializationMap = {};
    if (response.data['data']['specializations'] != null) {
      for (final s in response.data['data']['specializations']) {
        if (s != null) {
          final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
          final name = s['name']?.toString() ?? '';
          if (id > 0 && name.isNotEmpty) specializationMap[id] = name;
        }
      }
    }

    final doctor = Doctor.fromApi(doctorData, specializationMap);
    var hospitalName = 'Hospital';
    var hospitalAddress = 'Address not available';
    var hospitalId = 0;

    final topHospitalName = doctorData['hospital_name']?.toString().trim();
    if (topHospitalName != null && topHospitalName.isNotEmpty) {
      hospitalName = topHospitalName;
    }

    if (doctorData['hospital'] != null) {
      final hospital = doctorData['hospital'];
      final nestedName = (hospital['hospital_name'] ?? hospital['name'])
          ?.toString()
          .trim();
      if (nestedName != null && nestedName.isNotEmpty) {
        hospitalName = nestedName;
      }
      final nestedAddress = hospital['address']?.toString().trim();
      if (nestedAddress != null && nestedAddress.isNotEmpty) {
        hospitalAddress = nestedAddress;
      }
      hospitalId = int.tryParse(hospital['id']?.toString() ?? '0') ?? hospitalId;
    }
    if (doctorData['hospital_address'] != null) {
      final addr = doctorData['hospital_address'].toString().trim();
      if (addr.isNotEmpty) hospitalAddress = addr;
    }
    if (doctorData['hospital_id'] != null) {
      hospitalId =
          int.tryParse(doctorData['hospital_id'].toString()) ?? hospitalId;
    }

    return _DoctorContext(
      doctor: doctor,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      hospitalId: hospitalId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Doctor Profile')),
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

class _DoctorContext {
  final Doctor doctor;
  final String hospitalName;
  final String hospitalAddress;
  final int hospitalId;

  _DoctorContext({
    required this.doctor,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.hospitalId,
  });
}
