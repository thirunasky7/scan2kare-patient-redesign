import 'package:flutter/material.dart';
import '../pages/second_opinion_page.dart';

class ConnectBanner extends StatelessWidget {
  final String image1;
  final String image2;
  final double height;
  final double borderRadius;
  final double spacing;

  const ConnectBanner({
    super.key,
    required this.image1,
    required this.image2,
    this.height = 120,
    this.borderRadius = 12,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// Image 1
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecondOpinionPage(),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.asset(
                image1,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        SizedBox(width: spacing),

        /// Image 2
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecondOpinionPage(),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.asset(
                image2,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
