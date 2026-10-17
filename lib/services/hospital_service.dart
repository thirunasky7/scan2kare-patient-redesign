import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/hospitals.dart';
import '../models/doctor.dart';
import '../models/doctor_api_response.dart';
import '../models/hospital_type.dart';
import '../utils/token_storage.dart';

class HospitalService {
  static String get baseUrl => ApiConfig.baseUrl;
  static final Dio dio = Dio();

  /// ================= FETCH HOSPITALS =================
  static Future<List<HospitalItem>> fetchHospitals({
    String? search,
    bool all = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception("Token is missing");
    }

    var url = '$baseUrl/home-hospital-lists';
    final params = <String>[];
    if (all) params.add('all=1');
    if (search != null && search.isNotEmpty) {
      params.add('search=${Uri.encodeComponent(search)}');
    }
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception("API failed with status: ${response.statusCode}");
    }

    final decoded = jsonDecode(response.body);
    final List list = decoded['data']['hospitals'] ?? [];

    return list.map((e) => HospitalItem.fromJson(e)).toList();
  }

  /// ================= FETCH NEARBY HOSPITALS =================
  static Future<List<HospitalItem>> fetchNearbyHospitals(
      double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception("Authentication token missing");
    }

    final response = await http.post(
      Uri.parse('$baseUrl/favroite-hospitals'),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    if (response.statusCode == 401) {
      await TokenStorage.clearTokens();
      throw Exception("Session expired");
    }

    if (response.statusCode != 200) {
      throw Exception("API failed: ${response.body}");
    }

    final decoded = jsonDecode(response.body);

    if (decoded['data'] is List) {
      return (decoded['data'] as List)
          .map((e) => HospitalItem.fromJson(e))
          .toList();
    } else {
      throw Exception("Invalid response format");
    }
  }

  /// ================= FETCH DOCTORS =================
  static Future<DoctorApiResponse> fetchDoctorsWithMeta(
      dynamic hospitalId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception("Token is missing");
    }

    final response = await http.get(
      Uri.parse('$baseUrl/hospital-detail/$hospitalId'),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load doctors');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'];

    final Map<int, String> specializationMap = {};
    if (data['specializations'] != null) {
      for (var s in data['specializations']) {
        final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
        final name = (s['name'] ?? s['specialization_name'] ?? '')
            .toString()
            .trim();
        if (id > 0 && name.isNotEmpty) {
          specializationMap[id] = name;
        }
      }
    }

    final Map<int, String> departmentsMap = {};
    if (data['departments'] != null) {
      for (var d in data['departments']) {
        departmentsMap[d['id']] = d['department_name'];
      }
    }

    List<Doctor> doctors = [];
    if (data['doctors_list'] != null) {
      doctors = (data['doctors_list'] as List)
          .map((e) => Doctor.fromApi(e, specializationMap))
          .toList();
    }

    return DoctorApiResponse(
      doctors: doctors,
      departments: departmentsMap,
      specializations: specializationMap,
    );
  }

  static Future<AvailableSlotsResult> getAvailableTimeSlots({
    required int doctorId,
    required int hospitalId,
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception("Token is missing");
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final url = '$baseUrl/doctors/$doctorId/available-slots';

    final response = await Dio().get(
      url,
      queryParameters: {
        'date': formattedDate,
        'hospital_id': hospitalId,
      },
      options: Options(
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final slotsRaw = data['slots'];
      final slots = slotsRaw is List
          ? slotsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final isHoliday = data['is_holiday'] == true;
      final message = (data['message'] ?? '').toString().trim();

      return AvailableSlotsResult(
        slots: slots,
        isHoliday: isHoliday,
        message: message.isEmpty ? null : message,
      );
    } else {
      throw Exception("Failed to fetch slots");
    }
  }

  /// Approved doctor holiday dates (yyyy-MM-dd) for the next ~3 months.
  /// Tries public holiday-dates first (same style as available-slots), then
  /// authenticated patient endpoint as fallback.
  static Future<Set<String>> fetchDoctorHolidayDates(int doctorId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final urls = <String>[
      '$baseUrl/doctors/$doctorId/holiday-dates',
      '$baseUrl/patient/doctors/$doctorId/holiday-dates',
    ];

    for (final url in urls) {
      try {
        final headers = <String, dynamic>{
          "Accept": "application/json",
        };
        if (token != null && token.isNotEmpty) {
          headers["Authorization"] = "Bearer $token";
        }

        final response = await Dio().get(
          url,
          options: Options(
            headers: headers,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode != 200) continue;

        final parsed = _parseHolidayDatesPayload(response.data);
        if (parsed.isNotEmpty) return parsed;

        // Empty list can be valid (no holidays) — trust a successful 200.
        if (response.data is Map &&
            ((response.data as Map)['status'] == true ||
                (response.data as Map).containsKey('dates'))) {
          return parsed;
        }
      } catch (e) {
        // try next url
      }
    }

    return <String>{};
  }

  static Set<String> _parseHolidayDatesPayload(dynamic raw) {
    if (raw is! Map) return <String>{};
    final data = Map<String, dynamic>.from(raw);

    final datesRaw = data['dates'];
    if (datesRaw is List) {
      return datesRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e.length >= 10 ? e.substring(0, 10) : e)
          .toSet();
    }

    final leaves = data['leaves'];
    if (leaves is! List) return <String>{};

    final dates = <String>{};
    for (final item in leaves) {
      if (item is! Map) continue;
      final status =
          (item['status'] ?? 'approved').toString().toLowerCase().trim();
      if (status.isNotEmpty && status != 'approved') continue;
      final leaveDate = (item['leave_date'] ?? '').toString().trim();
      if (leaveDate.isNotEmpty) {
        dates.add(
            leaveDate.length >= 10 ? leaveDate.substring(0, 10) : leaveDate);
      }
    }
    return dates;
  }

  /// ================= HOSPITAL TYPES =================
  static Future<List<HospitalType>> fetchHospitalTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/health-hub/hospital-types'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final List data = jsonData['data'];
      return data.map((e) => HospitalType.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load hospital types');
    }
  }

  static Future<List<HospitalItem>> fetchHospitalsByType(
      String type, String lat, String lng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      throw Exception('Authentication token missing');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/health-hub/hospitals'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'type': type,
              'latitude': lat,
              'longitude': lng,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Check if data exists and is a list
        if (jsonData['data'] != null && jsonData['data'] is List) {
          List<HospitalItem> hospitals = [];

          for (var item in jsonData['data']) {
            try {
              // Create HospitalItem from the API response
              HospitalItem hospital = HospitalItem(
                id: item['id'] ?? 0,
                name: item['hospital_name'] ?? 'Unknown Hospital',
                address: item['address'] ?? 'Address not available',
                profileImage: item['profile_image'] ??
                    item['hospital_image'] ??
                    'https://scan2kare.com/public/assets/images/defaultt-icons.png',
                image: item['hospital_image'] ??
                    item['hospital_image'] ??
                    'https://scan2kare.com/public/assets/images/defaultt-icons.png',
                rating: 4.0, // Default rating since not in response
                reviews: 0, // Default reviews since not in response
                distance: item['distance']?.toDouble() ?? 0.0,
                time: _calculateTimeFromDistance(
                    item['distance']?.toDouble() ?? 0.0),
                type: item['hospital_type'] ?? type,
                latitude:
                    double.tryParse(item['latitude']?.toString() ?? '0') ?? 0,
                longitude:
                    double.tryParse(item['longitude']?.toString() ?? '0') ?? 0,
              );
              hospitals.add(hospital);
            } catch (e) {
              // print('❌ Error parsing hospital item: $e');
            }
          }

          //print('✅ Successfully parsed ${hospitals.length} hospitals');
          return hospitals;
        }

        return [];
      } else if (response.statusCode == 401) {
        await TokenStorage.clearTokens();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
            'Failed to load hospitals. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // print('❌ Error in fetchHospitalsByType: $e');
      return [];
    }
  }

  /// ================= DEEP LINK DETAIL FETCH =================
  static Future<Map<String, dynamic>> fetchHospitalDetailById(
      String hospitalId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token missing');
    }

    final response = await dio.get(
      '$baseUrl/hospital-detail/$hospitalId',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode != 200 || response.data?['data'] == null) {
      throw Exception('Failed to load hospital details');
    }

    final data = response.data['data'];
    final hospital = data['hospital'] ?? data;

    final Map<int, String> specializationMap = {};
    if (data['specializations'] != null) {
      for (var s in data['specializations']) {
        final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
        final name = (s['name'] ?? s['specialization_name'] ?? '')
            .toString()
            .trim();
        if (id > 0 && name.isNotEmpty) {
          specializationMap[id] = name;
        }
      }
    }

    final List<Map<String, dynamic>> doctors = [];
    if (data['doctors_list'] != null) {
      for (var doctor in data['doctors_list']) {
        final rawSpec = (doctor['specialization'] ?? '').toString().trim();
        final specId = int.tryParse(
              doctor['specialization_id']?.toString() ?? '',
            ) ??
            int.tryParse(rawSpec) ??
            0;
        String specialty = '';
        if (rawSpec.isNotEmpty && int.tryParse(rawSpec) == null) {
          specialty = rawSpec;
        }
        if (specialty.isEmpty && specId > 0) {
          specialty = specializationMap[specId] ?? '';
        }
        if (specialty.isEmpty) {
          specialty = 'General';
        }
        doctors.add({
          'name': doctor['doctor_name']?.toString() ??
              doctor['name']?.toString() ??
              'Unknown Doctor',
          'specialty': specialty,
          'location': doctor['location']?.toString(),
          'language': doctor['language']?.toString(),
        });
      }
    }

    return {
      'name': hospital['hospital_name']?.toString() ??
          hospital['name']?.toString() ??
          'Hospital',
      'phone': hospital['phone']?.toString() ??
          hospital['contact_number']?.toString() ??
          'Phone not available',
      'address': hospital['address']?.toString() ?? 'Address not available',
      'doctors': doctors,
    };
  }

  static Future<Map<String, dynamic>> fetchDoctorDetailById(
      String doctorId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token missing');
    }

    final response = await dio.get(
      '$baseUrl/doctor-detail/$doctorId',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode != 200 || response.data?['data'] == null) {
      throw Exception('Failed to load doctor details');
    }

    final data = response.data['data'];
    final doctorData = data['doctor'] ?? data;

    if (doctorData == null) {
      throw Exception('Doctor data not found');
    }

    final Map<int, String> specializationMap = {};
    if (data['specializations'] != null) {
      for (var s in data['specializations']) {
        final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
        final name = (s['name'] ?? s['specialization_name'] ?? '')
            .toString()
            .trim();
        if (id > 0 && name.isNotEmpty) {
          specializationMap[id] = name;
        }
      }
    }

    final doctor = Doctor.fromApi(doctorData, specializationMap);

    String hospitalName = 'Hospital';
    String hospitalAddress = 'Address not available';
    int hospitalId = 0;

    if (doctorData['hospital_name'] != null) {
      hospitalName = doctorData['hospital_name'].toString();
    } else if (doctorData['hospital'] != null) {
      final hospital = doctorData['hospital'];
      hospitalName = hospital['name']?.toString() ?? hospitalName;
      hospitalAddress = hospital['address']?.toString() ?? hospitalAddress;
      hospitalId = int.tryParse(hospital['id']?.toString() ?? '0') ?? 0;
    }

    if (doctorData['hospital_address'] != null) {
      hospitalAddress = doctorData['hospital_address'].toString();
    }

    if (doctorData['hospital_id'] != null) {
      hospitalId = int.tryParse(doctorData['hospital_id'].toString()) ?? 0;
    }

    final weekDates = _parseScheduleList(data['weekDates']);
    final availableDays = _parseScheduleList(data['available_days']);

    return {
      'doctor': doctor,
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'hospitalId': hospitalId,
      'weekDates': weekDates,
      'available_days': availableDays,
    };
  }

  /// Parses weekDates / available_days from doctor-detail API.
  static List<Map<String, dynamic>> _parseScheduleList(dynamic raw) {
    if (raw is! List) return [];
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        list.add(Map<String, dynamic>.from(item));
      }
    }
    return list;
  }

// Helper method to estimate time based on distance
  static String _calculateTimeFromDistance(double distance) {
    // Assuming average speed of 30 km/h in city
    double timeInHours = distance / 30;
    double timeInMinutes = timeInHours * 60;

    if (timeInMinutes < 1) {
      return 'Less than 1 min';
    } else if (timeInMinutes < 60) {
      return '${timeInMinutes.round()} mins';
    } else {
      int hours = (timeInMinutes / 60).floor();
      int minutes = (timeInMinutes % 60).round();
      return '$hours hr $minutes mins';
    }
  }
}

class AvailableSlotsResult {
  final List<String> slots;
  final bool isHoliday;
  final String? message;

  const AvailableSlotsResult({
    required this.slots,
    this.isHoliday = false,
    this.message,
  });
}
