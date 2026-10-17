import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'router/app_router.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_service.dart';
import 'services/install_referrer_service.dart';
import 'utils/token_storage.dart';
import 'utils/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App is portrait by default; video fullscreen temporarily unlocks landscape.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  await TokenStorage.hydrate();
  await LocalStorage.hydrateDisplayName();
  if (TokenStorage.isLoggedIn) {
    unawaited(FavoritesService.seed());
  }
  runApp(const Scan2KareApp());
}

class Scan2KareApp extends StatefulWidget {
  const Scan2KareApp({super.key});

  @override
  State<Scan2KareApp> createState() => _Scan2KareAppState();
}

class _Scan2KareAppState extends State<Scan2KareApp> {
  late final AppLinks _appLinks = AppLinks();
  late final GoRouter _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleIncomingLink(initial);
      } else {
        await _checkInstallReferrer();
      }
    } catch (_) {}

    _appLinks.uriLinkStream.listen(_handleIncomingLink);
  }

  Future<void> _checkInstallReferrer() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('install_referrer_processed') ?? false) return;
    await prefs.setBool('install_referrer_processed', true);

    final referrer = await InstallReferrerService.getInstallReferrer();
    if (referrer == null || referrer.isEmpty) return;

    final path = DeepLinkService.pathFromInstallReferrer(referrer);
    if (path == null || !DeepLinkService.isSupportedPath(path)) return;

    await DeepLinkService.savePendingPath(path);
    _router.go(path);
  }

  void _handleIncomingLink(Uri uri) {
    DeepLinkService.handleUri(uri);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Scan2Kare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      routerConfig: _router,
    );
  }
}

/// Called from SplashScreen after animation to decide post-splash navigation.
Future<void> navigateFromSplash(BuildContext context) async {
  if (!context.mounted) return;

  final pending = await DeepLinkService.getPendingPath();
  final token = await TokenStorage.getToken();
  final prefs = await SharedPreferences.getInstance();
  final isFirstTime = prefs.getBool('is_first_time') ?? true;

  if (!context.mounted) return;

  if (pending != null) {
    if (token != null && token.isNotEmpty) {
      context.go(pending.startsWith('/') ? pending : '/$pending');
    } else {
      context.go('/login');
    }
    return;
  }

  if (isFirstTime) {
    await prefs.setBool('is_first_time', false);
    if (!context.mounted) return;
    context.go('/get-started');
    return;
  }

  if (token != null && token.isNotEmpty) {
    context.go('/home');
  } else {
    context.go('/login');
  }
}
