import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/care_folder_service.dart';
import '../../widgets/care_folder_tile.dart';
import '../../widgets/fast_network_image.dart';
import '../hospital_types_screen.dart';
import 'care_scan_upload_screen.dart';

class CareSubfolderScreen extends StatelessWidget {
  final CareChild child;

  const CareSubfolderScreen({super.key, required this.child});

  static const Color _brand = Color(0xFF2B6F71);

  Future<void> _openUrl(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link is available for this item yet.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  void _openItem(BuildContext context, CareFolderItem item) {
    if (item.href != null && item.href!.isNotEmpty) {
      _openUrl(context, item.href);
      return;
    }
    if (item.url != null && item.url!.isNotEmpty) {
      _openUrl(context, item.url);
      return;
    }
    if (item.hospitalSearch != null && item.hospitalSearch!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HospitalTypesScreen()),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No link is available for this item yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showPartnerTiles = child.scanFolders.isEmpty;
    final tiles = <Widget>[
      ...child.scanFolders.map(
        (scan) => CareFolderTile(
          title: scan.title,
          imageUrl: scan.icon,
          fallbackIcon: Icons.image_search,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CareScanUploadScreen(
                  folderSlug: child.folderSlug,
                  subfolderSlug: child.slug,
                  scan: scan,
                ),
              ),
            );
          },
        ),
      ),
      if (showPartnerTiles)
        ...child.items.map(
          (item) => CareFolderTile(
            title: item.name,
            imageUrl: item.icon ?? child.icon,
            fallbackIcon: Icons.local_hospital,
            onTap: () => _openItem(context, item),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(child.title),
        actions: [
          if (child.url != null && child.url!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openUrl(context, child.url),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (child.sliders.isNotEmpty)
            SizedBox(
              height: 160,
              child: PageView(
                children: child.sliders
                    .map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FastNetworkImage(
                            url: url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 160,
                            memCacheWidth: 900,
                            fallback: Container(
                              color: const Color(0xFFE7F6F1),
                              child: const Icon(Icons.image, color: _brand),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (child.sliders.isNotEmpty) const SizedBox(height: 16),
          if (child.description.isNotEmpty || child.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                child.content.isNotEmpty ? child.content : child.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800, height: 1.45),
              ),
            ),
          if (tiles.isNotEmpty)
            CareFolderTileGrid(tiles: tiles)
          else
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: const Column(
                children: [
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B324E),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Partners for this option will appear here soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
