import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/common_drawer.dart';
import '../widgets/emergency_sos_button.dart';
import 'home_screen.dart';
import 'hospital_list_screen.dart';
import 'scanner_screen.dart';

/// Opens the shell's drawer from screens nested inside it.
final GlobalKey<ScaffoldState> mainShellScaffoldKey =
    GlobalKey<ScaffoldState>();

void openMainDrawer() => mainShellScaffoldKey.currentState?.openDrawer();

/// Persistent shell that owns the bottom navigation bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = AppNavTab.home});

  final AppNavTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late AppNavTab _tab = widget.initialTab;

  late final Set<AppNavTab> _visited = {widget.initialTab};

  void _select(AppNavTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _screenFor(AppNavTab tab) {
    switch (tab) {
      case AppNavTab.home:
        return const HomeScreen();
      case AppNavTab.recentHospital:
        return const HospitalHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mainShellScaffoldKey,
      drawer: const CommonDrawer(),
      floatingActionButton: const EmergencySosButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: IndexedStack(
        index: AppNavTab.values.indexOf(_tab),
        children: [
          for (final tab in AppNavTab.values)
            _visited.contains(tab) ? _screenFor(tab) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onHome: () => _select(AppNavTab.home),
        onScan: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        onRecentHospital: () => _select(AppNavTab.recentHospital),
      ),
    );
  }
}
