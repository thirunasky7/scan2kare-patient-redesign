import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/app_banner.dart';
import '../services/banner_navigation.dart';
import '../services/banner_service.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  List<AppBanner> _banners = [];
  bool _loading = true;

  static const List<String> _fallbackAssets = [
    'assets/home-banner1.jpeg',
    'assets/home-banner2.jpeg',
    'assets/home-banner3.jpeg',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await BannerService.fetchBanners(BannerService.home);
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
        height: 200,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      banner.image,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _fallbackAssets[index],
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 200,
            autoPlay: count > 1,
            viewportFraction: 0.8,
            enlargeCenterPage: false,
            autoPlayInterval: const Duration(seconds: 3),
          ),
        ),
      ],
    );
  }
}
