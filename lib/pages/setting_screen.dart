import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../utils/auth_nav.dart';
import 'account_profiles_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw "Could not launch $url";
    }
  }

  Future<void> _logout(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logging out...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint("Logout API failed: $e");
    }

    if (context.mounted) {
      goToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          /// Background
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),

          /// Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ACCOUNT
                  _sectionCard(
                    children: [
                      _item(
                        icon: Icons.person_outline,
                        title: "Profile",
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileUpdateScreen(),
                            ),
                          );
                        },
                      ),
                      _item(
                        icon: Icons.person_outline,
                        title: "Patient Profiles",
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PatientProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// LEGAL
                  _sectionTitle("Legal"),
                  _sectionCard(
                    children: [
                      _item(
                        icon: Icons.description_outlined,
                        title: "Terms & Conditions",
                        onTap: () {
                          openUrl("https://scan2kare.com/terms-and-conditions");
                        },
                      ),
                      _divider(),
                      _item(
                        icon: Icons.privacy_tip_outlined,
                        title: "Privacy Policy",
                        onTap: () {
                          openUrl("https://scan2kare.com/privacy-policy");
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// SUPPORT
                  _sectionTitle("Support"),
                  _sectionCard(
                    children: [
                      _item(
                        icon: Icons.help_outline,
                        title: "Help & Support",
                        onTap: () {
                          openUrl("https://scan2kare.com/contact-us");
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  _logoutButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SECTION TITLE
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// CARD
  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  /// ITEM
  Widget _item({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  /// DIVIDER
  Widget _divider() {
    return Divider(height: 1, color: Colors.grey.shade200);
  }

  Widget _logoutButton(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  // Close the dialog
                  Navigator.pop(dialogContext);
                  // Call logout with the original context
                  _logout(context);
                },
                child: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            "Logout",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
