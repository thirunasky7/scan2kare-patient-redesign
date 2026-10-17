import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/hospitals.dart';
import '../models/patient.dart';
import '../services/emergency_service.dart';
import '../services/hospital_service.dart';
import 'my_bookings_screen.dart';
import '../widgets/fast_network_image.dart';

class EmergencyBookingScreen extends StatefulWidget {
  const EmergencyBookingScreen({super.key});

  @override
  State<EmergencyBookingScreen> createState() => _EmergencyBookingScreenState();
}

class _EmergencyBookingScreenState extends State<EmergencyBookingScreen> {
  // Soft, friendly reason categories with pastel color accents
  final List<Map<String, dynamic>> _reasons = [
    {
      'title': 'Accident / Injury',
      'subtitle': 'Fall, collision, cut',
      'icon': Icons.healing_rounded,
      'bg': const Color(0xFFFFE4E6),
      'color': const Color(0xFFE11D48),
    },
    {
      'title': 'Chest Pain',
      'subtitle': 'Pressure, discomfort',
      'icon': Icons.favorite_rounded,
      'bg': const Color(0xFFFEE2E2),
      'color': const Color(0xFFDC2626),
    },
    {
      'title': 'Breathing Issue',
      'subtitle': 'Asthma, shortness of breath',
      'icon': Icons.air_rounded,
      'bg': const Color(0xFFE0F2FE),
      'color': const Color(0xFF0284C7),
    },
    {
      'title': 'High Fever',
      'subtitle': 'Severe chills, body pain',
      'icon': Icons.thermostat_rounded,
      'bg': const Color(0xFFFEF3C7),
      'color': const Color(0xFFD97706),
    },
    {
      'title': 'Severe Bleeding',
      'subtitle': 'Uncontrolled wound',
      'icon': Icons.bloodtype_rounded,
      'bg': const Color(0xFFFCE7F3),
      'color': const Color(0xFFDB2777),
    },
    {
      'title': 'Other Crisis',
      'subtitle': 'Sudden severe illness',
      'icon': Icons.medical_services_rounded,
      'bg': const Color(0xFFF3E8FF),
      'color': const Color(0xFF9333EA),
    },
  ];

  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<HospitalItem> _hospitals = [];
  List<HospitalItem> _filteredHospitals = [];
  HospitalItem? _selectedHospital;
  bool _isLoadingHospitals = true;
  String? _hospitalError;

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _isLoadingPatients = true;

