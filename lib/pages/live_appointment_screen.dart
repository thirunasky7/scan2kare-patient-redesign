import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../models/live_appointment.dart';
import '../services/live_appointment_service.dart';

class LiveAppointmentScreen extends StatefulWidget {
  const LiveAppointmentScreen({
    super.key,
    required this.appointmentId,
    this.doctorName,
    this.specialization,
    this.hospitalName,
    this.scheduledTime,
    this.scheduledDate,
  });

  final int appointmentId;
  final String? doctorName;
  final String? specialization;
  final String? hospitalName;
  final String? scheduledTime;
  final String? scheduledDate;

  static Route<void> routeFromAppointment(AppointmentModel appointment) {
    return MaterialPageRoute(
      builder: (_) => LiveAppointmentScreen(
        appointmentId: appointment.appointmentId,
        doctorName: appointment.doctorName,
        specialization: appointment.specialization,
        hospitalName: appointment.hospitalName.isNotEmpty
            ? appointment.hospitalName
            : appointment.branchName,
        scheduledTime: appointment.appointmentTime,
        scheduledDate: appointment.appointmentDate,
      ),
    );
  }

  @override
  State<LiveAppointmentScreen> createState() => _LiveAppointmentScreenState();
}

class _LiveAppointmentScreenState extends State<LiveAppointmentScreen> {
  static const _brand = Color(0xFF2B6F71);
  static const _liveEvents = {
    'QueueUpdated',
    'ETAUpdated',
    'DoctorPaused',
    'DoctorResumed',
    'EmergencyStarted',
    'EmergencyEnded',
    'AppointmentCheckedIn',
    'ConsultationStarted',
    'ConsultationCompleted',
    'AppointmentCancelled',
  };

