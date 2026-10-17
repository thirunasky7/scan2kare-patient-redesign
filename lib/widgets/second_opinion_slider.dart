import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class SecondOpinionSlider extends StatefulWidget {
  const SecondOpinionSlider({super.key});

  @override
  State<SecondOpinionSlider> createState() => _SecondOpinionSliderState();
}

class _SecondOpinionSliderState extends State<SecondOpinionSlider> {
  int _currentIndex = 0;

  final List<String> banners = [
    'assets/icon/second-opinion.png',
    'assets/icon/second-1.png',
    'assets/icon/second-2.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🔹 Slider
        CarouselSlider(
          items: banners.map((image) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 80,
            autoPlay: false,
            viewportFraction: 0.8,
            enlargeCenterPage: false,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),

        const SizedBox(height: 2),
      ],
    );
  }
}
