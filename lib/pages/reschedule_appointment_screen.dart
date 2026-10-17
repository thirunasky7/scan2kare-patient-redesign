import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/hospital_service.dart';
import '../services/appointment_service.dart';

class RescheduleAppointmentScreen extends StatefulWidget {
  final int appointmentId;
  final int doctorId;
  final int hospitalId;
  final String doctorName;
  final String doctorAddress;
  final DateTime oldDate;
  final String oldTime;

  const RescheduleAppointmentScreen({
    super.key,
    required this.appointmentId,
    required this.doctorId,
    required this.hospitalId,
    required this.doctorName,
    required this.doctorAddress,
    required this.oldDate,
    required this.oldTime,
  });

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
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

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  int _leadingEmptyDays(DateTime month) {
    return DateTime(month.year, month.month, 1).weekday % 7;
  }

  DateTime? _firstSelectableInMonth(DateTime month) {
    final totalDays = DateUtils.getDaysInMonth(month.year, month.month);
    for (int day = 1; day <= totalDays; day++) {
      final date = DateTime(month.year, month.month, day);
      if (_isDateSelectable(date)) return date;
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

  @override
  void initState() {
    super.initState();

    selectedDate = _dateOnly(widget.oldDate);
    currentMonth = DateTime(widget.oldDate.year, widget.oldDate.month);
    maxMonth = DateTime(DateTime.now().year, DateTime.now().month + 3, 1);
    _loadHolidaysAndSlots();
  }

  Future<void> _loadHolidaysAndSlots() async {
    try {
      final dates =
          await HospitalService.fetchDoctorHolidayDates(widget.doctorId);
      if (!mounted) return;

      DateTime nextSelected = selectedDate;
      final selectedKey = DateFormat('yyyy-MM-dd').format(selectedDate);
      if (dates.contains(selectedKey) || dates.isNotEmpty) {
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        DateTime? candidate;
        final totalDays =
            DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
        for (int day = 1; day <= totalDays; day++) {
          final date = DateTime(currentMonth.year, currentMonth.month, day);
          final key = DateFormat('yyyy-MM-dd').format(date);
          if (date.isBefore(today)) continue;
          if (dates.contains(key)) continue;
          candidate = date;
          break;
        }
        candidate ??= () {
          var cursor = today;
          final limit = DateTime(maxMonth.year, maxMonth.month + 1, 0);
          while (!cursor.isAfter(limit)) {
            final key = DateFormat('yyyy-MM-dd').format(cursor);
            if (!dates.contains(key)) return cursor;
            cursor = cursor.add(const Duration(days: 1));
          }
          return null;
        }();
        if (candidate != null) nextSelected = candidate;
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

  void _changeMonth(int monthDelta) {
    setState(() {
      currentMonth =
          DateTime(currentMonth.year, currentMonth.month + monthDelta);
      if (selectedDate.year != currentMonth.year ||
          selectedDate.month != currentMonth.month) {
        final first = _firstSelectableInMonth(currentMonth);
        if (first != null) {
          selectedDate = first;
          selectedTimeIndex = -1;
          _fetchTimeSlotsForDate(selectedDate);
        } else {
          timeSlots = [];
          selectedTimeIndex = -1;
          selectedDateIsHoliday = false;
          slotsUnavailableMessage =
              'No available dates in this month. Doctor may be on holiday.';
        }
      }
    });
  }

  Future<void> _fetchTimeSlotsForDate(DateTime date) async {
    if (_isHolidayDate(date)) {
      if (!mounted) return;
      setState(() {
        isLoadingSlots = false;
        timeSlots = [];
        selectedTimeIndex = -1;
        selectedDateIsHoliday = true;
        slotsUnavailableMessage =
            'Appointments are unavailable on this date (doctor holiday).';
      });
      return;
    }

    setState(() {
      isLoadingSlots = true;
      timeSlots = [];
      selectedTimeIndex = -1;
      selectedDateIsHoliday = false;
      slotsUnavailableMessage = null;
    });

    try {
      final result = await HospitalService.getAvailableTimeSlots(
        doctorId: widget.doctorId,
        hospitalId: widget.hospitalId,
        date: date,
      );

      if (!mounted) return;

      if (result.isHoliday) {
        final key = DateFormat('yyyy-MM-dd').format(_dateOnly(date));
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
      final isToday = isSameDay(date, now);
      var slots = result.slots;
      if (isToday) {
        slots = result.slots.where((slot) {
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

      setState(() {
        timeSlots = slots;
        selectedDateIsHoliday = false;
        slotsUnavailableMessage =
            slots.isEmpty ? (result.message ?? 'No slots available') : null;
        final index = slots.indexOf(widget.oldTime);
        if (index != -1) {
          selectedTimeIndex = index;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        timeSlots = [];
        slotsUnavailableMessage = 'Unable to load time slots';
      });
    } finally {
      if (mounted) setState(() => isLoadingSlots = false);
    }
  }

  Future<void> _confirmReschedule() async {
    if (selectedDateIsHoliday || !_isDateSelectable(selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appointments are unavailable on this date (doctor holiday).',
          ),
        ),
      );
      return;
    }

    final newTime = timeSlots[selectedTimeIndex];

    final success = await AppointmentService.rescheduleAppointmentUpdate(
      appointmentId: widget.appointmentId,
      doctorId: widget.doctorId,
      newDate: selectedDate,
      newTime: newTime,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment rescheduled successfully")),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to reschedule appointment")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doctorName),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select New Date",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _calendarCard(),
                if (selectedDateIsHoliday) ...[
                  const SizedBox(height: 12),
                  _holidayUnavailableBanner(),
                ] else ...[
                  const SizedBox(height: 24),
                  const Text("Select New Time",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTimeSlotsGrid(),
                ],
              ],
            ),
          ),

          // CONFIRM BUTTON
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedTimeIndex >= 0
                    ? const Color(0xFF243C90)
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: selectedTimeIndex >= 0 ? _confirmReschedule : null,
              child: const Text(
                "Confirm Reschedule",
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ================= CALENDAR =================
  Widget _calendarCard() {
    final totalDays =
        DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
    final leadingEmptyDays = _leadingEmptyDays(currentMonth);
    final today = _dateOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMMM yyyy').format(currentMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _canGoToPreviousMonth() ? () => _changeMonth(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        _canGoToNextMonth() ? () => _changeMonth(1) : null,
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
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
                dayBg = _holidayBlue;
                dayText = Colors.white;
                dayBorder = Border.all(color: _holidayBlueSelected);
              } else if (isSelected) {
                dayBg = const Color(0xFF243C90);
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
                        shape: BoxShape.circle,
                        color: dayBg,
                        border: dayBorder,
                      ),
                      child: Text(
                        "$day",
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

  // ================= TIME GRID =================
  Widget _buildTimeSlotsGrid() {
    if (isLoadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }

    if (timeSlots.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          slotsUnavailableMessage ?? 'No slots available',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timeSlots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
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
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? const Color(0xFF243C90) : Colors.white,
              border: Border.all(color: Colors.grey),
            ),
            child: Text(
              timeSlots[index],
              style: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          ),
        );
      },
    );
  }
}
