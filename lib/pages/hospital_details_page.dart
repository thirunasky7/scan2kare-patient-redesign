import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';

class HospitalDetailsPage extends StatelessWidget {
  final String hospitalId;
  final Map<String, dynamic> hospitalData;

  const HospitalDetailsPage({
    super.key,
    required this.hospitalId,
    required this.hospitalData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(hospitalData['name'] ?? 'Hospital Details'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (int.tryParse(hospitalId) != null)
            FavoriteButton(
              type: FavoritesService.hospital,
              id: int.parse(hospitalId),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              snapshot: {
                'id': int.parse(hospitalId),
                'name': hospitalData['name'] ?? '',
                'image': hospitalData['image'] ??
                    hospitalData['hospital_image'] ??
                    '',
                'address': hospitalData['address'] ?? '',
                'hospital_type': hospitalData['hospital_type'] ??
                    hospitalData['type'] ??
                    '',
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospitalData['name'] ?? 'Hospital Name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(hospitalData['phone'] ?? 'Phone not available'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(hospitalData['address'] ??
                              'Address not available'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Available Doctors',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (hospitalData['doctors'] != null)
              ...List.generate(
                (hospitalData['doctors'] as List).length,
                (index) {
                  final doctor = hospitalData['doctors'][index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF243C90),
                        child: Text(
                          doctor['name'][0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(doctor['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              doctor['specialty'] ?? 'Specialty not specified'),
                          if (doctor['location'] != null)
                            Text('Location: ${doctor['location']}'),
                          if (doctor['language'] != null)
                            Text('Language: ${doctor['language']}'),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Booking with ${doctor['name']}'),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF243C90),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                  );
                },
              )
            else
              const Text('No doctors available'),
          ],
        ),
      ),
    );
  }
}
