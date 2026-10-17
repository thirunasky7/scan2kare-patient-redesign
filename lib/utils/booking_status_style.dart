import 'package:flutter/material.dart';

class BookingStatusStyle {
  final Color background;
  final Color foreground;
  final String label;

  const BookingStatusStyle({
    required this.background,
    required this.foreground,
    required this.label,
  });

  static BookingStatusStyle of(String? raw) {
    final key = (raw ?? '').toLowerCase().trim();
    switch (key) {
      case 'pending':
        return const BookingStatusStyle(
          background: Color(0xFFFFF3CD),
          foreground: Color(0xFF856404),
          label: 'Pending',
        );
      case 'accepted':
      case 'confirmed':
      case 'booked':
        return const BookingStatusStyle(
          background: Color(0xFFCFE2FF),
          foreground: Color(0xFF084298),
          label: 'Accepted',
        );
      case 'scan_completed':
        return const BookingStatusStyle(
          background: Color(0xFFCFF4FC),
          foreground: Color(0xFF055160),
          label: 'Scan Completed – Report Pending',
        );
      case 'completed':
        return const BookingStatusStyle(
          background: Color(0xFFD1E7DD),
          foreground: Color(0xFF0F5132),
          label: 'Completed',
        );
      case 'cancelled':
      case 'canceled':
        return const BookingStatusStyle(
          background: Color(0xFFF8D7DA),
          foreground: Color(0xFF842029),
          label: 'Cancelled',
        );
      case 'rescheduled':
        return const BookingStatusStyle(
          background: Color(0xFFFFE5D0),
          foreground: Color(0xFF984C0C),
          label: 'Rescheduled',
        );
      case 'overdue':
        return const BookingStatusStyle(
          background: Color(0xFFF8D7DA),
          foreground: Color(0xFF842029),
          label: 'Overdue',
        );
      default:
        return BookingStatusStyle(
          background: const Color(0xFFE9ECEF),
          foreground: const Color(0xFF495057),
          label: (raw == null || raw.isEmpty) ? 'Unknown' : raw,
        );
    }
  }

  static Widget badge(String? status) {
    final style = of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 11,
          color: style.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