  PatientLiveView? _view;
  String? _error;
  bool _loading = true;
  bool _checkingIn = false;
  int _lastEventId = 0;
  int _sessionVersion = 0;
  int? _lastEtaMinutes;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final view =
          await LiveAppointmentService.fetchLive(widget.appointmentId);
      if (!mounted) return;
      _maybeNotifyEta(view);
      setState(() {
        _view = view;
        _loading = false;
        _error = null;
      });
      if (initial) {
        final page = await LiveAppointmentService.fetchEvents(
          widget.appointmentId,
        );
        _lastEventId = page.latestEventId ??
            (page.events.isEmpty ? 0 : page.events.last.eventId);
        _sessionVersion = page.sessionVersion ?? 0;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _poll() async {
    if (!mounted || _checkingIn) return;
    try {
      final page = await LiveAppointmentService.fetchEvents(
        widget.appointmentId,
        sinceId: _lastEventId > 0 ? _lastEventId : null,
      );
      final latest = page.latestEventId ??
          (page.events.isEmpty ? _lastEventId : page.events.last.eventId);
      final relevant = page.events.where((e) {
        final name = e.clientEvent ?? e.eventType;
        return _liveEvents.contains(name) || _liveEvents.contains(e.eventType);
      }).toList();

      final incoming = page.sessionVersion ??
          (relevant.isEmpty ? null : relevant.last.sessionVersion);
      final stale = incoming != null &&
          incoming > 0 &&
          _sessionVersion > 0 &&
          incoming < _sessionVersion;

      _lastEventId = latest;
      if (stale) return;

      if (incoming != null && incoming >= _sessionVersion) {
        _sessionVersion = incoming;
      }

      // Laravel is authoritative: always refresh the privacy-safe patient view.
      await _load();
    } catch (_) {
      await _load();
    }
  }

  void _maybeNotifyEta(PatientLiveView view) {
    final next = view.etaMinutes;
    final prev = _lastEtaMinutes;
    _lastEtaMinutes = next;
    if (prev == null || next == null) return;
    final delta = (next - prev).abs();
    if (delta < 10) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your estimated appointment time has been updated.',
          ),
        ),
      );
    });
  }

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check in?'),
        content: const Text(
          'Let the clinic know you have arrived for this visit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check in'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _checkingIn = true);
    try {
      await LiveAppointmentService.checkIn(widget.appointmentId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in confirmed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  String _friendlyStatus(PatientLiveView view) {
    if (!view.live) return 'NOT STARTED';
    if (!view.inQueue) return 'NOT IN QUEUE';
    if (view.state == 'completed') return 'COMPLETED';
    if (view.state == 'no_show') return 'NO SHOW';
    if (view.isCurrent && view.state == 'in_consult') return 'IN CONSULTATION';
    if (view.checkedIn) return 'CHECKED IN';
    if (view.state.isNotEmpty) return view.state.replaceAll('_', ' ').toUpperCase();
    return 'WAITING';
  }

  String _formatEta(PatientLiveView view) {
    if (view.etaStartAt != null) {
      return DateFormat('h:mm a').format(view.etaStartAt!.toLocal());
    }
    if (view.etaMinutes != null) return 'In ${view.etaMinutes} min';
    return '—';
  }

  String _formatScheduled() {
    final planned = _view?.plannedTime;
    if (planned != null && planned.isNotEmpty) return planned;
    return widget.scheduledTime ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          'Live View',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : _error != null && _view == null
              ? _ErrorBody(message: _error!, onRetry: () => _load(initial: true))
              : RefreshIndicator(
                  color: _brand,
                  onRefresh: () => _load(initial: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeaderCard(
                        doctorName: widget.doctorName ?? 'Your doctor',
                        specialization: widget.specialization ?? '',
                        hospitalName: widget.hospitalName ?? '',
                      ),
                      const SizedBox(height: 12),
                      if (_view != null) ..._statusBanners(_view!),
                      _InfoCard(
                        scheduled: _formatScheduled(),
                        date: widget.scheduledDate,
                        queue: _view?.inQueue == true
                            ? '#${_view!.queueNumber}'
                            : '—',
                        eta: _view == null ? '—' : _formatEta(_view!),
                        status: _view == null
                            ? '—'
                            : _friendlyStatus(_view!),
                        checkedIn: _view?.checkedIn == true,
                      ),
                      if (_view != null &&
                          _view!.live &&
                          _view!.inQueue &&
                          !_view!.checkedIn) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _checkingIn ? null : _checkIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                            ),
                            child: _checkingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Check in'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<Widget> _statusBanners(PatientLiveView view) {
    final banners = <Widget>[];
    if (view.doctorUnavailable) {
      banners.add(const _Banner(
        text: 'Doctor temporarily unavailable.',
        color: Color(0xFFB45309),
      ));
      banners.add(const SizedBox(height: 8));
      banners.add(const _Banner(
        text: 'Your estimated appointment time has been updated.',
        color: _brand,
      ));
      banners.add(const SizedBox(height: 12));
    } else if ((view.delayMinutes ?? 0) > 0) {
      banners.add(const _Banner(
        text: 'Doctor is running late.',
        color: Color(0xFFB45309),
      ));
      banners.add(const SizedBox(height: 12));
    }
    if (!view.live && (view.message ?? '').isNotEmpty) {
      banners.add(_Banner(text: view.message!, color: _brand));
      banners.add(const SizedBox(height: 12));
    }
    return banners;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.doctorName,
    required this.specialization,
    required this.hospitalName,
  });

  final String doctorName;
  final String specialization;
  final String hospitalName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doctorName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (specialization.isNotEmpty)
            Text(
              specialization,
              style: GoogleFonts.poppins(color: Colors.black54),
            ),
          if (hospitalName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hospitalName,
              style: GoogleFonts.poppins(color: Colors.black45, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.scheduled,
    required this.queue,
    required this.eta,
    required this.status,
    required this.checkedIn,
    this.date,
  });

  final String scheduled;
  final String? date;
  final String queue;
  final String eta;
  final String status;
  final bool checkedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _row('Scheduled', scheduled),
          if (date != null && date!.isNotEmpty) _row('Date', date!),
          _row('Queue', queue),
          _row('Estimated', eta),
          _row('Status', status),
          _row('Check-in', checkedIn ? 'Confirmed' : 'Not checked in'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B6F71),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
