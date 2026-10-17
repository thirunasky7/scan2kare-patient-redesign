import 'package:flutter/material.dart';

class PanelCard extends StatelessWidget {
  final String title;
  final String image;
  final String description;

  const PanelCard({
    super.key,
    required this.title,
    required this.image,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      // decoration: BoxDecoration(
      //   color: Colors.white,
      //   borderRadius: BorderRadius.circular(16),
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(0.05),
      //       blurRadius: 6,
      //       offset: Offset(0, 3),
      //     )
      //   ],
      // ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 👤 Circle Image
          CircleAvatar(
            radius: 35,
            backgroundImage: NetworkImage(image),
          ),

          const SizedBox(height: 10),

          // 🏷 Title
          Text(
            title,
            //textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2B3A67),
            ),
          ),

          const SizedBox(height: 8),

          // 📄 Description
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
