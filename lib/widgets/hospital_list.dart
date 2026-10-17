import 'package:flutter/material.dart';
import '../services/hospital_service.dart';
import '../models/hospitals.dart';
import '../widgets/hospital_card.dart';

class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  String selectedFilter = "All";

  List<HospitalItem> hospitals = [];
  List<HospitalItem> filteredHospitals = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHospitalsFromApi();
  }

  Future<void> fetchHospitalsFromApi() async {
    try {
      final data = await HospitalService.fetchHospitals();

      setState(() {
        hospitals = data;
        filteredHospitals = data; // default All
        isLoading = false;
      });
    } catch (e) {
      // debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void filterHospitals(String type) {
    setState(() {
      selectedFilter = type;

      if (type == "All") {
        filteredHospitals = hospitals;
      } else {
        filteredHospitals = hospitals
            .where((h) => h.type.toLowerCase() == type.toLowerCase())
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hospitals")),
      body: Column(
        children: [
          /// 🔹 FILTER BUTTONS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                filterButton("All"),
                filterButton("Hospital"),
                filterButton("Clinic"),
                filterButton("Diagnostics"),
              ],
            ),
          ),

          /// 🔹 HOSPITAL LIST (Nearby Centers removed)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredHospitals.isEmpty
                    ? const Center(child: Text("No hospitals found"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredHospitals.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemBuilder: (context, index) {
                          final hospital = filteredHospitals[index];

                          return HospitalCard(
                            hospital: hospital,
                            onTap: () {
                              print("Clicked: ${hospital.name}");
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget filterButton(String text) {
    bool isSelected = selectedFilter == text;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () => filterHospitals(text),
      child: Text(text),
    );
  }
}
