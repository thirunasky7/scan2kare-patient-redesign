import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';

/// Saved doctors and hospitals, separate from the Recent Hospital tab.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  static const Color _brand = Color(0xFF2B6F71);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F8),
        appBar: AppBar(
          title: const Text('Favourites'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            labelColor: _brand,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _brand,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Doctors'),
              Tab(text: 'Hospitals'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavoritesTab(type: FavoritesService.doctor),
            _FavoritesTab(type: FavoritesService.hospital),
          ],
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab({required this.type});

  final String type;

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _future;

  bool get _isDoctor => widget.type == FavoritesService.doctor;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = FavoritesService.fetchFavorites(type: widget.type);
  }

  Future<void> _refresh() async {
    final future = FavoritesService.fetchFavorites(type: widget.type);
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: FavoritesScreen._brand,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: FavoritesScreen._brand),
            );
          }

          if (snapshot.hasError) {
            return _message(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load favourites',
              subtitle: 'Pull down to try again.',
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _message(
              icon: Icons.favorite_border,
              title: _isDoctor
                  ? 'No saved doctors yet'
                  : 'No saved hospitals yet',
              subtitle: 'Tap the heart on any '
                  '${_isDoctor ? 'doctor' : 'hospital'} to save it here.',
            );
          }

          return ValueListenableBuilder<Set<int>>(
            valueListenable: FavoritesService.notifierFor(widget.type),
            builder: (context, ids, _) {
              final visible =
                  items.where((e) => ids.contains(e['id'] as int)).toList();

              if (visible.isEmpty) {
                return _message(
                  icon: Icons.favorite_border,
                  title: 'No favourites left',
                  subtitle: 'Pull down to refresh.',
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _card(context, visible[i]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> item) {
    final id = item['id'] as int;
    final name = (item['name'] as String?)?.trim();
    final image = item['image'] as String?;

    final subtitle = _isDoctor
        ? (item['hospital_name'] as String?) ?? ''
        : (item['address'] as String?) ?? '';
    final tag = _isDoctor
        ? (item['qualification'] as String?) ?? ''
        : (item['hospital_type'] as String?) ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(context, id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: image == null || image.isEmpty
                      ? _imageFallback()
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.isNotEmpty == true ? name! : 'Unnamed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tag.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: FavoritesScreen._brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              FavoriteButton(
                type: widget.type,
                id: id,
                snapshot: item,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        color: const Color(0xFFE8EFEF),
        child: Icon(
          _isDoctor ? Icons.person : Icons.local_hospital,
          color: FavoritesScreen._brand,
        ),
      );

  void _openDetail(BuildContext context, int id) {
    context.push(
      _isDoctor ? '/view-doctor-profile/$id' : '/view-hospital-details/$id',
    );
  }
}
