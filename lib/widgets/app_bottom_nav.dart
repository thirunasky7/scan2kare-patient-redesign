import 'package:flutter/material.dart';

/// Which primary tab the current screen represents.
enum AppNavTab { home, recentHospital }

/// Shared bottom navigation bar used by [MainShell] and pushed screens.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    this.current,
    required this.onHome,
    required this.onScan,
    required this.onRecentHospital,
  });

  /// The active tab, or null on screens that are neither (Health Hub).
  final AppNavTab? current;
  final VoidCallback onHome;
  final VoidCallback onScan;
  final VoidCallback onRecentHospital;

  static const Color brand = Color(0xFF2B6F71);
  static const Color _brandLight = Color(0xFF3E9799);
  static const Color _inactive = Color(0xFF98A6A6);
  static const double _barHeight = 66;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF4F9F9)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: brand.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: brand.withOpacity(0.10),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: current == AppNavTab.home,
                  onTap: onHome,
                ),
              ),
              SizedBox(width: 84, child: _ScanButton(onTap: onScan)),
              Expanded(
                child: _NavItem(
                  icon: Icons.medical_services_outlined,
                  activeIcon: Icons.medical_services_rounded,
                  label: 'Recent',
                  selected: current == AppNavTab.recentHospital,
                  onTap: onRecentHospital,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppBottomNav.brand : AppBottomNav._inactive;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppBottomNav.brand.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          AppBottomNav.brand.withOpacity(0.16),
                          AppBottomNav._brandLight.withOpacity(0.08),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedScale(
                scale: selected ? 1.12 : 1.0,
                duration: _duration,
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? activeIcon : icon,
                  color: color,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: _duration,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                letterSpacing: selected ? 0.2 : 0,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Semantics(
          button: true,
          label: 'Scan QR code',
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppBottomNav._brandLight, AppBottomNav.brand],
                  ),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppBottomNav.brand.withOpacity(0.45),
                      blurRadius: 18,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
