import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/appointment_service.dart';
import '../utils/deeplink_nav.dart';

class AppointmentPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  final int doctorId;
  final int hospitalId;
  final String hospitalAddress;
  final String doctorName;
  final String hospitalName;
  final String doctorImage;
  final String hospitalPhone;

  const AppointmentPreviewScreen({
    super.key,
    required this.appointmentData,
    required this.doctorId,
    required this.hospitalId,
    required this.hospitalAddress,
    required this.doctorName,
    required this.hospitalName,
    required this.doctorImage,
    this.hospitalPhone = '',
  });

  @override
  State<AppointmentPreviewScreen> createState() =>
      _AppointmentPreviewScreenState();
}

class _AppointmentPreviewScreenState extends State<AppointmentPreviewScreen> {
  bool _isLoading = false;

  // ✅ SAFE DATA ACCESS
  Map<String, dynamic> get patient => widget.appointmentData['patient'] ?? {};

  DateTime get appointmentDate {
    try {
      return DateTime.parse(widget.appointmentData['date'] ?? '');
    } catch (_) {
      return DateTime.now();
    }
  }

  String get appointmentTime =>
      widget.appointmentData['time']?.toString() ?? '-';

  String get notes => widget.appointmentData['notes']?.toString() ?? '';

  int get patientId => patient['id'] ?? 0;

  String get patientName => patient['name']?.toString() ?? 'Unknown';

  String get patientPhone => patient['phone']?.toString() ?? '-';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.doctorName,
          style: const TextStyle(color: Colors.black),
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
                  widget.hospitalAddress,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                )
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0x1F62C6FF),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appointment Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // ================= DETAILS =================
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          icon: Icons.calendar_today,
                          title:
                              DateFormat('dd MMM yyyy').format(appointmentDate),
                          subtitle: 'Appointment Date',
                        ),
                        _divider(),
                        _infoRow(
                          icon: Icons.access_time,
                          title: appointmentTime,
                          subtitle: 'Appointment Time',
                        ),
                        _divider(),
                        _infoRow(
                          icon: Icons.person,
                          title: patientName,
                          subtitle: "Patient Name",
                        ),
                        _infoRow(
                          icon: Icons.phone,
                          title: patientPhone,
                          subtitle: 'Contact Number',
                        ),
                        if (widget.hospitalPhone.trim().isNotEmpty) ...[
                          _divider(),
                          _infoRow(
                            icon: Icons.local_hospital_outlined,
                            title: widget.hospitalPhone.trim(),
                            subtitle: 'Hospital Phone',
                          ),
                        ],
                        if (notes.isNotEmpty) ...[
                          _divider(),
                          _infoRow(
                            icon: Icons.note,
                            title: notes,
                            subtitle: 'Notes',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ================= DOCTOR =================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1F62C6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage: widget.doctorImage.isNotEmpty
                              ? NetworkImage(widget.doctorImage)
                              : null,
                          child: widget.doctorImage.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(widget.doctorName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================= CONFIRM =================
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
                onPressed:
                    _isLoading || patientId == 0 ? null : _confirmBooking,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Confirm booking",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= API =================
  Future<void> _confirmBooking() async {
    setState(() => _isLoading = true);

    try {
      final success = await AppointmentService.createAppointment(
        doctorId: widget.doctorId,
        hospitalId: widget.hospitalId,
        patientId: patientId,
        date: appointmentDate,
        time: appointmentTime,
        notes: notes,
      );

      setState(() => _isLoading = false);

      if (success) {
        _showSuccessDialog(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Booking Error: $e");
    }
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Success"),
        content: const Text("Appointment booked successfully"),
        actions: [
          TextButton(
            onPressed: () {
              navigateToHome(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
}
