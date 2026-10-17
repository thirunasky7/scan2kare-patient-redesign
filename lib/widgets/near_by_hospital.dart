import 'package:flutter/material.dart';

class NearByCentersExactMatch extends StatefulWidget {
  const NearByCentersExactMatch({super.key});

  @override
  State<NearByCentersExactMatch> createState() =>
      _NearByCentersExactMatchState();
}

class _NearByCentersExactMatchState extends State<NearByCentersExactMatch> {
  int selectedTab = 1;

  final tabs = ['All', 'Hospitals', 'Clinics', 'Diagnostic'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// HEADER
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Near by Centers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'View all',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        /// TABS (SMALL PILLS)
        SizedBox(
          height: 32,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final isSelected = selectedTab == index;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xffa9c8f8)
                      : const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isSelected ? const Color(0xff044b86) : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        /// CARD
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFFFE2BF),
            ),
            child: Row(
              children: [
                /// LEFT IMAGE
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: Image.asset(
                    'assets/near_by_hospital.png',
                    width: 135,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                /// RIGHT CONTENT
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_hospital, size: 16),
                          SizedBox(height: 6),
                          Text(
                            'Connect with the\nhospitals nearby\nyou',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        /// HOSPITAL NAME (OUTSIDE CARD)
        const Padding(
          padding: EdgeInsets.only(left: 18, top: 18),
          child: Text(
            'Apollo Hospital',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xff05508e),
            ),
          ),
        ),
      ],
    );
  }
}
