import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/deep_link_service.dart';

/// Resolves /r?t=token via GET /api/resolve-link then routes by type/code.
class ResolveLinkScreen extends StatefulWidget {
  final String? token;

  const ResolveLinkScreen({super.key, this.token});

  @override
  State<ResolveLinkScreen> createState() => _ResolveLinkScreenState();
}

class _ResolveLinkScreenState extends State<ResolveLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Future<void> _resolve() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      if (mounted) context.go('/home');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.resolveLink}?t=${Uri.encodeComponent(token)}'),
        headers: const {'Accept': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        context.go('/home');
        return;
      }

      final body = jsonDecode(response.body);
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'])
          : body is Map
              ? Map<String, dynamic>.from(body)
              : null;

      if (data == null) {
        context.go('/home');
        return;
      }

      final deeplink = data['deeplink'] is Map
          ? Map<String, dynamic>.from(data['deeplink'])
          : data;

      final requiresAuth = deeplink['requires_auth'] == true;
      final targetPath = DeepLinkService.deeplinkToPath(deeplink);

      if (targetPath == null) {
        context.go('/home');
        return;
      }

      if (requiresAuth && !await DeepLinkService.hasAuthToken()) {
        await DeepLinkService.savePendingPath(targetPath);
        if (mounted) context.go('/login');
        return;
      }

      if (mounted) context.go(targetPath);
    } catch (_) {
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
