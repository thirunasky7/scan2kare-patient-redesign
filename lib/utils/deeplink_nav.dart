import 'package:flutter/material.dart';

import '../router/app_router.dart';

/// Bumped whenever we navigate to Home so screens can close location search.
final ValueNotifier<int> homeNavigationTick = ValueNotifier<int>(0);

/// Navigate to the main Home page (clears stacked Material routes).
void navigateToHome([BuildContext? context]) => _goToShell('/home');

/// Navigate to the Recent Hospital tab on the same shell as [navigateToHome].
void navigateToRecentHospitalTab([BuildContext? context]) =>
    _goToShell('/home?tab=recent');

void _goToShell(String location) {
  FocusManager.instance.primaryFocus?.unfocus();

  final nav = rootNavigatorKey.currentState;
  if (nav != null && nav.canPop()) {
    nav.popUntil((route) => route.settings is Page);
  }

  homeNavigationTick.value++;
  appRouter.go(location);
}

/// Back from hospital/doctor/diagnostic detail screens.
/// Deep-link / QR URL entries return to Home; in-app flow pops as usual.
void handleDetailBack(BuildContext context, {required bool fromDeepLink}) {
  if (fromDeepLink) {
    navigateToHome(context);
    return;
  }

  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }

  navigateToHome(context);
}
