import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cached network image with a short fade and small decode size so folder
/// tiles and homepage cards appear quickly.
class FastNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget? fallback;
  final double? width;
  final double? height;
  final int memCacheWidth;

  const FastNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.width,
    this.height,
    this.memCacheWidth = 600,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return fallback ?? const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 80),
      fadeOutDuration: Duration.zero,
      imageBuilder: (context, imageProvider) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: fit),
        ),
      ),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: const Color(0xFFE7F6F1),
      ),
      errorWidget: (_, __, ___) =>
          fallback ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFFE7F6F1),
          ),
    );
  }
}
