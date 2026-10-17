import 'package:flutter/material.dart';
import 'appointment_screen.dart';
import '../models/doctor.dart';
import '../services/hospital_service.dart';
import '../services/favorites_service.dart';
import '../utils/deeplink_nav.dart';
import '../widgets/favorite_button.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Doctor doctor;
  final String hospitalName;
  final String hospitalAddress;
  final int hospitalId;
  /// True when opened via App Link / QR URL (back → Home).
  final bool fromDeepLink;

  const DoctorProfileScreen({
    super.key,
    required this.doctor,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.hospitalId,
    this.fromDeepLink = false,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  List<Map<String, dynamic>> _workingDays = [];
  bool _loadingSchedule = true;
  late Doctor _doctor;
  late String _hospitalName;
  late String _hospitalAddress;
  late int _hospitalId;
  late int _experienceYears;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _hospitalName = widget.hospitalName;
    _hospitalAddress = widget.hospitalAddress;
    _hospitalId = widget.hospitalId;
    _experienceYears = widget.doctor.experienceYears;
    _loadWorkingSchedule();
  }

  Future<void> _loadWorkingSchedule() async {
    try {
      final detail = await HospitalService.fetchDoctorDetailById(
        widget.doctor.id.toString(),
      );

      final available =
          (detail['available_days'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      final weekDates =
          (detail['weekDates'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Prefer available_days; else week days marked available.
      final days = available.isNotEmpty
          ? available
          : weekDates
              .where((d) =>
                  d['is_available'] == 1 ||
                  d['is_available'] == true ||
                  d['is_available']?.toString() == '1')
              .toList();

      // Always refresh profile fields from doctor-detail (favourites may be stale).
      final detailDoctor = detail['doctor'];
      final refreshed = detailDoctor is Doctor ? detailDoctor : _doctor;
      final hospitalName = (detail['hospitalName'] as String?)?.trim();
      final hospitalAddress = (detail['hospitalAddress'] as String?)?.trim();
      final hospitalId = detail['hospitalId'] as int?;

      if (!mounted) return;
      setState(() {
        _doctor = refreshed;
        if (hospitalName != null && hospitalName.isNotEmpty) {
          _hospitalName = hospitalName;
        }
        if (hospitalAddress != null && hospitalAddress.isNotEmpty) {
          _hospitalAddress = hospitalAddress;
        }
        if (hospitalId != null && hospitalId > 0) {
          _hospitalId = hospitalId;
        }
        _experienceYears = refreshed.experienceYears;
        _workingDays = days;
        _loadingSchedule = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workingDays = [];
        _loadingSchedule = false;
      });
    }
  }

  String _dayLabel(Map<String, dynamic> day) {
    final full = day['day_of_week']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;
    final short = day['day_name']?.toString().trim();
    if (short != null && short.isNotEmpty) return short;
    return day['display']?.toString() ?? 'Day';
  }

  String _timeLabel(Map<String, dynamic> day) {
    final display = day['time_display']?.toString().trim();
    if (display != null && display.isNotEmpty) return display;

    final start = day['start_time']?.toString();
    final end = day['end_time']?.toString();
    if (start != null &&
        start.isNotEmpty &&
        end != null &&
        end.isNotEmpty) {
      return '$start - $end';
    }
    return 'Time not available';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.fromDeepLink,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.fromDeepLink) {
          handleDetailBack(context, fromDeepLink: true);
        }
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            handleDetailBack(context, fromDeepLink: widget.fromDeepLink);
          },
        ),
        centerTitle: true,
        title: Text(
          _hospitalName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          FavoriteButton(
            type: FavoritesService.doctor,
            id: _doctor.id,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            snapshot: {
              'id': _doctor.id,
              'name': _doctor.name,
              'image': _doctor.imagePath,
              'qualification': _doctor.specialization,
              'hospital_name': _hospitalName,
              'phone': _doctor.phone,
              'patient_count': _doctor.patient_count,
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _hospitalAddress,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _doctor.imagePath,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/logo-icon.png',
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _doctor.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _doctor.specialization,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (_doctor.phone.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.phone,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _doctor.phone,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statItem(Icons.group,
                          _doctor.patient_count.toString(), 'patients'),
                      const SizedBox(width: 48),
                      _statItem(Icons.work,
                          _experienceText(_experienceYears), ''),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Working Time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildWorkingTimeSection(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B6F71),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentDateTimeScreen(
                        doctorId: _doctor.id,
                        hospitalId: _hospitalId,
                        doctorName: _doctor.name,
                        doctorAddress: _hospitalAddress,
                        hospitalName: _hospitalName,
                        doctorImage: _doctor.imagePath,
                        hospitalPhone: _doctor.phone),
                  ),
                );
              },
              child: const Text(
                'Book Now',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          )
        ],
      ),
    ),
    );
  }

  Widget _buildWorkingTimeSection() {
    if (_loadingSchedule) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_workingDays.isEmpty) {
      return const Text(
        'Schedule not available',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _workingDays.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _dayLabel(_workingDays[i]),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _timeLabel(_workingDays[i]),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _experienceText(int years) {
    final y = years > 0 ? years : 1;
    return y == 1 ? '1 year' : '$y years';
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFEFF3FF),
          child: Icon(icon, color: const Color(0xFF1F3C88)),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
