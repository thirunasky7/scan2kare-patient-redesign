import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brand = Color(0xFF2B6F71);
  static const Color _accentGreen = Color(0xFF22C55E);
  static const Color _ink = Color(0xFF16211F);
  static const Color _muted = Color(0xFF6E7E7E);

  /// One controller for the whole screen: a single staged fade-in, then still.
  /// No looping glow, drifting particles or shimmer — a splash is on screen
  /// for barely a second, and continuous motion in that window reads as busy
  /// rather than polished.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
  );

  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.88,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  );

  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    ),
  );

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    try {
      await _entrance.forward();
      await Future.delayed(const Duration(milliseconds: 1100));

      if (!mounted) return;

      final currentPath = GoRouterState.of(context).uri.path;
      if (currentPath != '/splash') return;

      await navigateFromSplash(context);
    } catch (e) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          // Clean clinical wash: white at the top settling into a pale mint,
          // matching the light gradient the rest of the app already uses.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF2FAF9), Color(0xFFE4F2F1)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // A single flat ECG trace across the lower third — a static
            // medical cue that carries the theme without another moving part.
            Positioned(
              left: 0,
              right: 0,
              bottom: 190,
              child: CustomPaint(
                size: const Size(double.infinity, 56),
                painter: _EcgLinePainter(),
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: _LogoCard(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textFade,
                        child: Column(
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'SCAN',
                                    style: TextStyle(color: _ink),
                                  ),
                                  TextSpan(
                                    text: '2',
                                    style: TextStyle(color: _accentGreen),
                                  ),
                                  TextSpan(
                                    text: 'KARE',
                                    style: TextStyle(color: _ink),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Scan  •  Connect  •  Care',
                                style: TextStyle(
                                  color: _brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: FadeTransition(
                opacity: _footerFade,
                child: Column(
                  children: [
                    // Functional rather than decorative: the only motion left
                    // on the screen, and it is there to say "still working".
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: _brand.withOpacity(0.12),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(_brand),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Your health, simplified',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app mark on a clean white disc with a soft teal halo — clinical and
/// uncluttered, no blur layers or animated rim light.
class _LogoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _SplashScreenState._brand.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: _SplashScreenState._brand.withOpacity(0.14),
            blurRadius: 34,
            spreadRadius: -4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Image.asset(
        'assets/icon/app_icon_new.png',
        errorBuilder: (_, __, ___) => const Icon(
          Icons.local_hospital_rounded,
          size: 64,
          color: _SplashScreenState._brand,
        ),
      ),
    );
  }
}

/// Flat baseline with a single QRS complex in the middle — the shape reads as
/// "medical" instantly and costs nothing to draw.
class _EcgLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _SplashScreenState._brand.withOpacity(0.16)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final midY = size.height / 2;
    final centre = size.width / 2;
    final path = Path()..moveTo(0, midY);

    // Lead-in, then the spike, then back to a flat trace.
    path
      ..lineTo(centre - 76, midY)
      ..lineTo(centre - 58, midY - 8)
      ..lineTo(centre - 40, midY + 10)
      ..lineTo(centre - 22, midY - 26)
      ..lineTo(centre - 4, midY + 22)
      ..lineTo(centre + 14, midY)
      ..lineTo(centre + 40, midY)
      ..lineTo(centre + 54, midY - 10)
      ..lineTo(centre + 68, midY)
      ..lineTo(size.width, midY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}