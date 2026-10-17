import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/care_folder_service.dart';
import '../../widgets/care_folder_tile.dart';
import 'care_subfolder_screen.dart';

class CareFolderScreen extends StatefulWidget {
  final String slug;
  final String? title;

  const CareFolderScreen({super.key, required this.slug, this.title});

  @override
  State<CareFolderScreen> createState() => _CareFolderScreenState();
}

class _CareFolderScreenState extends State<CareFolderScreen> {
  static const Color _brand = Color(0xFF2B6F71);
  CareFolder? _folder;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final folder = await CareFolderService.getFolder(widget.slug);
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _loading = false;
    });
    if (!mounted) return;
    for (final child in folder.children) {
      final url = child.icon;
      if (url != null && url.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _folder?.title ?? widget.title ?? 'Care';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if ((_folder?.description ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _folder!.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if ((_folder?.children ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('No options in this folder yet.')),
                    )
                  else
                    CareFolderTileGrid(
                      tiles: (_folder?.children ?? [])
                          .map(
                            (child) => CareFolderTile(
                              title: child.title,
                              imageUrl: child.icon,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CareSubfolderScreen(child: child),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }
}
