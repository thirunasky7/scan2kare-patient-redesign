import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/patient.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/scan_api_service.dart';

class ScanBookingScreen extends StatefulWidget {
  final int centerId;
  final String centerName;
  final String centerAddress;

  final int scanTypeId;
  final String scanName;
  final String scanDescription;

  const ScanBookingScreen({
    super.key,
    required this.centerId,
    required this.centerName,
    required this.centerAddress,
    required this.scanTypeId,
    required this.scanName,
    required this.scanDescription,
  });

  @override
  State<ScanBookingScreen> createState() => _ScanBookingScreenState();
}

class _ScanBookingScreenState extends State<ScanBookingScreen> {
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? selectedDate = DateTime.now().day;

  final TextEditingController notesController = TextEditingController();

  List<Patient> patients = [];
  Patient? selectedPatient;
  bool isLoadingPatients = false;
  bool isSubmitting = false;

  List<Map<String, dynamic>> timeSlots = [];
  String? selectedTime;
  String? slotsMessage;
  bool isLoadingSlots = false;

  static final DateTime _minMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  static final DateTime _maxMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month + 3,
  );

  @override
  void initState() {
    super.initState();
    _fetchPatients();
    _loadSlotsForSelectedDate();
  }

  Future<void> _fetchPatients() async {
    setState(() => isLoadingPatients = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/patient/family-profiles"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['data'] != null) {
        List list = data['data'];

        setState(() {
          patients = list.map((e) => Patient.fromJson(e)).toList();

          selectedPatient = patients.firstWhere(
            (p) => p.relationship.toLowerCase() == "self",
            orElse: () => patients.first,
          );
        });
      }
    } catch (e) {
      setState(() {
        patients = [];
        selectedPatient = null;
      });
    } finally {
      setState(() => isLoadingPatients = false);
    }
  }

  String? get _selectedDateString {
    if (selectedDate == null) return null;
    final date = DateTime(currentMonth.year, currentMonth.month, selectedDate!);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _loadSlotsForSelectedDate() async {
    final dateStr = _selectedDateString;
    if (dateStr == null) {
      setState(() {
        timeSlots = [];
        selectedTime = null;
        slotsMessage = 'Select a date to see available slots';
      });
      return;
    }

    setState(() {
      isLoadingSlots = true;
      selectedTime = null;
      slotsMessage = null;
      timeSlots = [];
    });

    try {
      final data = await ScanApiService.getSlots(
        centerId: widget.centerId,
        scanTypeId: widget.scanTypeId,
        date: dateStr,
      );

      final rawSlots = data['slots'];
      final list = rawSlots is List
          ? rawSlots
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        timeSlots = list;
        slotsMessage = list.isEmpty
            ? (data['message']?.toString() ??
                'No slots available for this date.')
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        timeSlots = [];
        slotsMessage = 'Failed to load time slots. Please try again.';
      });
    } finally {
      if (mounted) setState(() => isLoadingSlots = false);
    }
  }

  int daysInMonth(DateTime date) {
    final firstDayNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1)).day;
  }

  void _changeMonth(int delta) {
    final target = DateTime(currentMonth.year, currentMonth.month + delta);
    if (target.isBefore(_minMonth) || target.isAfter(_maxMonth)) return;
    setState(() {
      currentMonth = target;
      selectedDate = null;
      timeSlots = [];
      selectedTime = null;
      slotsMessage = 'Select a date to see available slots';
    });
  }

  bool get _canSubmit =>
      selectedPatient != null &&
      selectedDate != null &&
      selectedTime != null &&
      !isSubmitting;

  Future<void> _submitBooking() async {
    if (!_canSubmit) return;

    setState(() => isSubmitting = true);

    final bookingDate = DateTime(
      currentMonth.year,
      currentMonth.month,
      selectedDate!,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/scan-booking'),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "diagnatic_center_id": widget.centerId,
          "scan_type_id": widget.scanTypeId,
          "appointment_date": DateFormat('yyyy-MM-dd').format(bookingDate),
          "appointment_time": selectedTime,
          "patient_id": selectedPatient!.id,
          "notes": notesController.text,
        }),
      );

      final decoded = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? "Scan booked successfully"),
            backgroundColor: const Color(0xFF2B6F71),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(decoded['message'] ?? "Booking failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text("Book Scan"),
        backgroundColor: const Color(0xFF2B6F71),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.centerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.centerAddress,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.scanName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.scanDescription),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Date",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            _calendarCard(),

            const SizedBox(height: 24),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Select Time",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            _timeSlotsCard(),

            const SizedBox(height: 24),

            _patientDropdown(),

            const SizedBox(height: 24),

            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Notes (Optional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canSubmit ? const Color(0xFF2B6F71) : Colors.grey,
                ),
                onPressed: _canSubmit ? _submitBooking : null,
                child: isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Continue",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _calendarCard() {
    final totalDays = daysInMonth(currentMonth);
    final today = DateTime.now();

    final canGoPrev = !DateTime(currentMonth.year, currentMonth.month - 1)
        .isBefore(_minMonth);
    final canGoNext = !DateTime(currentMonth.year, currentMonth.month + 1)
        .isAfter(_maxMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: canGoPrev ? const Color(0xFF2B6F71) : Colors.grey.shade300,
                onPressed: canGoPrev ? () => _changeMonth(-1) : null,
              ),
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: canGoNext ? const Color(0xFF2B6F71) : Colors.grey.shade300,
                onPressed: canGoNext ? () => _changeMonth(1) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, index) {
              final day = index + 1;
              final date =
                  DateTime(currentMonth.year, currentMonth.month, day);

              final isPast = date.isBefore(
                DateTime(today.year, today.month, today.day),
              );

              final selected = selectedDate == day;

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                        setState(() {
                          selectedDate = day;
                        });
                        _loadSlotsForSelectedDate();
                      },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected ? const Color(0xFF2B6F71) : Colors.transparent,
                  ),
                  child: Text(
                    "$day",
                    style: TextStyle(
                      color: isPast
                          ? Colors.grey
                          : selected
                              ? Colors.white
                              : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _timeSlotsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isLoadingSlots
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF2B6F71)),
              ),
            )
          : timeSlots.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    slotsMessage ?? 'No slots available for this date.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: timeSlots.map((slot) {
                    final time = (slot['time'] ?? '').toString();
                    final label =
                        (slot['label'] ?? slot['time'] ?? '').toString();
                    final selected = selectedTime == time;

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF2B6F71)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF2B6F71)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _patientDropdown() {
    if (isLoadingPatients) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2B6F71),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Patient",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B6F71),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Patient>(
            isExpanded: true,
            value: patients.contains(selectedPatient) ? selectedPatient : null,
            hint: const Text("Choose patient"),
            items: patients.map((patient) {
              return DropdownMenuItem<Patient>(
                value: patient,
                child: Text("${patient.name} (${patient.relationship})"),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedPatient = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
