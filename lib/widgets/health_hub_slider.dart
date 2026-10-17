import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/app_banner.dart';
import '../services/banner_navigation.dart';
import '../services/banner_service.dart';

class HealthhubSlider extends StatefulWidget {
  const HealthhubSlider({super.key});

  @override
  State<HealthhubSlider> createState() => _HealthhubSliderState();
}

class _HealthhubSliderState extends State<HealthhubSlider> {
  List<AppBanner> _banners = [];
  bool _loading = true;

  static const List<String> _fallbackAssets = [
    'assets/icon/health-hub1.png',
    'assets/icon/health-hub2.png',
    'assets/icon/health-hub3.png',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await BannerService.fetchBanners(BannerService.healthHub);
      if (!mounted) return;
      setState(() {
        _banners = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banners = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final useNetwork = _banners.isNotEmpty;
    final count = useNetwork ? _banners.length : _fallbackAssets.length;

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: count,
          itemBuilder: (context, index, realIndex) {
            if (useNetwork) {
              final banner = _banners[index];
              return GestureDetector(
                onTap: () => BannerNavigation.open(banner),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: Image.network(
                      banner.image,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  _fallbackAssets[index],
                  fit: BoxFit.fill,
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 80,
            autoPlay: false,
            viewportFraction: 0.8,
            enlargeCenterPage: false,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
