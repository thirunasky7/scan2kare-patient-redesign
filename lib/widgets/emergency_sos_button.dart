import 'package:flutter/material.dart';

import '../pages/emergency_booking_screen.dart';

/// Floating emergency-booking shortcut, always on screen regardless of scroll.
class EmergencySosButton extends StatefulWidget {
  const EmergencySosButton({super.key});

  @override
  State<EmergencySosButton> createState() => _EmergencySosButtonState();
}

class _EmergencySosButtonState extends State<EmergencySosButton>
    with SingleTickerProviderStateMixin {
  static const Color _red = Color(0xFFE11D48);
  static const Color _redDeep = Color(0xFFBE123C);
  static const double _size = 56;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  bool _pressed = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyBookingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency booking',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _open();
        },
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = _pulse.value;
                  return Opacity(
                    opacity: (1 - t) * 0.4,
                    child: Transform.scale(
                      scale: 1 + (t * 0.5),
                      child: Container(
                        width: _size,
                        height: _size,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedScale(
                scale: _pressed ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_red, _redDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _red.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emergency_share_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
