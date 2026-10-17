import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/deeplink/diagnostic_center_screen.dart';
import '../pages/deeplink/dialysis_center_loader_screen.dart';
import '../pages/deeplink/doctor_booking_screen.dart';
import '../pages/deeplink/doctor_profile_loader_screen.dart';
import '../pages/deeplink/hospital_details_screen.dart';
import '../pages/deeplink/resolve_link_screen.dart';
import '../pages/live_appointment_screen.dart';
import '../pages/get_started_screen.dart';
import '../pages/login_screen.dart';
import '../pages/main_shell.dart';
import '../pages/profile_screen.dart';
import '../pages/splash_screen.dart';
import '../models/appointment.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/deep_link_service.dart';
import '../utils/token_storage.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

late final GoRouter appRouter;

GoRouter createAppRouter() {
  appRouter = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    redirect: _authRedirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/get-started',
        builder: (_, __) => const GetStartedScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, state) => MainShell(
          initialTab: state.uri.queryParameters['tab'] == 'recent'
              ? AppNavTab.recentHospital
              : AppNavTab.home,
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, state) {
          final setup = state.uri.queryParameters['setup'] == '1';
          return ProfileUpdateScreen(isFirstLoginSetup: setup);
        },
      ),
      GoRoute(
        path: '/appointments/:id/live',
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final extra = state.extra;
          if (extra is AppointmentModel) {
            return LiveAppointmentScreen(
              appointmentId: extra.appointmentId,
              doctorName: extra.doctorName,
              specialization: extra.specialization,
              hospitalName: extra.hospitalName.isNotEmpty
                  ? extra.hospitalName
                  : extra.branchName,
              scheduledTime: extra.appointmentTime,
              scheduledDate: extra.appointmentDate,
            );
          }
          return LiveAppointmentScreen(appointmentId: id);
        },
      ),
      GoRoute(
        path: '/r',
        builder: (_, state) => ResolveLinkScreen(
          token: state.uri.queryParameters['t'],
        ),
      ),
      GoRoute(
        path: '/view-hospital-details/:code',
        builder: (_, state) => HospitalDetailsScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/view-doctor-profile/:code',
        builder: (_, state) => DoctorProfileLoaderScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/view-doctor-details/:code',
        builder: (_, state) => DoctorBookingScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/view-diagnostic-center-detail/:code',
        builder: (_, state) => DiagnosticCenterScreen(
          code: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/view-dialysis-center-detail/:code',
        builder: (_, state) => DialysisCenterLoaderScreen(
          code: state.pathParameters['code']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
  return appRouter;
}

Future<String?> _authRedirect(BuildContext context, GoRouterState state) async {
  final path = state.uri.path;

  if (_isPublicRoute(path)) return null;

  // Prefer in-memory flag (set sync on login) so OTP → Home is not bounced.
  // Fall back to prefs for cold start / deep links before hydrate finishes.
  var isLoggedIn = TokenStorage.isLoggedIn;
  if (!isLoggedIn) {
    isLoggedIn = await TokenStorage.hasToken();
  }

  // Deep links: unchanged — save pending path and send to login if needed.
  if (DeepLinkService.isDeepLinkPath(path)) {
    if (isLoggedIn) return null;
    final fullPath = DeepLinkService.uriToLocation(state.uri);
    await DeepLinkService.savePendingPath(fullPath);
    return '/login';
  }

  // Protect home and other private destinations.
  if (!isLoggedIn) {
    return '/login';
  }

  return null;
}

bool _isPublicRoute(String path) {
  return path == '/splash' ||
      path == '/login' ||
      path == '/get-started' ||
      path == '/r';
}
