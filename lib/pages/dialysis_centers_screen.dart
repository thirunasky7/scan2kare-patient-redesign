import 'package:flutter/material.dart';

import '../models/dialysis_models.dart';
import '../services/auth_service.dart';
import '../services/dialysis_api_service.dart';
import '../utils/api_error.dart';
import '../widgets/fast_network_image.dart';
import 'dialysis_center_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DialysisCentersScreen extends StatefulWidget {
  const DialysisCentersScreen({super.key});

  @override
  State<DialysisCentersScreen> createState() => _DialysisCentersScreenState();
}

class _DialysisCentersScreenState extends State<DialysisCentersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DialysisCenterItem> _centers = [];
  List<DialysisCenterItem> _filtered = [];
  bool _loading = true;
  String? _error;
  String _userName = 'Guest';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await AuthService.getUserProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', data['name'] ?? 'Guest');
      if (!mounted) return;
      setState(() => _userName = data['name'] ?? 'Guest');
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _userName = prefs.getString('user_name') ?? 'Guest');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await DialysisApiService.getCenters();
      final list = raw
          .map((e) =>
              DialysisCenterItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      list.sort((a, b) => a.centerName.toLowerCase().compareTo(b.centerName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _centers = list;
        _filtered = list;
        _loading = false;
      });
      _filter(_searchController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyException(
          e,
          fallback: 'Could not load dialysis centres. Please try again.',
        );
      });
    }
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _centers;
      } else {
        _filtered = _centers.where((c) {
          return c.centerName.toLowerCase().contains(query) ||
              (c.city ?? '').toLowerCase().contains(query) ||
              (c.address ?? '').toLowerCase().contains(query) ||
              (c.state ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8F4F3),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildBannerCard(),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: const BackButton(color: Colors.black),
      title: Column(
        children: [
          const Text(
            'Dialysis Centres',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _userName,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: _filter,
      decoration: InputDecoration(
        hintText: 'Search by dialysis centre name / city',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _filter('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFE7F6F1),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Book dialysis slots at trusted centres near you',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              'https://images.unsplash.com/photo-1579684385127-1ef15d508118',
              width: 140,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140,
                height: 120,
                color: const Color(0xFF2B6F71).withValues(alpha: 0.15),
                child: const Icon(Icons.water_drop, color: Color(0xFF2B6F71), size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B6F71),
                  foregroundColor: Colors.white,
                ),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No dialysis centres found'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _centerCard(_filtered[i]),
      ),
    );
  }

  Widget _centerCard(DialysisCenterItem c) {
    final imageUrl = c.profileImage ?? '';
    final address = (c.address != null && c.address!.isNotEmpty)
        ? c.address!
        : c.locationLine;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DialysisCenterDetailScreen(centerId: c.id),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: imageUrl.isNotEmpty
                  ? FastNetworkImage(
                      url: imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      fallback: _imageFallback(),
                    )
                  : _imageFallback(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.centerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (c.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F6F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2B6F71),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.isNotEmpty ? address : 'Address not available',
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Color(0xFF2B6F71)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.locationLine.isNotEmpty
                              ? c.locationLine
                              : (c.city ?? '—'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.water_drop, size: 16, color: Color(0xFF2B6F71)),
                      const SizedBox(width: 4),
                      const Text('Dialysis'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_hospital, size: 40, color: Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(
            'Image\nunavailable',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
