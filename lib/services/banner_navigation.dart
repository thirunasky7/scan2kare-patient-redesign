import 'package:url_launcher/url_launcher.dart';

import '../models/app_banner.dart';
import '../router/app_router.dart';
import 'deep_link_service.dart';

/// Opens banner targets in-app (hospital / diagnostic / dialysis) or externally.
class BannerNavigation {
  static Future<void> open(AppBanner banner) async {
    final target = banner.target;

    if (target != null) {
      if (target.isFacility) {
        final path = _facilityPath(target);
        if (path != null && DeepLinkService.isSupportedPath(path)) {
          appRouter.go(path.startsWith('/') ? path : '/$path');
          return;
        }
      }

      if (target.isExternal) {
        await _launchExternal(target.url ?? banner.linkUrl);
        return;
      }
    }

    final linkUrl = banner.linkUrl?.trim();
    if (linkUrl == null || linkUrl.isEmpty) return;

    final uri = Uri.tryParse(linkUrl);
    if (uri == null) return;

    final deepPath = DeepLinkService.extractPathFromUri(uri);
    if (deepPath != null && DeepLinkService.isSupportedPath(deepPath)) {
      DeepLinkService.handleUri(uri);
      return;
    }

    await _launchExternal(linkUrl);
  }

  static String? _facilityPath(AppBannerTarget target) {
    final path = target.path?.trim();
    if (path != null && path.isNotEmpty) {
      return path.startsWith('/') ? path : '/$path';
    }

    final code = target.code?.trim();
    if (code == null || code.isEmpty) return null;

    switch (target.type) {
      case 'hospital':
        return '/view-hospital-details/$code';
      case 'diagnostic':
        return '/view-diagnostic-center-detail/$code';
      case 'dialysis':
        return '/view-dialysis-center-detail/$code';
      default:
        return null;
    }
  }

  static Future<void> _launchExternal(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
