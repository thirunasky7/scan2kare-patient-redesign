import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dialysis_models.dart';
import '../models/patient.dart';
import '../services/dialysis_api_service.dart';
import '../utils/api_error.dart';
import '../utils/app_date_format.dart';
import '../widgets/fast_network_image.dart';

class DialysisCenterDetailScreen extends StatefulWidget {
  final int centerId;
  final DialysisBookingItem? rescheduleBooking;

  const DialysisCenterDetailScreen({
    super.key,
    required this.centerId,
    this.rescheduleBooking,
  });

  @override
  State<DialysisCenterDetailScreen> createState() =>
      _DialysisCenterDetailScreenState();
}

class _DialysisCenterDetailScreenState extends State<DialysisCenterDetailScreen> {
  static const Color _brand = Color(0xFF2B6F71);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _center;
  List<dynamic> _branches = [];

  int? _branchId;
  int? _machineId;
  String? _machineName;

  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late DateTime _maxMonth;

  List<Map<String, dynamic>> _slots = [];
  int _selectedTimeIndex = -1;
  bool _loadingSlots = false;
  String? _slotsMessage;
  final Set<String> _missingFields = {};

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  bool _loadingPatients = false;
  bool _booking = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentMonth = DateTime(now.year, now.month);
    _maxMonth = DateTime(now.year, now.month + 3);
    _bootstrap();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadingPatients = true;
    });
    try {
      final detail = await DialysisApiService.getCenterDetail(widget.centerId);
      final family = _isReschedule
          ? <dynamic>[]
          : await DialysisApiService.getFamilyProfiles();
      final patients = family
          .map((e) => Patient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (!mounted) return;

      Patient? selected;
      for (final p in patients) {
        if (p.relationship.toLowerCase() == 'self') {
          selected = p;
          break;
        }
      }
      selected ??= patients.isNotEmpty ? patients.first : null;

      setState(() {
        _center = detail;
        _branches = (detail['branches'] as List?) ?? [];
        _patients = patients;
        _selectedPatient = selected;
        _loadingPatients = false;

        if (_branches.isNotEmpty) {
          final first = Map<String, dynamic>.from(_branches.first as Map);
          _branchId = int.tryParse('${first['id']}');
          final machines = (first['machines'] as List?) ?? [];
          if (machines.isNotEmpty) {
            final m = Map<String, dynamic>.from(machines.first as Map);
            if ((m['status'] ?? '').toString() != 'maintenance') {
              _machineId = int.tryParse('${m['id']}');
              _machineName = m['machine_name']?.toString();
            }
          }
        }
        _applyRescheduleDefaults();
        _loading = false;
      });

      if (_machineId != null) await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingPatients = false;
        _error = friendlyException(
          e,
          fallback: 'Could not load this dialysis centre. Please try again.',
        );
      });
    }
  }

  void _applyRescheduleDefaults() {
    final booking = widget.rescheduleBooking;
    if (booking == null) return;

    if (booking.branchId != null) {
      final hasBranch = _branches.any((b) {
        final map = Map<String, dynamic>.from(b as Map);
        return int.tryParse('${map['id']}') == booking.branchId;
      });
      if (hasBranch) {
        _branchId = booking.branchId;
        _machineId = null;
        _machineName = null;
      }
    }
    if (booking.machineId != null) {
      final machines = _machinesForBranch(_branchId);
      for (final m in machines) {
        if (int.tryParse('${m['id']}') == booking.machineId) {
          _machineId = booking.machineId;
          _machineName = m['machine_name']?.toString() ?? booking.machineName;
          break;
        }
      }
    }
    if (_machineId == null) {
      final machines = _machinesForBranch(_branchId);
      for (final m in machines) {
        if ((m['status'] ?? '').toString() != 'maintenance') {
          _machineId = int.tryParse('${m['id']}');
          _machineName = m['machine_name']?.toString();
          break;
        }
      }
    }
    final parsed = DateTime.tryParse(booking.bookingDate ?? '');
    if (parsed != null) {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
      if (!dateOnly.isBefore(todayOnly)) {
        _selectedDate = dateOnly;
        _currentMonth = DateTime(dateOnly.year, dateOnly.month);
      }
    }
  }

  List<Map<String, dynamic>> _machinesForBranch(int? branchId) {
    if (branchId == null) return [];
    for (final b in _branches) {
      final map = Map<String, dynamic>.from(b as Map);
      if (int.tryParse('${map['id']}') == branchId) {
        return ((map['machines'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return [];
  }

  Future<void> _loadSlots() async {
    if (_machineId == null) return;
    setState(() {
      _loadingSlots = true;
      _selectedTimeIndex = -1;
      _slots = [];
      _slotsMessage = null;
    });
    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await DialysisApiService.getMachineSlots(
        machineId: _machineId!,
        date: date,
        ignoreBookingId: widget.rescheduleBooking?.id,
      );
      final morning = _mapSlotList(data['morning']);
      final evening = _mapSlotList(data['evening']);
      final combined = [
        ..._upcomingSlots(morning, _selectedDate),
        ..._upcomingSlots(evening, _selectedDate),
      ];
      final fallback = combined.isNotEmpty
          ? combined
          : _upcomingSlots(
              _mapSlotList(data['slots']),
              _selectedDate,
            );
      if (!mounted) return;
      setState(() {
        _slots = fallback;
        if (fallback.isEmpty) {
          _slotsMessage = data['message']?.toString() ??
              (DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                      ) ==
                      DateTime(DateTime.now().year, DateTime.now().month,
                          DateTime.now().day)
                  ? 'No upcoming morning or evening slots left today. Please choose another date.'
                  : 'No morning or evening slots are available on this date.');
        } else {
          _slotsMessage = null;
        }
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyException(
            e,
            fallback: 'Could not load time slots. Please try another date.',
          )),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _mapSlotList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _upcomingSlots(
    List<Map<String, dynamic>> slots,
    DateTime date,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected.isBefore(today)) {
      return [];
    }
    if (selected.isAfter(today)) {
      return slots;
    }
    return slots.where((slot) {
      final parts = (slot['time'] ?? '').toString().split(':');
      if (parts.length < 2) return false;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final slotAt = DateTime(date.year, date.month, date.day, hour, minute);
      return slotAt.isAfter(now);
    }).toList();
  }

  bool get _isReschedule => widget.rescheduleBooking != null;

  bool get _canBook =>
      (_isReschedule || _selectedPatient != null) &&
      _branchId != null &&
      _machineId != null &&
      _selectedTimeIndex >= 0 &&
      _selectedTimeIndex < _slots.length;

  String _requiredMessage(List<String> missing) {
    if (missing.isEmpty) return '';
    if (missing.length == 1) {
      return 'Please select a ${missing.first} before proceeding.';
    }
    if (missing.length == 2) {
      return 'Please select a ${missing[0]} and ${missing[1]} before proceeding.';
    }
    final last = missing.last;
    final rest = missing.sublist(0, missing.length - 1).join(', ');
    return 'Please select $rest and $last before proceeding.';
  }

  Future<void> _book() async {
    final missing = <String>[];
    if (_branchId == null) missing.add('Branch');
    if (_machineId == null) missing.add('Machine');
    if (_selectedTimeIndex < 0 || _selectedTimeIndex >= _slots.length) {
      missing.add('time slot');
    }
    if (_selectedPatient == null && !_isReschedule) missing.add('Patient');

    if (missing.isNotEmpty) {
      setState(() {
        _missingFields
          ..clear()
          ..addAll(missing);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_requiredMessage(missing))),
      );
      return;
    }

    final slotTime = (_slots[_selectedTimeIndex]['time'] ?? '').toString();
    final slotLabel = _formatSlotDisplay(slotTime);
    final dateLabel = AppDateFormat.formatLong(_selectedDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isReschedule
            ? 'Confirm reschedule'
            : 'Confirm dialysis booking'),
        content: Text(
          'Centre: $_centerName\n'
          'Date: $dateLabel\n'
          'Time: $slotLabel'
          '${_isReschedule ? '' : '\nPatient: ${_selectedPatient!.name}'}\n\n'
          '${_isReschedule ? 'Do you want to reschedule this booking?' : 'Do you want to confirm this booking?'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _missingFields.clear();
      _booking = true;
    });
    try {
      final created = _isReschedule
          ? await DialysisApiService.rescheduleBooking(
              bookingId: widget.rescheduleBooking!.id,
              bookingDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
              slotTime: slotTime,
              branchId: _branchId,
              machineId: _machineId,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            )
          : await DialysisApiService.createBooking(
              patientId: _selectedPatient!.id,
              centerId: widget.centerId,
              branchId: _branchId!,
              machineId: _machineId!,
              bookingDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
              slotTime: slotTime,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      if (!mounted) return;
      final ref = created['booking_reference']?.toString();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_isReschedule ? 'Booking rescheduled' : 'Booking confirmed'),
          content: Text(
            _isReschedule
                ? 'Your dialysis slot is now $dateLabel at $slotLabel.'
                    '${ref != null && ref.isNotEmpty ? '\nReference: $ref' : ''}'
                : 'Your dialysis slot is booked for $dateLabel at $slotLabel.'
                    '${ref != null && ref.isNotEmpty ? '\nReference: $ref' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyException(
            e,
            fallback: _isReschedule
              ? 'Could not reschedule this booking. Please try again.'
              : 'Could not complete the booking. Please try again.',
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  int _leadingEmptyDays(DateTime month) =>
      DateTime(month.year, month.month, 1).weekday % 7;

  bool _canGoPrevMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return _currentMonth.isAfter(start);
  }

  bool _canGoNextMonth() => !_currentMonth.isAtSameMomentAs(
        DateTime(_maxMonth.year, _maxMonth.month),
      );

  void _changeMonth(int delta) {
    final next = DateTime(_currentMonth.year, _currentMonth.month + delta);
    if (delta < 0 && !_canGoPrevMonth()) return;
    if (delta > 0 && !_canGoNextMonth()) return;
    setState(() => _currentMonth = next);
  }

  String get _centerName =>
      (_center?['center_name'] ?? 'Dialysis Centre').toString();

  String get _centerAddress {
    final address = (_center?['address'] ?? '').toString();
    if (address.isNotEmpty) return address;
    return [
      _center?['city'],
      _center?['state'],
    ].where((e) => e != null && e.toString().isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0x1F62C6FF),
        surfaceTintColor: const Color(0x1F62C6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _isReschedule ? 'Reschedule booking' : _centerName,
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
                Flexible(
                  child: Text(
                    _centerAddress.isNotEmpty
                        ? _centerAddress
                        : 'Dialysis centre',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFFE8F4F3)),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _brand))
                : _error != null
                    ? _errorView()
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _profileCard(),
                                  const SizedBox(height: 16),
                                  _sectionTitle('Select Branch & Machine'),
                                  const SizedBox(height: 12),
                                  _branchMachineCard(),
                                  const SizedBox(height: 24),
                                  _sectionTitle('Select Date'),
                                  const SizedBox(height: 12),
                                  _calendarCard(),
                                  const SizedBox(height: 24),
                                  _sectionTitle(
                                    'Select Timing${_machineName != null ? ' · $_machineName' : ''}',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTimeSlotsGrid(),
                                  if (_selectedTimeIndex >= 0 && !_isReschedule) ...[
                                    const SizedBox(height: 24),
                                    _patientDetailsForm(),
                                  ],
                                  const SizedBox(height: 30),
                                  _continueButton(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _bootstrap,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _profileCard() {
    final image = (_center?['profile_image'] ?? '').toString();
    final about = (_center?['about_us'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isNotEmpty
                    ? FastNetworkImage(
                        url: image,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        fallback: _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _centerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dialysis Centre',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (about.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              about,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFE7F6F1),
      child: const Icon(Icons.water_drop, color: _brand, size: 36),
    );
  }

  Widget _branchMachineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _branchId,
            hint: const Text('Choose branch'),
            items: _branches.map((b) {
              final m = Map<String, dynamic>.from(b as Map);
              return DropdownMenuItem(
                value: int.tryParse('${m['id']}'),
                child: Text((m['branch_name'] ?? 'Branch').toString()),
              );
            }).toList(),
            onChanged: (v) {
              final machines = _machinesForBranch(v);
              setState(() {
                _branchId = v;
                _selectedTimeIndex = -1;
                _missingFields.remove('Branch');
                if (machines.isNotEmpty) {
                  Map<String, dynamic>? firstAvailable;
                  for (final m in machines) {
                    if ((m['status'] ?? '').toString() != 'maintenance') {
                      firstAvailable = m;
                      break;
                    }
                  }
                  if (firstAvailable != null) {
                    _machineId = int.tryParse('${firstAvailable['id']}');
                    _machineName = firstAvailable['machine_name']?.toString();
                  } else {
                    _machineId = null;
                    _machineName = null;
                  }
                } else {
                  _machineId = null;
                  _machineName = null;
                }
              });
              _loadSlots();
            },
            decoration: _premiumDropdownDeco(
              icon: Icons.apartment_outlined,
              label: 'Branch *',
              hasError: _missingFields.contains('Branch'),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _machineId,
            hint: const Text('Choose machine'),
            items: _machinesForBranch(_branchId).map((m) {
              final status = (m['status'] ?? '').toString();
              final label =
                  '${m['machine_name']}${status == 'maintenance' ? ' (maintenance)' : ''}';
              return DropdownMenuItem(
                value: int.tryParse('${m['id']}'),
                enabled: status != 'maintenance',
                child: Text(label),
              );
            }).toList(),
            onChanged: (v) {
              final machines = _machinesForBranch(_branchId);
              final match = machines.firstWhere(
                (m) => int.tryParse('${m['id']}') == v,
                orElse: () => {},
              );
              setState(() {
                _machineId = v;
                _machineName = match['machine_name']?.toString();
                _selectedTimeIndex = -1;
                _missingFields.remove('Machine');
              });
              _loadSlots();
            },
            decoration: _premiumDropdownDeco(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Machine *',
              hasError: _missingFields.contains('Machine'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _premiumDropdownDeco({
    required IconData icon,
    required String label,
    bool hasError = false,
  }) {
    final borderColor = hasError ? const Color(0xFFDC3545) : Colors.grey.shade300;
    return InputDecoration(
      labelText: label,
      errorText: hasError ? 'Required' : null,
      prefixIcon: Icon(icon, color: hasError ? const Color(0xFFDC3545) : _brand),
      filled: true,
      fillColor: hasError ? const Color(0xFFFFF5F5) : const Color(0xFFF7FBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: hasError ? 1.4 : 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? const Color(0xFFDC3545) : _brand,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC3545), width: 1.4),
      ),
    );
  }

  Widget _calendarCard() {
    final totalDays = _daysInMonth(_currentMonth);
    final leading = _leadingEmptyDays(_currentMonth);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _canGoPrevMonth() ? () => _changeMonth(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _canGoNextMonth() ? () => _changeMonth(1) : null,
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Selected date: ${AppDateFormat.formatLong(_selectedDate)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B6F71),
              ),
            ),
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
            itemCount: leading + totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final date =
                  DateTime(_currentMonth.year, _currentMonth.month, day);
              final isPast = date.isBefore(todayOnly);
              final isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              final isToday = date.year == todayOnly.year &&
                  date.month == todayOnly.month &&
                  date.day == todayOnly.day;

              Color dayBg = Colors.transparent;
              Color dayText = isPast ? Colors.grey.shade400 : Colors.black;
              Border? dayBorder;

              if (isSelected) {
                dayBg = _brand;
                dayText = Colors.white;
              } else if (isToday) {
                dayBorder = Border.all(color: _brand, width: 1.2);
              }

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = date;
                          _selectedTimeIndex = -1;
                        });
                        _loadSlots();
                      },
                child: Container(
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 14,
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

  Widget _buildTimeSlotsGrid() {
    if (_machineId == null) {
      return _emptySlotsBox(
        icon: Icons.precision_manufacturing_outlined,
        title: 'Select a machine first',
        subtitle: 'Choose branch and machine to see available slots',
      );
    }

    if (_loadingSlots) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _brand),
      );
    }

    if (_slots.isEmpty) {
      return _emptySlotsBox(
        icon: Icons.schedule,
        title: 'No time slots available',
        subtitle: _slotsMessage ??
            'Select another date to see available slots',
      );
    }

    // Group morning / evening visually if present
    final morning = <Map<String, dynamic>>[];
    final evening = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];
    for (final s in _slots) {
      final shift = (s['shift'] ?? '').toString().toLowerCase();
      if (shift == 'morning') {
        morning.add(s);
      } else if (shift == 'evening') {
        evening.add(s);
      } else {
        other.add(s);
      }
    }

    if (morning.isEmpty && evening.isEmpty) {
      return _slotGrid(_slots);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morning.isNotEmpty) ...[
          _shiftLabel('Morning'),
          const SizedBox(height: 10),
          _slotGrid(morning),
          const SizedBox(height: 16),
        ],
        if (evening.isNotEmpty) ...[
          _shiftLabel('Evening'),
          const SizedBox(height: 10),
          _slotGrid(evening),
        ],
        if (other.isNotEmpty) ...[
          const SizedBox(height: 16),
          _slotGrid(other),
        ],
      ],
    );
  }

  Widget _shiftLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _slotGrid(List<Map<String, dynamic>> slots) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        final slot = slots[index];
        final globalIndex = _slots.indexOf(slot);
        final time = (slot['time'] ?? '').toString();
        final display = _formatSlotDisplay(time);
        final isSelected = _selectedTimeIndex == globalIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeIndex = globalIndex;
              _missingFields.remove('time slot');
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? _brand : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _brand
                    : (_missingFields.contains('time slot')
                        ? const Color(0xFFDC3545)
                        : Colors.grey.shade300),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _brand.withOpacity(0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              display,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatSlotDisplay(String time) {
    try {
      final parsed = DateFormat('HH:mm').parse(time);
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      return time;
    }
  }

  Widget _emptySlotsBox({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientDetailsForm() {
    if (_loadingPatients) {
      return const Center(
        child: CircularProgressIndicator(color: _brand),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                color: _brand,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Patient>(
              isExpanded: true,
              value: _patients.contains(_selectedPatient)
                  ? _selectedPatient
                  : null,
              hint: const Text('Choose patient'),
              items: _patients.map((patient) {
                return DropdownMenuItem<Patient>(
                  value: patient,
                  child: Text('${patient.name} (${patient.relationship})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPatient = value;
                  _missingFields.remove('Patient');
                });
              },
              decoration: _premiumDropdownDeco(
                icon: Icons.person,
                label: 'Patient *',
                hasError: _missingFields.contains('Patient'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any additional info',
                prefixIcon: const Icon(Icons.note, size: 20),
                filled: true,
                fillColor: const Color(0xFFF7FBFA),
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

  Widget _continueButton() {
    final enabled = _canBook && !_booking;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _brand : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: enabled ? 2 : 0,
        ),
        onPressed: enabled ? _book : null,
        child: _booking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isReschedule ? 'Reschedule Booking' : 'Confirm Booking',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
