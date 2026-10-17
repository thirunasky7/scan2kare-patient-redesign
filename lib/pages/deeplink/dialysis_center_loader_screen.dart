import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/dialysis_api_service.dart';
import '../dialysis_center_detail_screen.dart';

/// Deep-link / QR: /view-dialysis-center-detail/:code
class DialysisCenterLoaderScreen extends StatefulWidget {
  final String code;

  const DialysisCenterLoaderScreen({super.key, required this.code});

  @override
  State<DialysisCenterLoaderScreen> createState() =>
      _DialysisCenterLoaderScreenState();
}

class _DialysisCenterLoaderScreenState extends State<DialysisCenterLoaderScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  String _decodedCode() {
    try {
      return utf8.decode(base64Decode(widget.code));
    } catch (_) {
      return widget.code;
    }
  }

  Future<void> _resolve() async {
    try {
      final list = await DialysisApiService.getCenters();
      final want = _decodedCode().toUpperCase();

      Map<String, dynamic>? match;
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final code = (m['code'] ?? '').toString().toUpperCase();
        if (code == want || code == widget.code.toUpperCase()) {
          match = m;
          break;
        }
      }

      if (!mounted) return;
      if (match == null) {
        setState(() => _error = 'Dialysis centre not found');
        return;
      }

      final id = int.tryParse('${match['id']}');
      if (id == null) {
        setState(() => _error = 'Invalid centre');
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DialysisCenterDetailScreen(centerId: id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialysis Centre'),
        backgroundColor: const Color(0xFF2B6F71),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
