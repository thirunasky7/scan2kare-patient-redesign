import 'package:flutter/material.dart';

import '../pages/dialysis_bookings_screen.dart';
import '../pages/dialysis_centers_screen.dart';
import '../pages/health_hub_screen.dart';
import '../pages/health_hub_video_screen.dart';
import '../pages/my_bookings_screen.dart';
import '../pages/profile_screen.dart';
import '../pages/scan_booking_history.dart';
import '../pages/second_opinion_landing.dart';
import '../pages/setting_screen.dart';
import '../services/auth_service.dart';
import '../utils/auth_nav.dart';
import '../utils/local_storage.dart';

class CommonDrawer extends StatelessWidget {
  const CommonDrawer({super.key});

  static const Color _brand = Color(0xFF2B6F71);
  static const Color _brandLight = Color(0xFF3E9799);
  static const Color _text = Color(0xFF1F2A2A);
  static const Color _muted = Color(0xFF7C8A8A);

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    Navigator.pop(context);
    await AuthService.logout();
    goToLogin();
  }

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFBFDFD),
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const _DrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              children: [
                _SectionLabel('Account'),
                _DrawerItem(
                  icon: Icons.person_outline_rounded,
                  label: 'My Profile',
                  onTap: () => _go(context, const ProfileUpdateScreen()),
                ),
                _DrawerExpansion(
                  icon: Icons.event_note_rounded,
                  label: 'My Bookings',
                  children: [
                    _SubItem(
                      icon: Icons.local_hospital_outlined,
                      label: 'Hospitals',
                      onTap: () => _go(context, const MyBookingsScreen()),
                    ),
                    _SubItem(
                      icon: Icons.biotech_outlined,
                      label: 'Scan Centers',
                      onTap: () => _go(context, const MyScanBookingsScreen()),
                    ),
                    _SubItem(
                      icon: Icons.water_drop_outlined,
                      label: 'Dialysis',
                      onTap: () => _go(context, const DialysisBookingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SectionLabel('Explore'),
                _DrawerItem(
                  icon: Icons.local_hospital_outlined,
                  label: 'Dialysis Centres',
                  onTap: () => _go(context, const DialysisCentersScreen()),
                ),
                _DrawerExpansion(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Health Hub',
                  children: [
                    _SubItem(
                      icon: Icons.article_outlined,
                      label: 'Articles',
                      onTap: () => _go(context, const HealthHubScreen()),
                    ),
                    _SubItem(
                      icon: Icons.play_circle_outline,
                      label: 'Videos',
                      onTap: () => _go(context, const HealthHubVideoScreen()),
                    ),
                  ],
                ),
                _DrawerItem(
                  icon: Icons.forum_outlined,
                  label: 'Second Opinion',
                  onTap: () => _go(context, const SecondOptionScreen()),
                ),
                const SizedBox(height: 14),
                _SectionLabel('More'),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _go(context, const SettingsScreen()),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD5443B),
                        backgroundColor:
                            const Color(0xFFD5443B).withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Image.asset(
                    'assets/app-logo.png',
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CommonDrawer._brandLight, CommonDrawer._brand],
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: LocalStorage.getUser(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final imageUrl = user?['profile_image']?.toString() ?? '';
              final phone = user?['phone']?.toString() ?? '';

              return ValueListenableBuilder<String>(
                valueListenable: LocalStorage.displayNameNotifier,
                builder: (context, name, _) {
                  final display = name.trim().isEmpty ? 'Guest' : name.trim();

                  return Row(
                    children: [
                      _Avatar(imageUrl: imageUrl, name: display),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone.isEmpty ? 'View and edit profile' : phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl, required this.name});

  final String imageUrl;
  final String name;

  static const double _size = 54;

  bool get _hasPhoto =>
      imageUrl.isNotEmpty && !imageUrl.contains('defaultt-icons');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: ClipOval(
        child: _hasPhoto
            ? Image.network(
                imageUrl,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initial(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _initial(),
              )
            : _initial(),
      ),
    );
  }

  Widget _initial() => Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: CommonDrawer._muted,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _IconChip(icon: icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: CommonDrawer._text,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: CommonDrawer._muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerExpansion extends StatelessWidget {
  const _DrawerExpansion({
    required this.icon,
    required this.label,
    required this.children,
  });

  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 22, bottom: 4),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: CommonDrawer._brand,
        collapsedIconColor: CommonDrawer._muted,
        leading: _IconChip(icon: icon),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: CommonDrawer._text,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  const _SubItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: CommonDrawer._muted),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: CommonDrawer._text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: CommonDrawer._brand.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: CommonDrawer._brand),
    );
  }
}
