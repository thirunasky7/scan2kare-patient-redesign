import 'package:flutter/material.dart';

import 'fast_network_image.dart';

/// Image + title tile matching homepage folders and website care pages.
class CareFolderTile extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final IconData fallbackIcon;

  const CareFolderTile({
    super.key,
    required this.title,
    this.imageUrl,
    this.onTap,
    this.fallbackIcon = Icons.folder_open,
  });

  static const Color _bar = Color(0xFF014652);
  static const Color _brand = Color(0xFF2B6F71);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned.fill(child: _image()),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                color: _bar,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    return FastNetworkImage(
      url: imageUrl ?? '',
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 500,
      fallback: _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE7F6F1),
      child: Icon(fallbackIcon, color: _brand, size: 42),
    );
  }
}

class CareFolderTileGrid extends StatelessWidget {
  final List<Widget> tiles;

  const CareFolderTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: tiles,
    );
  }
}
