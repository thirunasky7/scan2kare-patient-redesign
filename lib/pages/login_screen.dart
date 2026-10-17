import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  static const String countryCode = '+91';

  static const Color _brand = Color(0xFF2B6F71);
  static const Color _brandLight = Color(0xFF3E9799);
  static const Color _text = Color(0xFF16211F);
  static const Color _muted = Color(0xFF6E7E7E);

  static const int _phoneLength = 10;

  bool _isCooldown = false;
  bool _isSending = false;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    phoneController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _isCooldown = true);
    _cooldownTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isCooldown = false);
      }
    });
  }

  Future<void> _onSendOtp() async {
    if (_isCooldown || _isSending) return;

    final phone = phoneController.text.trim();
    if (phone.length < _phoneLength) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    final result = await AuthService.sendOtp(phone);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] == true) {
      _startCooldown();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => OtpVerifyScreen(phone: phone),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Failed to send OTP'),
          backgroundColor: const Color(0xFFD5443B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/gradient.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      _brandMark(),
                      const SizedBox(height: 28),
                      const Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _text,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to book doctors, scans and more',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: _muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _card(),
                      const SizedBox(height: 20),
                      _legalNote(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandMark() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _brand.withOpacity(0.16),
              blurRadius: 30,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Image.asset(
          'assets/app-logo.png',
          height: 46,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.local_hospital_rounded,
            size: 46,
            color: _brand,
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.10),
            blurRadius: 34,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: phoneController,
        builder: (context, value, _) {
          final complete = value.text.length == _phoneLength;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mobile number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              _phoneField(complete),
              const SizedBox(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 15, color: _muted),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'We’ll text you a one-time code to confirm this number.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _submitButton(complete),
            ],
          );
        },
      ),
    );
  }

  Widget _phoneField(bool complete) {
    return TextFormField(
      controller: phoneController,
      keyboardType: TextInputType.phone,
      cursorColor: _brand,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_phoneLength),
      ],
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _text,
        letterSpacing: 0.6,
      ),
      onFieldSubmitted: (_) => complete ? _onSendOtp() : null,
      decoration: InputDecoration(
        hintText: '00000 00000',
        hintStyle: TextStyle(
          color: _muted.withOpacity(0.55),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF3F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                countryCode,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 22, color: const Color(0xFFDDE6E6)),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: complete
            ? const Icon(Icons.check_circle_rounded, color: _brand, size: 22)
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2EAEA), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _brand, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _submitButton(bool complete) {
    final busy = _isSending || _isCooldown;
    final enabled = complete && !busy;

    final String label = _isSending
        ? 'Sending code…'
        : _isCooldown
            ? 'Please wait…'
            : 'Continue';

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_brandLight, _brand],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _brand.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? _onSendOtp : null,
            child: SizedBox(
              height: 54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSending) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (!busy) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 19),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legalNote() {
    return const Text(
      'By continuing you agree to our Terms of Service\nand Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11.5, color: _muted, height: 1.5),
    );
  }
}
