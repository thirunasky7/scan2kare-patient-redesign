import 'dart:math';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class SpotlightSlider extends StatefulWidget {
  const SpotlightSlider({super.key});

  @override
  State<SpotlightSlider> createState() => _SpotlightSliderState();
}

class _SpotlightSliderState extends State<SpotlightSlider> {
  int _currentIndex = 0;

  final List<Map<String, String>> banners = [
    {
      "image": "assets/healthcare.png",
      "title": "SPOTLIGHT",
      "subtitle": "Revolutionary Healthcare Solutions",
      "offer": "15%\nOFF",
    },
    {
      "image": "assets/healthcare.png",
      "title": "SPOTLIGHT",
      "subtitle": "Advanced Medical Care",
      "offer": "20%\nOFF",
    },
    {
      "image": "assets/healthcare.png",
      "title": "SPOTLIGHT",
      "subtitle": "Wellness & Prevention",
      "offer": "25%\nOFF",
    },
    {
      "image": "assets/healthcare.png",
      "title": "SPOTLIGHT",
      "subtitle": "Telemedicine Services",
      "offer": "30%\nOFF",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselSlider(
          items: banners.map((banner) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section - Fixed
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              // Background color as fallback
                              Container(
                                color: Colors.blue[50],
                              ),
                              // Local image - covers entire area
                              Image.asset(
                                banner["image"]!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              // Overlay content on top of image
                              Container(
                                height: 140,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                // child: Center(
                                //   child: Column(
                                //     mainAxisAlignment: MainAxisAlignment.center,
                                //     children: [
                                //       Text(
                                //         banner["subtitle"]!,
                                //         textAlign: TextAlign.start,
                                //         style: const TextStyle(
                                //           color: Colors.white,
                                //           fontSize: 14,
                                //           fontWeight: FontWeight.w500,
                                //           shadows: [
                                //             Shadow(
                                //               blurRadius: 2,
                                //               color: Colors.black,
                                //             ),
                                //           ],
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Text + Offer Section (unchanged)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    banner["title"]!,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    banner["subtitle"]!,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Burst Badge
                            const SizedBox(width: 8),
                            OfferBurstBadge(text: banner["offer"]!),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
          options: CarouselOptions(
            height: 240,
            autoPlay: false,
            // autoPlayInterval: const Duration(seconds: 5),
            // autoPlayAnimationDuration: const Duration(milliseconds: 900),
            // autoPlayCurve: Curves.fastOutSlowIn,
            viewportFraction: 0.9,
            enlargeCenterPage: true,
            enlargeFactor: 0.2,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
      ],
    );
  }
}

class OfferBurstBadge extends StatelessWidget {
  final String text;

  const OfferBurstBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Burst Background
          CustomPaint(
            size: const Size(70, 70),
            painter: _BurstPainter(),
          ),

          // Text
          Positioned.fill(
            child: Center(
              child: Transform.rotate(
                angle: -0.2,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.7;
    const numberOfPoints = 10;

    // Create gradient for burst effect
    const gradient = RadialGradient(
      colors: [
        Color(0xFFD32F2F),
        Color(0xFFB71C1C),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: outerRadius),
      )
      ..style = PaintingStyle.fill;

    final path = Path();

    for (int i = 0; i <= numberOfPoints * 2; i++) {
      double radius = i.isEven ? outerRadius : innerRadius;
      double angle = (2 * pi * i) / (numberOfPoints * 2);

      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    // Add subtle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
