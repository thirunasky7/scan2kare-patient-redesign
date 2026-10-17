import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  double _dragPosition = 0.0;
  final double _sliderWidth = 320;
  final double _handleSize = 56;
  bool _isUnlocked = false;

  bool get _isCompleted => _dragPosition >= (_sliderWidth - _handleSize - 20);

  /// ===============================
  /// LOCATION PERMISSION HANDLER
  /// ===============================
  /// Soft request only — do not open Settings or block Login (App Store 5.1.x).
  Future<void> _requestLocationPermissionSoft() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var status = await Permission.location.status;
      if (status.isDenied) {
        await Permission.location.request();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                "Don't waste your time.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),

              const SizedBox(height: 10),

              const Text(
                "Your Health.Our\nPriority.",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 30),

              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/starter-img.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Trusted Healthcare at\nyour Fingertip",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 30),

              /// SLIDER BUTTON
              Center(
                child: SizedBox(
                  width: _sliderWidth,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Background bar
                      Container(
                        width: _sliderWidth,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              width: _dragPosition + _handleSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2B6F71),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            const Center(
                              child: Text(
                                "Let's Get Started...",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Draggable handle
                      Positioned(
                        left: _dragPosition,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (_) {
                            HapticFeedback.selectionClick();
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _dragPosition += details.delta.dx;
                              _dragPosition = _dragPosition.clamp(
                                0.0,
                                _sliderWidth - _handleSize,
                              );
                            });
                          },
                          onPanEnd: (details) async {
                            if (_isCompleted) {
                              setState(() {
                                _isUnlocked = true;
                                _dragPosition = _sliderWidth - _handleSize;
                              });

                              HapticFeedback.mediumImpact();

                              await Future.delayed(
                                  const Duration(milliseconds: 300));

                              // Soft location request — never block Login.
                              await _requestLocationPermissionSoft();

                              if (!context.mounted) return;

                              // Use go_router so OTP → Home navigation works.
                              context.go('/login');
                            } else {
                              HapticFeedback.lightImpact();
                              await Future.delayed(
                                  const Duration(milliseconds: 50));
                              setState(() {
                                _dragPosition = 0;
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: _handleSize,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _isCompleted
                                  ? Colors.green
                                  : const Color(0xFF2B6F71),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _dragPosition > 0 && !_isCompleted ? 0.7 : 0,
                  child: const Text(
                    "Slide to continue →",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
