import 'package:flutter/material.dart';

class AppointmentData {
  final String day;
  final String date;
  final String time;
  final String doctorName;
  final String specialty;
  final Color cardColor;
  final Color textColor;

  AppointmentData({
    required this.day,
    required this.date,
    required this.time,
    required this.doctorName,
    required this.specialty,
    this.cardColor = Colors.blue,
    this.textColor = Colors.white,
  });
}
