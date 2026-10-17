import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class PapularHospitalSlider extends StatefulWidget {
  const PapularHospitalSlider({super.key});

  @override
  State<PapularHospitalSlider> createState() => _PapularHospitalSliderState();
}

class _PapularHospitalSliderState extends State<PapularHospitalSlider> {
  int _currentIndex = 0;

  final List<String> banners = [
    'assets/healcare.png',
    'assets/healcare.png',
    'assets/healcare.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          items: banners.map((image) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 100,
            autoPlay: true,
            viewportFraction: 0.95,
            //enlargeCenterPage: true,
            autoPlayInterval: const Duration(seconds: 3),
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
