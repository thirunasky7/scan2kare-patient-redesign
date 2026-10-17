import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../pages/hospital_types_screen.dart';
import '../pages/health_hub_screen.dart';
import '../pages/scan_center_screen.dart';
import '../pages/home_care_screen.dart';
import '../pages/labs_listing_screen.dart';
import '../pages/second_opinion_landing.dart';
import '../pages/unblock_dna_type_screen.dart';
import '../pages/dialysis_centers_screen.dart';
import '../pages/care/care_folder_screen.dart';
import 'fast_network_image.dart';

class ServiceCardsWidget extends StatelessWidget {
  const ServiceCardsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final services = [
      _ServiceItem(
        title: "Doctor booking",
        icon:
            "https://scan2kare.com/public/app-images/services/book-doctor.png",
        color: const Color(0xFFFFEAEA),
        iconColor: Colors.red,
        id: 1,
      ),
      _ServiceItem(
        title: "Scan center booking",
        icon:
            "https://scan2kare.com/public/app-images/services/scan-center-booking.png",
        color: const Color(0xFFF2F8FF),
        iconColor: Colors.pink,
        id: 2,
      ),
      _ServiceItem(
        title: "Lab Booking",
        icon:
            "https://scan2kare.com/public/app-images/services/lab-booking.png",
        color: const Color(0xFFF4F6FF),
        iconColor: Colors.blue,
        id: 3,
      ),
      _ServiceItem(
        title: "Dialysis Booking",
        icon:
            "https://scan2kare.com/public/app-images/services/lab-booking.png",
        color: const Color(0xFFE7F6F1),
        iconColor: Colors.teal,
        id: 9,
      ),
      _ServiceItem(
        title: "Gynecology",
        icon: "${ApiConfig.host}/public/assets/homepage/genocology.png",
        color: const Color(0xFFFFEAEA),
        iconColor: Colors.pink,
        id: 10,
      ),
      _ServiceItem(
        title: "Telemedicine",
        icon: "${ApiConfig.host}/public/assets/homepage/telemedicine.png",
        color: const Color(0xFFEAF6FF),
        iconColor: Colors.blue,
        id: 11,
      ),
      _ServiceItem(
        title: "Radiology",
        icon: "${ApiConfig.host}/public/assets/homepage/radiology.png",
        color: const Color(0xFFF4F6FF),
        iconColor: Colors.indigo,
        id: 12,
      ),
      _ServiceItem(
        title: "Second opinion",
        icon:
            "https://scan2kare.com/public/app-images/services/second-opinion.png",
        color: const Color(0xFFF4F6FF),
        iconColor: Colors.blueGrey,
        id: 5,
      ),
      _ServiceItem(
        title: "Unlock Your DNA",
        icon: "https://scan2kare.com/public/app-images/services/geno-bytes.png",
        color: const Color(0xFFFFF8E1),
        iconColor: Colors.orange,
        id: 6,
      ),
      _ServiceItem(
        title: "Home Care",
        icon: "https://scan2kare.com/public/app-images/services/home-care.png",
        color: const Color(0xFFFFF1E0),
        iconColor: Colors.orange,
        id: 7,
      ),
      _ServiceItem(
        title: "Health Hub",
        icon: "https://scan2kare.com/public/app-images/services/health-hub.png",
        color: const Color(0xFFFFF8E1),
        iconColor: Colors.orange,
        id: 8,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final item = services[index];
        return _serviceCard(context, item);
      },
    );
  }

  Widget _serviceCard(BuildContext context, _ServiceItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _navigate(context, item.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Background Color
            // Container(
            //   decoration: BoxDecoration(
            //     color: item.color,
            //   ),
            // ),

            Positioned.fill(
              child: FastNetworkImage(
                url: item.icon,
                fit: BoxFit.cover,
                fallback: Container(color: item.color),
              ),
            ),

            // Bottom Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF014652),
                ),
                child: Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Manual navigation logic here
  void _navigate(BuildContext context, int id) {
    switch (id) {
      case 1:
        // Doctor Appointment
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HospitalTypesScreen(),
          ),
        );
        break;

      case 2:
        // Scan Appointment
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanCenterScreen(),
          ),
        );
        break;

      case 3:
        // Medical Online Booking
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LabCenterScreen(),
          ),
        );
        break;

      case 4:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => const PharmacyScreen(),
        //   ),
        // );
        break;
//HealthHubScreen
      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SecondOptionScreen(),
          ),
        );
        break;
      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const UnlockDnaScreen(),
          ),
        );
        break;

      case 7:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeCareScreen(),
          ),
        );
        break;

      case 8:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HealthHubScreen(),
          ),
        );
        break;

      case 9:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DialysisCentersScreen(),
          ),
        );
        break;

      case 10:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CareFolderScreen(
              slug: 'gynec',
              title: 'Gynecology',
            ),
          ),
        );
        break;

      case 11:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CareFolderScreen(
              slug: 'telemedicine',
              title: 'Telemedicine',
            ),
          ),
        );
        break;

      case 12:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CareFolderScreen(
              slug: 'radiology',
              title: 'Radiology',
            ),
          ),
        );
        break;
    }
  }
}

class _ServiceItem {
  final String title;
  final String icon;
  final Color color;
  final Color iconColor;
  final int id;

  _ServiceItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.id,
  });
}
