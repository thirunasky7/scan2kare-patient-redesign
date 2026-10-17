import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../services/favorites_service.dart';
import '../utils/local_storage.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String phone;

  const OtpVerifyScreen({super.key, required this.phone});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final TextEditingController otpController = TextEditingController();
  final FocusNode _otpFocus = FocusNode();

  static const Color _brand = Color(0xFF2B6F71);
  static const Color _brandLight = Color(0xFF3E9799);
  static const Color _text = Color(0xFF16211F);
  static const Color _muted = Color(0xFF6E7E7E);
  static const Color _danger = Color(0xFFD5443B);

  static const int _otpLength = 6;

  int secondsRemaining = 30;
  Timer? timer;
  bool canResend = false;

  bool isLoading = false;
  bool isResending = false;
  String? otpError;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    secondsRemaining = 30;
    canResend = false;

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (secondsRemaining == 0) {
        setState(() => canResend = true);
        t.cancel();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    otpController.dispose();
    _otpFocus.dispose();
    timer?.cancel();
    super.dispose();
  }

  String get _prettyPhone {
    final p = widget.phone;
    return p.length == 10 ? '${p.substring(0, 5)} ${p.substring(5)}' : p;
  }

  void _onOtpChanged(String value) {
    setState(() {
      if (otpError != null) otpError = null;
    });
    if (value.length == _otpLength && !isLoading) {
      FocusScope.of(context).unfocus();
      verifyOtp();
    }
  }

  Future<void> verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length < _otpLength) {
      setState(() => otpError = 'Enter the $_otpLength-digit code');
      return;
    }

    setState(() {
      isLoading = true;
      otpError = null;
    });

    try {
      final pendingPath = await DeepLinkService.getPendingPath();

      final response = await AuthService.verifyOtp(
        widget.phone,
        otp,
        pendingPath: pendingPath,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final token = response['token']?.toString();
      final deeplink = response['deeplink'] is Map
          ? Map<String, dynamic>.from(response['deeplink'] as Map)
          : null;

      if (token != null && token.isNotEmpty) {
        await LocalStorage.saveToken(token);

        final user = response['data'];
        if (user is Map) {
          await LocalStorage.saveUser(Map<String, dynamic>.from(user));
        }

        unawaited(FavoritesService.seed());

        await DeepLinkService.navigateAfterLogin(
          deeplink: deeplink,
          redirectPath: response['redirect_path']?.toString(),
        );

        if (mounted) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) {
            nav.pop();
          }
        }
      } else {
        setState(() {
          otpError = response['message']?.toString() ?? 'Verification failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          otpError = 'Network error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _resend() async {
    if (isResending) return;
    setState(() => isResending = true);

    final result = await AuthService.sendOtp(widget.phone);
    if (!mounted) return;

    setState(() => isResending = false);

    if (result['success'] == true) {
      otpController.clear();
      setState(() => otpError = null);
      startTimer();
      _otpFocus.requestFocus();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (result['success'] == true ? 'OTP resent' : 'Failed to send OTP'),
        ),
        backgroundColor: result['success'] == true ? _brand : _danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE6E6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms_outlined, color: _brand, size: 26),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify your number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 13.5,
                color: _muted,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Enter the 6-digit code sent on '),
                const TextSpan(
                  text: 'WhatsApp',
                  style: TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' to\n'),
                TextSpan(
                  text: '+91 $_prettyPhone',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _otpBoxes(),
          if (otpError != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: _danger),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    otpError!,
                    style: const TextStyle(
                      color: _danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          _verifyButton(),
          const SizedBox(height: 14),
          _resendRow(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _otpBoxes() {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_otpLength, (i) {
            final text = otpController.text;
            final filled = i < text.length;
            final isNext = i == text.length && _otpFocus.hasFocus;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? Colors.white : const Color(0xFFF3F7F7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: otpError != null
                      ? _danger
                      : isNext
                          ? _brand
                          : filled
                              ? _brand.withOpacity(0.55)
                              : const Color(0xFFE2EAEA),
                  width: isNext || filled ? 1.8 : 1.4,
                ),
              ),
              child: Text(
                filled ? text[i] : '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: TextField(
            controller: otpController,
            focusNode: _otpFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_otpLength),
            ],
            enableInteractiveSelection: false,
            showCursor: false,
            style: const TextStyle(color: Colors.transparent, height: 0.01),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: _onOtpChanged,
          ),
        ),
      ],
    );
  }

  Widget _verifyButton() {
    final complete = otpController.text.length == _otpLength;
    final enabled = complete && !isLoading;

    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.5,
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
            onTap: enabled ? verifyOtp : null,
            child: SizedBox(
              height: 54,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Verify & continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resendRow() {
    if (isResending) {
      return const Center(
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
        ),
      );
    }

    if (!canResend) {
      return Center(
        child: Text(
          'Resend code in ${secondsRemaining}s',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      );
    }

    return Center(
      child: TextButton(
        onPressed: _resend,
        style: TextButton.styleFrom(
          foregroundColor: _brand,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        child: const Text('Didn’t get it?  Resend code'),
      ),
    );
  }
}
