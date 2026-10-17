import 'package:flutter/material.dart';
import '../widgets/hospital_type_card.dart';
import '../services/hospital_service.dart';
import '../models/hospital_type.dart';

class HospitalTypesScreen extends StatefulWidget {
  const HospitalTypesScreen({super.key});

  @override
  _HospitalTypesScreenState createState() => _HospitalTypesScreenState();
}

class _HospitalTypesScreenState extends State<HospitalTypesScreen> {
  final HospitalService _apiService = HospitalService();
  late Future<List<HospitalType>> _hospitalTypesFuture;

  @override
  void initState() {
    super.initState();
    _hospitalTypesFuture = HospitalService.fetchHospitalTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Hospital Types'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder<List<HospitalType>>(
                future: _hospitalTypesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _hospitalTypesFuture =
                                    HospitalService.fetchHospitalTypes();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasData) {
                    return _buildHospitalGrid(snapshot.data!);
                  } else {
                    return const Center(
                      child: Text('No data available'),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalGrid(List<HospitalType> hospitalTypes) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: hospitalTypes.length,
        itemBuilder: (context, index) {
          return HospitalTypeCard(
            hospitalType: hospitalTypes[index],
          );
        },
      ),
    );
  }
}
