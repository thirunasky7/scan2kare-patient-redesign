import '../router/app_router.dart';

/// Always navigate to Login via go_router (clears leftover MaterialPageRoutes).
void goToLogin() {
  final nav = rootNavigatorKey.currentState;
  if (nav != null && nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
  }
  appRouter.go('/login');
}

void goToHome() {
  appRouter.go('/home');
}
