import 'package:flutter/material.dart';

import '../models/dialysis_models.dart';
import '../services/dialysis_api_service.dart';
import '../utils/api_error.dart';
import '../utils/app_date_format.dart';
import '../utils/booking_status_style.dart';
import 'dialysis_center_detail_screen.dart';

class DialysisBookingsScreen extends StatefulWidget {
  const DialysisBookingsScreen({super.key});

  @override
  State<DialysisBookingsScreen> createState() => _DialysisBookingsScreenState();
}

class _DialysisBookingsScreenState extends State<DialysisBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<DialysisBookingItem> upcoming = [];
  List<DialysisBookingItem> past = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await DialysisApiService.getBookings();
      final up = (data['upcoming'] as List? ?? [])
          .map((e) =>
              DialysisBookingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final pa = (data['past'] as List? ?? [])
          .map((e) =>
              DialysisBookingItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        upcoming = up;
        past = pa;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyException(
            e,
            fallback: 'Could not load your dialysis bookings.',
          )),
        ),
      );
    }
  }

  Future<void> _reschedule(DialysisBookingItem b) async {
    if (b.centerId == null || b.centerId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this booking for reschedule.'),
        ),
      );
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DialysisCenterDetailScreen(
          centerId: b.centerId!,
          rescheduleBooking: b,
        ),
      ),
    );
    if (result == true && mounted) {
      _load();
    }
  }

  Future<void> _cancel(DialysisBookingItem b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text('Cancel ${b.bookingReference ?? 'this booking'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DialysisApiService.cancelBooking(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyException(
            e,
            fallback: 'Could not cancel this booking. Please try again.',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0x1F62C6FF),
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Dialysis Bookings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF2B6F71),
          labelColor: const Color(0xFF2B6F71),
          unselectedLabelColor: Colors.grey.shade600,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
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
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _list(upcoming, canCancel: true),
                      _list(past, canCancel: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<DialysisBookingItem> items, {required bool canCancel}) {
    if (items.isEmpty) {
      return const Center(child: Text('No bookings'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final b = items[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.centerName ?? 'Dialysis centre',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      BookingStatusStyle.badge(b.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '${AppDateFormat.toLongDisplay(b.bookingDate)} · ${b.slotTime ?? ''}'
                        '${b.shift != null && b.shift!.isNotEmpty ? ' · ${b.shift}' : ''}',
                      ),
                    ],
                  ),
                  if (b.patientName != null) ...[
                    const SizedBox(height: 6),
                    Text('Patient: ${b.patientName}'),
                  ],
                  if (b.machineName != null) ...[
                    const SizedBox(height: 4),
                    Text('Machine: ${b.machineName}'),
                  ],
                  if (b.bookingReference != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ref: ${b.bookingReference}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                  if (canCancel && b.canReschedule) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _cancel(b),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2B6F71),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _reschedule(b),
                            child: const Text('Reschedule'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