  bool _isSubmitting = false;
  Map<String, dynamic>? _bookingSuccessResult;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredHospitals = List.from(_hospitals);
      });
      return;
    }

    final q = query.toLowerCase();
    final localMatches = _hospitals.where((h) {
      final name = h.name.toLowerCase();
      final address = h.address.toLowerCase();
      final type = h.type.toLowerCase();
      return name.contains(q) || address.contains(q) || type.contains(q);
    }).toList();

    setState(() {
      _filteredHospitals = localMatches;
    });

    _performServerSearch(query);
  }

  Future<void> _performServerSearch(String query) async {
    try {
      final results = await HospitalService.fetchHospitals(search: query, all: true);
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          final Map<int, HospitalItem> map = {
            for (var h in _filteredHospitals) h.id: h
          };
          for (var h in results) {
            map[h.id] = h;
          }
          _filteredHospitals = map.values.toList();
          if (_selectedHospital != null &&
              !_filteredHospitals.any((h) => h.id == _selectedHospital!.id)) {
            _selectedHospital =
                _filteredHospitals.isNotEmpty ? _filteredHospitals.first : null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    _fetchHospitals();
    _fetchPatients();
  }

  Future<void> _fetchHospitals() async {
    setState(() {
      _isLoadingHospitals = true;
      _hospitalError = null;
    });

    try {
      final hospitals = await HospitalService.fetchHospitals(all: true);
      if (mounted) {
        setState(() {
          _hospitals = hospitals;
          _filteredHospitals = List.from(hospitals);
          _isLoadingHospitals = false;
          if (_hospitals.isNotEmpty) {
            _selectedHospital = _hospitals.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hospitalError = e.toString().replaceAll('Exception: ', '');
          _isLoadingHospitals = false;
        });
      }
    }
  }

  Future<void> _fetchPatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _isLoadingPatients = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/patient/family-profiles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['data'] != null) {
        List list = data['data'];
        if (mounted) {
          setState(() {
            _patients = list.map((e) => Patient.fromJson(e)).toList();
            if (_patients.isNotEmpty) {
              _selectedPatient = _patients.first;
            }
            _isLoadingPatients = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingPatients = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  Future<void> _submitEmergencyBooking() async {
    if (_selectedReason == null) {
      _showSnackbar('Please select an emergency condition.', isError: true);
      return;
    }

    if (_selectedHospital == null) {
      _showSnackbar('Please select a hospital.', isError: true);
      return;
    }

    if (_selectedPatient == null) {
      _showSnackbar('Please select a patient profile.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await EmergencyService.bookEmergency(
        patientId: _selectedPatient!.id,
        hospitalId: _selectedHospital!.id,
        reason: _selectedReason!,
        notes: _notesController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _bookingSuccessResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSnackbar(e.toString().replaceAll('Exception: ', ''),
            isError: true);
      }
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE11D48) : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.isEmpty) return;

    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        _showSnackbar('Could not launch phone dialer for $phoneNumber',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bookingSuccessResult != null) {
      return _buildSoftSuccessView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF334155), size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_hospital_rounded,
                color: Color(0xFFF43F5E), size: 22),
            SizedBox(width: 8),
            Text(
              'Urgent Care Request',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSoftEmergencyNoticeBanner(),
                const SizedBox(height: 24),
                _buildStepHeader(
                  step: '1',
                  title: "What's the emergency?",
                  subtitle:
                      'Select the condition requiring urgent medical care',
                ),
                const SizedBox(height: 14),
                _buildReasonGrid(),
                const SizedBox(height: 12),
                _buildNotesInputField(),
                const SizedBox(height: 28),
                _buildStepHeader(
                  step: '2',
                  title: 'Select Nearest Hospital',
                  subtitle: 'Choose a 24/7 medical center or search below',
                ),
                const SizedBox(height: 14),
                _buildSoftSearchBar(),
                const SizedBox(height: 12),
                _buildHospitalList(),
                const SizedBox(height: 28),
                _buildStepHeader(
                  step: '3',
                  title: 'Who needs care?',
                  subtitle: 'Select patient profile',
                ),
                const SizedBox(height: 14),
                _buildPatientSelector(),
              ],
            ),
          ),
          _buildSoftFloatingActionBar(),
        ],
      ),
    );
  }

  // ── SOFT 108 NOTICE BANNER ──────────────────────────────────────────────
  Widget _buildSoftEmergencyNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF43F5E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Life-Threatening Emergency?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9F1239),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'For extreme critical events, call national ambulance (108).',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF9F1239),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _makeCall('108'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'CALL 108',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP HEADER ──────────────────────────────────────────────────────────
  Widget _buildStepHeader({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF43F5E).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Color(0xFFF43F5E),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 1: REASON GRID ──────────────────────────────────────────────────
  Widget _buildReasonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _reasons.length,
      itemBuilder: (context, index) {
        final r = _reasons[index];
        final title = r['title'] as String;
        final subtitle = r['subtitle'] as String;
        final icon = r['icon'] as IconData;
        final bg = r['bg'] as Color;
        final color = r['color'] as Color;
        final isSelected = _selectedReason == title;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: InkWell(
            onTap: () {
              setState(() => _selectedReason = isSelected ? null : title);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? color.withOpacity(0.25)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: isSelected ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── NOTES FIELD ──────────────────────────────────────────────────────────
  Widget _buildNotesInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Add additional details or symptoms (optional)...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.edit_note_rounded,
              color: Color(0xFF94A3B8), size: 22),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ── STEP 2: SEARCH BAR ───────────────────────────────────────────────────
  Widget _buildSoftSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search hospital name, city, or specialty...',
          hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFFF43F5E), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ── STEP 2: HOSPITAL LIST ────────────────────────────────────────────────
  Widget _buildHospitalList() {
    if (_isLoadingHospitals) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFF43F5E), strokeWidth: 2),
            SizedBox(height: 10),
            Text('Finding nearby hospitals...',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_hospitalError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Could not load hospitals: $_hospitalError',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _fetchHospitals,
            ),
          ],
        ),
      );
    }

    if (_filteredHospitals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 36, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            const Text(
              'No hospitals found matching search.',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              'Clear search to view all nearest care centers.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final displayList = _filteredHospitals.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final hospital = displayList[index];
            final isSelected = _selectedHospital?.id == hospital.id;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFF43F5E)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFF43F5E).withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: isSelected ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedHospital = hospital);
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Logo tile. Most hospital images here are wordmark
                      // logos on white — wide banners, not square photos — so
                      // BoxFit.cover was zooming in and cropping the text to
                      // illegible fragments. A neutral card with contain-fit
                      // keeps the whole logo visible and centred instead,
                      // with a hairline border so a white-background logo
                      // still reads as a distinct tile against the card.
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEF2F6)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: FastNetworkImage(
                            url: hospital.profileImage.isNotEmpty
                                ? hospital.profileImage
                                : hospital.image,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            fallback: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.local_hospital_rounded,
                                  color: Color(0xFFF43F5E), size: 26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    hospital.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected
                                          ? const Color(0xFF9F1239)
                                          : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Flexible + scaleDown: the badge has a fixed
                                // minimum width that a long hospital name can push
                                // past the row's edge — the name is already
                                // Expanded+ellipsis, but that only shrinks the
                                // name, not the badge sitting next to it. This lets
                                // the badge itself shrink as a last resort instead
                                // of overflowing.
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Text(
                                        '24/7 ER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${hospital.type} • ${hospital.address}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.near_me_rounded,
                                    size: 12, color: Color(0xFFF43F5E)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${hospital.distance.toStringAsFixed(1)} km away',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF43F5E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Radio Selector Circle
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFF43F5E)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_filteredHospitals.length > 30) ...[
          const SizedBox(height: 12),
          Text(
            'Showing top 30 nearest care centers out of ${_filteredHospitals.length}. Use search above to refine.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ],
    );
  }

  // ── STEP 3: PATIENT SELECTOR ──────────────────────────────────────────────
  Widget _buildPatientSelector() {
    if (_isLoadingPatients) {
      return Row(
        children: List.generate(
          3,
          (i) => Padding(
            padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
            child: Container(
              width: 104,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_off_rounded,
                size: 18, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'No patient profiles found. Add one from My Profile first.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }

    // Wrap rather than a horizontal scroller: two to four family members is
    // the common case, and a scroller for that few items reads as broken —
    // it invites a swipe that reveals nothing, or hides a card off-screen
    // that the patient never discovers.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _patients
          .map((p) => _PatientCard(
                patient: p,
                selected: _selectedPatient?.id == p.id,
                onTap: () => setState(() => _selectedPatient = p),
              ))
          .toList(),
    );
  }

  // ── FLOATING ACTION BAR ──────────────────────────────────────────────────
  Widget _buildSoftFloatingActionBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedHospital != null && _selectedReason != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on_rounded,
                          size: 14, color: Color(0xFFF43F5E)),
                      const SizedBox(width: 4),
                      Text(
                        'Dispatching to ${_selectedHospital!.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF43F5E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEmergencyBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Requesting Urgent Care...',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Request Urgent Care Now',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUCCESS CONFIRMATION VIEW ─────────────────────────────────────────────
  Widget _buildSoftSuccessView() {
    final res = _bookingSuccessResult!;
    final bookingNumber = res['booking_number'] ?? 'BK-EMG';
    final hospitalName = res['hospital_name'] ?? 'Emergency Hospital';
    final hospitalPhone = res['hospital_phone'] ?? '';
    final reason = res['reason'] ?? _selectedReason ?? 'Urgent Care Request';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Request Received',
          style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF059669), size: 54),
              ),
              const SizedBox(height: 16),
              const Text(
                'Urgent Request Sent',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Hospital triage team has been notified.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSoftRow('Request ID', bookingNumber.toString(),
                        isBold: true),
                    const Divider(height: 20),
                    _buildSoftRow('Hospital', hospitalName.toString()),
                    const SizedBox(height: 10),
                    _buildSoftRow('Condition', reason.toString()),
                    const SizedBox(height: 10),
                    _buildSoftRow(
                        'Patient', _selectedPatient?.name ?? 'Patient'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (hospitalPhone.toString().isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(hospitalPhone.toString()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    label: Text(
                      'Call $hospitalName',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyBookingsScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'View My Bookings',
                    style: TextStyle(
                        color: Color(0xFF334155), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home',
                    style: TextStyle(
                        color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selectable card for "Who needs care?".
///
/// Rose is the screen's own accent (matches the emergency banner, the badge,
/// the submit button) — the previous selected state used a dark navy that
/// belonged to no other element on this screen and read as a leftover
/// placeholder rather than a deliberate choice. Selection is now shown by a
/// checkmark badge as well as color, so it does not rely on color alone.
class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.patient,
    required this.selected,
    required this.onTap,
  });

  final Patient patient;
  final bool selected;
  final VoidCallback onTap;

  static const Color _rose = Color(0xFFF43F5E);
  static const Color _roseTint = Color(0xFFFFF1F2);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  /// "Self" reads clinically on a form about to summon an ambulance for
  /// someone; "You" is how the person actually thinks of their own profile.
  String get _relationshipLabel {
    final r = patient.relationship.trim();
    if (r.isEmpty || r.toLowerCase() == 'self') return 'You';
    return r[0].toUpperCase() + r.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${patient.name}, $_relationshipLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 104,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: selected ? _roseTint : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _rose : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _rose.withOpacity(0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: selected ? _rose : const Color(0xFFF1F5F9),
                    child: Text(
                      patient.name.isNotEmpty
                          ? patient.name[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: selected ? Colors.white : _muted,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: _rose,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                patient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _relationshipLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? _rose : _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
