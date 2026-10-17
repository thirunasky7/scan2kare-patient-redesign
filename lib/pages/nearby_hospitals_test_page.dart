import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NearbyHospitalsTestPage extends StatefulWidget {
  const NearbyHospitalsTestPage({super.key});

  @override
  State<NearbyHospitalsTestPage> createState() =>
      _NearbyHospitalsTestPageState();
}

class _NearbyHospitalsTestPageState extends State<NearbyHospitalsTestPage> {
  bool isLoading = false;
  String statusText = "Press button to search hospitals";
  List<Map<String, dynamic>> hospitals = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Hospitals Test"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : findHospitals,
              child: const Text("Find Nearby Hospitals"),
            ),
            const SizedBox(height: 10),
            Text(statusText),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hospitals.isEmpty
                      ? const Center(child: Text("No hospitals found"))
                      : ListView.builder(
                          itemCount: hospitals.length,
                          itemBuilder: (context, index) {
                            final h = hospitals[index];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.local_hospital),
                                title: Text(h["name"]),
                                subtitle:
                                    Text("Lat: ${h["lat"]}, Lng: ${h["lng"]}"),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // MAIN FUNCTION
  Future<void> findHospitals() async {
    setState(() {
      isLoading = true;
      statusText = "Getting your location...";
      hospitals.clear();
    });

    try {
      Position position = await _getUserLocation();

      setState(() {
        statusText = "Searching hospitals...";
      });

      List<Map<String, dynamic>> result =
          await _fetchNearbyHospitals(position.latitude, position.longitude);

      setState(() {
        hospitals = result;
        statusText = "Found ${hospitals.length} hospitals";
      });
    } catch (e) {
      setState(() {
        statusText = "Error: $e";
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  // GET USER LOCATION
  Future<Position> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location service disabled");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied");
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // FETCH HOSPITALS WITH AUTO RADIUS INCREASE
  Future<List<Map<String, dynamic>>> _fetchNearbyHospitals(
      double lat, double lng) async {
    int radius = 10000; // 10 km
    int maxRadius = 50000; // 50 km
    List<Map<String, dynamic>> foundHospitals = [];

    while (foundHospitals.isEmpty && radius <= maxRadius) {
      final query = """
[out:json];
(
  node["amenity"="hospital"](around:$radius,$lat,$lng);
  way["amenity"="hospital"](around:$radius,$lat,$lng);
  relation["amenity"="hospital"](around:$radius,$lat,$lng);
);
out center;
""";

      final url = Uri.parse("https://overpass-api.de/api/interpreter");

      final response = await http.post(url, body: {"data": query});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data["elements"] != null && data["elements"].isNotEmpty) {
          foundHospitals = List<Map<String, dynamic>>.from(data["elements"]);
          // print("Found in ${radius / 1000} km");
          break;
        } else {
          // print("No hospitals in ${radius / 1000} km");
        }
      } else {
        throw Exception("Overpass API error");
      }

      radius += 10000;

      // Avoid rate limit
      await Future.delayed(const Duration(seconds: 1));
    }

    return foundHospitals.map((h) {
      return {
        "name": h["tags"]?["name"] ?? "Unnamed Hospital",
        "lat": h["lat"] ?? h["center"]["lat"],
        "lng": h["lon"] ?? h["center"]["lon"],
      };
    }).toList();
  }
}
