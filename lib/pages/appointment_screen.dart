import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'appointment_preview_screen.dart';
import '../services/hospital_service.dart';
import '../models/patient.dart';
import 'dart:convert'; // for jsonDecode
import 'package:http/http.dart' as http; // for http requests
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/deeplink_nav.dart';
import '../config/api_config.dart';

class AppointmentDateTimeScreen extends StatefulWidget {
  final int doctorId;
  final int hospitalId;
  final String doctorName;
  final String doctorAddress;
  final String hospitalName;
  final String doctorImage;
  final String hospitalPhone;
  final bool fromDeepLink;

  const AppointmentDateTimeScreen({
    super.key,
    required this.doctorId,
    required this.hospitalId,
    required this.doctorName,
    required this.doctorAddress,
    required this.hospitalName,
    required this.doctorImage,
    this.hospitalPhone = '',
    this.fromDeepLink = false,
  });

  @override
  State<AppointmentDateTimeScreen> createState() =>
      _AppointmentDateTimeScreenState();
}

class _AppointmentDateTimeScreenState extends State<AppointmentDateTimeScreen> {
  static const Color _holidayBlue = Color(0xFF4A8FC7);
  static const Color _holidayBlueSoft = Color(0xFFD6EAF8);
  static const Color _holidayBlueSelected = Color(0xFF3D7EB5);
  static const Color _holidayBlueBorder = Color(0xFF7EB6D9);

  late DateTime selectedDate;
  int selectedTimeIndex = -1;
  DateTime currentMonth = DateTime.now();
  late DateTime maxMonth;

  List<String> timeSlots = [];
  bool isLoadingSlots = false;
  bool selectedDateIsHoliday = false;
  String? slotsUnavailableMessage;
  Set<String> holidayDates = {};

  List<Patient> patients = [];
  Patient? selectedPatient;
  bool isLoadingPatients = false;

