import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reschedule_appointment_screen.dart';
import '../utils/local_storage.dart';
import '../utils/app_date_format.dart';
import '../utils/deeplink_nav.dart';
import '../models/appointment.dart';
import '../config/api_config.dart';
import 'live_appointment_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<AppointmentModel> upcomingList = [];
  List<AppointmentModel> pastList = [];

  List<AppointmentModel> filteredUpcoming = [];
  List<AppointmentModel> filteredPast = [];
  List<AppointmentModel> cancelledList = [];
  List<AppointmentModel> filteredCancelled = [];

  bool isLoading = true;
  bool _isCancelling = false;

  String selectedSpecialization = 'All';
  List<String> specializationOptions = ['All'];

  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAppointments();
    searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    searchController.removeListener(_applyFilters);
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAppointments({bool showSpinner = true}) async {
    if (showSpinner) setState(() => isLoading = true);

    cancelledList = [];
    upcomingList = [];
    pastList = [];

    await fetchUpcomingAppointments();
    await fetchPastAppointments();

    if (!mounted) return;
    _rebuildSpecializationOptions();
    setState(() {
      isLoading = false;
    });
    _applyFilters();
  }

  void _rebuildSpecializationOptions() {
    final names = <String>{};
    for (final list in [upcomingList, pastList, cancelledList]) {
      for (final a in list) {
        final s = a.specialization.trim();
        if (s.isNotEmpty) names.add(s);
      }
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    specializationOptions = ['All', ...sorted];
    if (!specializationOptions.contains(selectedSpecialization)) {
      selectedSpecialization = 'All';
    }
  }

  bool _isCancelledStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'cancelled' || s == 'canceled' || s == 'cancel';
  }

  bool _isCompletedStatus(String status) {
    final s = status.toLowerCase().trim();
    return s == 'completed' ||
        s == 'complete' ||
        s == 'done' ||
        s == 'attended' ||
        s == 'no_show';
  }

  bool _isActiveUpcoming(AppointmentModel a) {
    return !_isCancelledStatus(a.status) && !_isCompletedStatus(a.status);
  }

  Future<void> fetchUpcomingAppointments() async {
    final token = await LocalStorage.getToken();

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/upcoming-appointments"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final data = jsonData['data'];
      if (data is! List) return;

      final allAppointments =
          data.map((e) => AppointmentModel.fromJson(e)).toList();

      // Upcoming API excludes cancelled/completed; keep only active.
      upcomingList = allAppointments.where(_isActiveUpcoming).toList();
    }
  }

  Future<void> fetchPastAppointments() async {
    final token = await LocalStorage.getToken();

    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/past-appointments"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final data = jsonData['data'];
      if (data is! List) return;

      final allAppointments =
          data.map((e) => AppointmentModel.fromJson(e)).toList();

      final completedOrPast = <int, AppointmentModel>{};
      final cancelled = <int, AppointmentModel>{};

      for (final a in allAppointments) {
        if (_isCancelledStatus(a.status)) {
          cancelled[a.appointmentId] = a;
        } else {
          completedOrPast[a.appointmentId] = a;
        }
      }

      pastList = completedOrPast.values.toList();
      cancelledList = cancelled.values.toList();
    }
  }

  /// Cancel allowed until 1 hour before appointment start.
  bool canCancelAppointment(AppointmentModel appointment) {
    final startsAt = _appointmentStartsAt(appointment);
    if (startsAt == null) return false;
    final now = DateTime.now();
    if (!startsAt.isAfter(now)) return false;
    return now.isBefore(startsAt.subtract(const Duration(hours: 1)));
  }

  DateTime? _appointmentStartsAt(AppointmentModel appointment) {
    try {
      final dateRaw = appointment.appointmentDate.trim();
      final timeRaw = appointment.appointmentTime.trim();
      if (dateRaw.isEmpty) return null;

      final datePart = dateRaw.contains('T')
          ? dateRaw.split('T').first
          : dateRaw.split(' ').first;

      var timePart = timeRaw;
      if (timePart.isEmpty) timePart = '00:00:00';

      // Support "10:30 AM" / "10:30"
      final amPm = RegExp(
        r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$',
        caseSensitive: false,
      ).firstMatch(timePart);
      if (amPm != null) {
        var hour = int.parse(amPm.group(1)!);
        final minute = int.parse(amPm.group(2)!);
        final second = int.tryParse(amPm.group(3) ?? '0') ?? 0;
        final period = (amPm.group(4) ?? '').toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        timePart =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
      }

      return DateTime.parse('$datePart $timePart');
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmAndCancel(AppointmentModel appointment) async {
    if (!canCancelAppointment(appointment)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancellation is not allowed within 1 hour of the appointment',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: Text(
          'Cancel your appointment with ${appointment.doctorName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await cancelAppointment(appointment.appointmentId);
    }
  }

  Future<void> cancelAppointment(int appointmentId) async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    try {
      final token = await LocalStorage.getToken();

      final response = await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/appointments/$appointmentId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      final ok = (response.statusCode == 200 || response.statusCode == 204) &&
          (data['success'] == true ||
              data['status'] == true ||
              data['success'] == null);

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Appointment cancelled successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await fetchAppointments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ??
                  'Failed to cancel appointment',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  bool _matchesFilters(AppointmentModel a) {
    final query = searchController.text.toLowerCase().trim();
    if (query.isNotEmpty &&
        !a.doctorName.toLowerCase().contains(query) &&
        !a.specialization.toLowerCase().contains(query) &&
        !a.hospitalName.toLowerCase().contains(query)) {
      return false;
    }

    if (selectedSpecialization != 'All' &&
        a.specialization.toLowerCase().trim() !=
            selectedSpecialization.toLowerCase().trim()) {
      return false;
    }

    return true;
  }

  void _applyFilters() {
    setState(() {
      filteredUpcoming = upcomingList.where(_matchesFilters).toList();
      filteredPast = pastList.where(_matchesFilters).toList();
      filteredCancelled = cancelledList.where(_matchesFilters).toList();
    });
  }

  void _openSpecializationFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        String temp = selectedSpecialization;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Specialization',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: specializationOptions.contains(temp) ? temp : 'All',
                    items: specializationOptions
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => temp = value);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => selectedSpecialization = 'All');
                            Navigator.pop(context);
                            _applyFilters();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B6F71),
                          ),
                          onPressed: () {
                            setState(() => selectedSpecialization = temp);
                            Navigator.pop(context);
                            _applyFilters();
                          },
                          child: const Text(
                            'Apply',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => navigateToHome(context),
          ),
          title:
              const Text("My bookings", style: TextStyle(color: Colors.black)),
          bottom: const TabBar(
            labelColor: Color(0xFF2F3A8F),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF2F3A8F),
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Completed"),
              Tab(text: "Cancelled"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _searchBox(),
                  if (selectedSpecialization != 'All')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          label: Text(selectedSpecialization),
                          onDeleted: () {
                            setState(() => selectedSpecialization = 'All');
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBookingList(filteredUpcoming, true),
                        _buildBookingList(filteredPast, false),
                        _buildBookingList(filteredCancelled, false),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search by name",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Filter by specialization',
            icon: Icon(
              Icons.tune,
              color: selectedSpecialization != 'All'
                  ? const Color(0xFF2F3A8F)
                  : Colors.grey,
            ),
            onPressed: specializationOptions.length > 1
                ? _openSpecializationFilter
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<AppointmentModel> list, bool isUpcoming) {
    return RefreshIndicator(
      color: const Color(0xFF2F3A8F),
      onRefresh: () => fetchAppointments(showSpinner: false),
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text("No appointments found")),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final appointment = list[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bookingDate(
                      "${AppDateFormat.toDisplay(appointment.appointmentDate)} - ${appointment.appointmentTime}",
                    ),
                    const SizedBox(height: 8),
                    _bookingCard(appointment, isUpcoming),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
    );
  }

  Widget _bookingDate(String date) {
    return Text(
      date,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  String _subtitleFor(AppointmentModel appointment) {
    if (appointment.specialization.isNotEmpty) {
      return appointment.specialization;
    }
    return '';
  }

  Widget _bookingCard(AppointmentModel appointment, bool isUpcoming) {
    final subtitle = _subtitleFor(appointment);
    final place = appointment.hospitalName.isNotEmpty
        ? appointment.hospitalName
        : appointment.branchName;
    final allowCancel = isUpcoming && canCancelAppointment(appointment);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  appointment.profileImage,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Image.asset("assets/doc1.png", width: 56, height: 56),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.doctorName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    if (place.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          )
                        ],
                      ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          isUpcoming
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_isCancelling || !allowCancel)
                                ? null
                                : () => _confirmAndCancel(appointment),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RescheduleAppointmentScreen(
                                    appointmentId: appointment.appointmentId,
                                    doctorId: appointment.doctorId,
                                    hospitalId: appointment.hospitalId,
                                    doctorName: appointment.doctorName,
                                    doctorAddress: place.isNotEmpty
                                        ? place
                                        : appointment.branchName,
                                    oldDate: DateTime.parse(
                                        appointment.appointmentDate),
                                    oldTime: appointment.appointmentTime,
                                  ),
                                ),
                              );

                              if (result == true) {
                                fetchAppointments();
                              }
                            },
                            child: const Text("Reschedule"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          LiveAppointmentScreen.routeFromAppointment(
                            appointment,
                          ),
                        ),
                        child: const Text('Live View'),
                      ),
                    ),
                    if (!allowCancel)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Cancel available until 1 hour before appointment',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}
