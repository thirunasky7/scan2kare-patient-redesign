import 'package:flutter/material.dart';
import 'scan_booking_screen.dart';
import '../services/scan_api_service.dart';
import '../models/scan_type_model.dart';

class ScanTypesScreen extends StatefulWidget {
  final int centerId;
  final int categoryId;
  final String categoryName;
  final String centerName;
  final String centerAddress;

  /// Scans already returned with the category card, shown while the list refreshes.
  final List<ScanType> initialScanTypes;

  const ScanTypesScreen({
    super.key,
    required this.centerId,
    required this.categoryId,
    required this.categoryName,
    required this.centerName,
    required this.centerAddress,
    this.initialScanTypes = const [],
  });

  @override
  State<ScanTypesScreen> createState() => _ScanTypesScreenState();
}

class _ScanTypesScreenState extends State<ScanTypesScreen> {
  List<ScanType> scanTypes = []; // Main data source
  bool loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialScanTypes.isNotEmpty) {
      scanTypes = List.of(widget.initialScanTypes);
      loading = false;
    }
    loadScanTypes();
  }

  Future<void> loadScanTypes() async {
    if (scanTypes.isEmpty && !loading) {
      setState(() => loading = true);
    }

    try {
      final response = await ScanApiService.getScanTypes(
        categoryId: widget.categoryId,
        centerId: widget.centerId,
      );
      final fetched = response
          .whereType<Map>()
          .map((e) => ScanType.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        // An empty refresh must not hide scans the category card already counted.
        if (fetched.isNotEmpty || scanTypes.isEmpty) {
          scanTypes = fetched;
        }
        loading = false;
      });
    } catch (e) {
      debugPrint('loadScanTypes failed: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B6F71),
        title: Text(widget.categoryName, style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildCenterHeader(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : scanTypes.isEmpty // Use scanTypes directly
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "No Scans Available",
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: loadScanTypes,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: scanTypes.length, // Use scanTypes
                        itemBuilder: (context, index) {
                          return _scanCard(
                            context,
                            scanTypes[index], // Use scanTypes
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.teal.shade100,
            child: const Icon(
              Icons.local_hospital,
              color: Color(0xFF2B6F71),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.centerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.centerAddress,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCard(BuildContext context, ScanType scan) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scan.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              scan.description,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 15),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B6F71),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScanBookingScreen(
                        centerId: widget.centerId,
                        centerName: widget.centerName,
                        centerAddress: widget.centerAddress,
                        scanTypeId: scan.id,
                        scanName: scan.name,
                        scanDescription: scan.description,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Book Now",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
