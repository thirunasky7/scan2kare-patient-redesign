import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/local_storage.dart';
import '../utils/deeplink_nav.dart';
import '../models/scan_appointment.dart';
import '../config/api_config.dart';
import '../utils/booking_status_style.dart';

class MyScanBookingsScreen extends StatefulWidget {
  const MyScanBookingsScreen({super.key});

  @override
  State<MyScanBookingsScreen> createState() => _MyScanBookingsScreenState();
}

class _MyScanBookingsScreenState extends State<MyScanBookingsScreen> {
  List<ScanAppointmentModel> upcomingList = [];
  List<ScanAppointmentModel> pastList = [];
  List<ScanAppointmentModel> cancelledList = [];

  List<ScanAppointmentModel> filteredUpcoming = [];
  List<ScanAppointmentModel> filteredPast = [];
  List<ScanAppointmentModel> filteredCancelled = [];

  bool isLoading = true;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAppointments();
    searchController.addListener(_onSearchChanged);
  }

  // ✅ SINGLE API CALL
  Future<void> fetchAppointments() async {
    setState(() => isLoading = true);

    try {
      final token = await LocalStorage.getToken();

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/scan-bookings-list"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'];

        setState(() {
          upcomingList = (data['upcoming'] as List)
              .map((e) => ScanAppointmentModel.fromJson(e))
              .toList();

          pastList = (data['past'] as List)
              .map((e) => ScanAppointmentModel.fromJson(e))
              .toList();

          cancelledList = (data['cancelled'] as List)
              .map((e) => ScanAppointmentModel.fromJson(e))
              .toList();

          filteredUpcoming = upcomingList;
          filteredPast = pastList;
          filteredCancelled = cancelledList;
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    }

    setState(() => isLoading = false);
  }

  // 🔍 SEARCH (PATIENT NAME)
  void _onSearchChanged() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredUpcoming = upcomingList
          .where((a) => (a.patientName ?? "").toLowerCase().contains(query))
          .toList();

      filteredPast = pastList
          .where((a) => (a.patientName ?? "").toLowerCase().contains(query))
          .toList();

      filteredCancelled = cancelledList
          .where((a) => (a.patientName ?? "").toLowerCase().contains(query))
          .toList();
    });
  }

  // ❌ Cancel API
  Future<void> cancelAppointment(int id) async {
    final token = await LocalStorage.getToken();

    final response = await http.delete(
      Uri.parse("${ApiConfig.baseUrl}/scan-bookings/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Accept": "application/json",
      },
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking cancelled")),
      );
      fetchAppointments();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
          title: const Text(
            "My bookings",
            style: TextStyle(color: Colors.black),
          ),
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
                hintText: "Search by patient name",
                border: InputBorder.none,
              ),
            ),
          ),
          const Icon(Icons.tune, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<ScanAppointmentModel> list, bool isUpcoming) {
    if (list.isEmpty) {
      return const Center(child: Text("No bookings found"));
    }

    return RefreshIndicator(
      onRefresh: fetchAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final a = list[index];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${a.appointmentDate ?? ""} ${a.appointmentTime ?? ""}",
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _bookingCard(a, isUpcoming),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _bookingCard(ScanAppointmentModel a, bool isUpcoming) {
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
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.medical_services),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.patientName ?? "",
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(a.doctorName ?? "Scan",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    if ((a.scanCategory ?? '').isNotEmpty)
                      Text(a.scanCategory!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B6F71))),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            a.branchName ?? "",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        )
                      ],
                    ),
                    if (!isUpcoming && (a.status ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: BookingStatusStyle.badge(a.status),
                      ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (isUpcoming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => cancelAppointment(a.appointmentId),
                    child: const Text("Cancel"),
                  ),
                ),
                // const SizedBox(width: 12),
                // Expanded(
                //   child: ElevatedButton(
                //     onPressed: () {},
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: const Color(0xFF2F3A8F),
                //     ),
                //     child: const Text(
                //       "Reschedule",
                //       style: TextStyle(color: Colors.white),
                //     ),
                //   ),
                // ),
              ],
            )
        ],
      ),
    );
  }
}