  // Form controllers for patient details
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  int daysInMonth(DateTime date) {
    final firstDayNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1)).day;
  }

  bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _leadingEmptyDays(DateTime month) {
    return DateTime(month.year, month.month, 1).weekday % 7;
  }

  bool _canGoToPreviousMonth() {
    final monthStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final todayMonthStart =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    return monthStart.isAfter(todayMonthStart);
  }

  bool _canGoToNextMonth() {
    final nextMonthStart =
        DateTime(currentMonth.year, currentMonth.month + 1, 1);
    final maxMonthStart = DateTime(maxMonth.year, maxMonth.month, 1);
    return !nextMonthStart.isAfter(maxMonthStart);
  }

  bool _isHolidayDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(_dateOnly(date));
    return holidayDates.contains(key);
  }

  bool _isDateSelectable(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final d = _dateOnly(date);
    if (d.isBefore(today)) return false;
    if (_isHolidayDate(d)) return false;
    return true;
  }

  DateTime? _firstSelectableInMonth(DateTime month) {
    final daysInCurrentMonth = daysInMonth(month);
    for (int day = 1; day <= daysInCurrentMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (_isDateSelectable(date)) return date;
    }
    return null;
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + monthDelta);
      if (!isSameMonth(selectedDate, currentMonth)) {
        final firstAvailable = _firstSelectableInMonth(currentMonth);

        if (firstAvailable != null) {
          selectedDate = firstAvailable;
          selectedTimeIndex = -1;
          selectedDateIsHoliday = false;
          slotsUnavailableMessage = null;
          _fetchTimeSlotsForDate(selectedDate);
        } else {
          selectedTimeIndex = -1;
          timeSlots = [];
          selectedDateIsHoliday = false;
          slotsUnavailableMessage =
              'No available dates in this month. Doctor may be on holiday.';
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = _dateOnly(now);
    currentMonth = DateTime(now.year, now.month);
    maxMonth = DateTime(now.year, now.month + 3, 1);
    _loadHolidaysAndSlots();
    _fetchPatients();
  }

  Future<void> _loadHolidaysAndSlots() async {
    try {
      final dates =
          await HospitalService.fetchDoctorHolidayDates(widget.doctorId);
      if (!mounted) return;

      // Apply all holiday marks first, then move selection off any holiday.
      DateTime nextSelected = selectedDate;
      if (dates.contains(DateFormat('yyyy-MM-dd').format(selectedDate)) ||
          dates.isNotEmpty) {
        final candidate = _firstSelectableWithHolidays(currentMonth, dates) ??
            _findNextSelectableWithHolidays(selectedDate, dates);
        if (candidate != null) {
          nextSelected = candidate;
        }
      }

      setState(() {
        holidayDates = dates;
        selectedDate = nextSelected;
        currentMonth = DateTime(nextSelected.year, nextSelected.month);
        selectedDateIsHoliday = false;
        selectedTimeIndex = -1;
      });
    } catch (e) {
      debugPrint('Holiday fetch error: $e');
    }

    if (!mounted) return;
    await _fetchTimeSlotsForDate(selectedDate);
  }

  DateTime? _firstSelectableWithHolidays(
      DateTime month, Set<String> holidays) {
    final daysInCurrentMonth = daysInMonth(month);
    final today = _dateOnly(DateTime.now());
    for (int day = 1; day <= daysInCurrentMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (date.isBefore(today)) continue;
      if (holidays.contains(key)) continue;
      return date;
    }
    return null;
  }

  DateTime? _findNextSelectableWithHolidays(
      DateTime from, Set<String> holidays) {
    var cursor = _dateOnly(from);
    final today = _dateOnly(DateTime.now());
    if (cursor.isBefore(today)) cursor = today;
    final limit = DateTime(maxMonth.year, maxMonth.month + 1, 0);
    while (!cursor.isAfter(limit)) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      if (!holidays.contains(key)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  DateTime? _findNextSelectableFrom(DateTime from) {
    var cursor = _dateOnly(from);
    final limit = DateTime(maxMonth.year, maxMonth.month + 1, 0);
    while (!cursor.isAfter(limit)) {
      if (_isDateSelectable(cursor)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
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
      } else {
        throw Exception("Failed to load patients");
      }
    } catch (e) {
      print("Patient API Error: $e");

      setState(() {
        patients = [];
        selectedPatient = null;
      });
    } finally {
      setState(() => isLoadingPatients = false);
    }
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _patientNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimeSlotsForDate(DateTime date) async {
    if (_isHolidayDate(date)) {
      if (!mounted) return;
      setState(() {
        isLoadingSlots = false;
        selectedTimeIndex = -1;
        timeSlots = [];
        selectedDateIsHoliday = true;
        slotsUnavailableMessage =
            'Appointments are unavailable on this date (doctor holiday).';
      });
      return;
    }

    setState(() {
      isLoadingSlots = true;
      selectedTimeIndex = -1;
      timeSlots = [];
      selectedDateIsHoliday = false;
      slotsUnavailableMessage = null;
    });

    try {
      final result = await HospitalService.getAvailableTimeSlots(
        doctorId: widget.doctorId,
        hospitalId: widget.hospitalId,
        date: date,
      );

      if (result.isHoliday) {
        final key = DateFormat('yyyy-MM-dd').format(_dateOnly(date));
        if (!mounted) return;
        setState(() {
          holidayDates = {...holidayDates, key};
          timeSlots = [];
          selectedDateIsHoliday = true;
          slotsUnavailableMessage = result.message ??
              'Appointments are unavailable on this date (doctor holiday).';
        });
        return;
      }

      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      List<String> filteredSlots = result.slots;

      if (isToday) {
        filteredSlots = result.slots.where((slot) {
          final slotTime = DateFormat('hh:mm a').parse(slot);
          final slotDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            slotTime.hour,
            slotTime.minute,
          );
          return slotDateTime.isAfter(now);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        timeSlots = filteredSlots;
        selectedDateIsHoliday = false;
        slotsUnavailableMessage = filteredSlots.isEmpty
            ? (result.message ?? 'No time slots available for this date')
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        timeSlots = [];
        selectedDateIsHoliday = false;
        slotsUnavailableMessage = 'Unable to load time slots';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingSlots = false;
        });
      }
    }
  }

  // Helper method to check if all required fields are filled
  bool _areAllRequiredFieldsFilled() {
    return _patientNameController.text.isNotEmpty &&
        // _emailController.text.isNotEmpty &&
        _contactController.text.isNotEmpty;
  }

  // Helper method to check if form is valid
  bool _isFormValid() {
    // if (!_areAllRequiredFieldsFilled()) {
    //   return false;
    // }

    // // Email validation ONLY if not empty
    // if (_emailController.text.isNotEmpty) {
    //   final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    //   if (!emailRegex.hasMatch(_emailController.text)) {
    //     return false;
    //   }
    // }

    // // Check phone number format (10 digits)
    // final phoneRegex = RegExp(r'^[0-9]{10}$');
    // if (!phoneRegex.hasMatch(_contactController.text)) {
    //   return false;
    // }

    return true;
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
      appBar: AppBar(
        backgroundColor: const Color(0x1F62C6FF),
        surfaceTintColor: const Color(0x1F62C6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            handleDetailBack(context, fromDeepLink: widget.fromDeepLink);
          },
        ),
        centerTitle: true,
        title: Text(
          widget.doctorName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  widget.doctorAddress,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                )
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Select Date
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _calendarCard(),

            if (selectedDateIsHoliday) ...[
              const SizedBox(height: 12),
              _holidayUnavailableBanner(),
            ] else ...[
              const SizedBox(height: 24),
              const Text(
                'Select Timing',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildTimeSlotsGrid(),
            ],

            // Patient Details Section (only shows when time slot is selected)
            if (selectedTimeIndex >= 0) ...[
              const SizedBox(height: 24),
              _patientDetailsForm(),
            ],

            const SizedBox(height: 30),

            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedTimeIndex >= 0 && _isFormValid()
                      ? const Color(0xFF2B6F71)
                      : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedTimeIndex >= 0 && selectedPatient != null
                    ? () {
                        final appointmentData = {
                          'doctor_id': widget.doctorId,
                          'hospital_id': widget.hospitalId,
                          'date':
                              DateFormat('yyyy-MM-dd').format(selectedDate),
                          'time': timeSlots[selectedTimeIndex],
                          'patient_id': selectedPatient!.id,
                          'patient_name': selectedPatient!.name,
                          'patient_phone': selectedPatient!.phone,
                          'patient': {
                            'id': selectedPatient!.id,
                            'name': selectedPatient!.name,
                            'phone': selectedPatient!.phone,
                            'relationship': selectedPatient!.relationship,
                          },
                          'notes': _notesController.text.trim(),
                        };

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AppointmentPreviewScreen(
                              appointmentData: appointmentData,
                              doctorId: widget.doctorId,
                              hospitalId: widget.hospitalId,
                              hospitalAddress: widget.doctorAddress,
                              doctorName: widget.doctorName,
                              hospitalName: widget.hospitalName,
                              doctorImage: widget.doctorImage,
                              hospitalPhone: widget.hospitalPhone,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }

  // ================= CALENDAR CARD =================
  Widget _calendarCard() {
    final totalDays = daysInMonth(currentMonth);
    final leadingEmptyDays = _leadingEmptyDays(currentMonth);
    final today = _dateOnly(DateTime.now());

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
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _canGoToPreviousMonth() ? () => _changeMonth(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canGoToNextMonth() ? () => _changeMonth(1) : null,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyDays + totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays) {
                return const SizedBox.shrink();
              }

              final day = index - leadingEmptyDays + 1;
              final date = DateTime(currentMonth.year, currentMonth.month, day);
              final isPast = date.isBefore(today);
              final isHoliday = _isHolidayDate(date);
              final isSelected = isSameDay(selectedDate, date);

              Color? dayBg;
              Color dayText;
              Border? dayBorder;

              if (isPast && isHoliday) {
                dayBg = const Color(0xFFB8D4E8);
                dayText = Colors.white70;
                dayBorder = Border.all(color: const Color(0xFF9BBFDB));
              } else if (isPast) {
                dayBg = Colors.transparent;
                dayText = Colors.grey;
              } else if (isHoliday && isSelected) {
                dayBg = _holidayBlueSelected;
                dayText = Colors.white;
                dayBorder = Border.all(color: _holidayBlueSelected, width: 1.5);
              } else if (isHoliday) {
                // All holidays marked before selection (filled blue + dot).
                dayBg = _holidayBlue;
                dayText = Colors.white;
                dayBorder = Border.all(color: _holidayBlueSelected);
              } else if (isSelected) {
                dayBg = const Color(0xFF2B6F71);
                dayText = Colors.white;
              } else {
                dayBg = Colors.transparent;
                dayText = Colors.black;
              }

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                        setState(() {
                          selectedDate = date;
                          selectedTimeIndex = -1;
                        });
                        _fetchTimeSlotsForDate(date);
                      },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dayBg,
                        shape: BoxShape.circle,
                        border: dayBorder,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: dayText,
                          fontWeight: isHoliday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isHoliday)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (holidayDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _holidayBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: _holidayBlueSelected, width: 1.2),
                  ),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Blue marked dates are doctor holidays',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _holidayUnavailableBanner() {
    final dateLabel = DateFormat('dd MMM yyyy').format(selectedDate);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _holidayBlueSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _holidayBlueBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _holidayBlueBorder),
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              color: _holidayBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doctor on holiday',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _holidayBlueSelected,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Appointments are unavailable on $dateLabel. Please choose another date.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientDetailsForm() {
    if (isLoadingPatients) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2B6F71)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Patient',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B6F71),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<Patient>(
              isExpanded: true,
              value:
                  patients.contains(selectedPatient) ? selectedPatient : null,
              hint: const Text('Choose patient'),
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

            const SizedBox(height: 12),

            // ✅ NOTES FIELD
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any additional info',
                prefixIcon: const Icon(Icons.note, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  // ================= TIME SLOTS GRID =================
  Widget _buildTimeSlotsGrid() {
    if (isLoadingSlots) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Color(0xFF2B6F71),
        ),
      );
    }

    if (timeSlots.isEmpty) {
      if (selectedDateIsHoliday) {
        return const SizedBox.shrink();
      }

      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.schedule,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'No time slots available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                slotsUnavailableMessage ??
                    'Select another date to see available slots',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timeSlots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        bool isSelected = selectedTimeIndex == index;
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedTimeIndex = index;
            });
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2B6F71) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF2B6F71) : Colors.grey.shade300,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2B6F71).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              timeSlots[index],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}
