import 'package:flutter/material.dart';
import 'scan_types_screen.dart';
import '../services/scan_api_service.dart';
import '../models/scan_category_model.dart';
import '../utils/deeplink_nav.dart';

class ScanCategoriesScreen extends StatefulWidget {
  final int centerId;
  final String centerName;
  final String centerAddress;
  final bool fromDeepLink;

  const ScanCategoriesScreen({
    super.key,
    required this.centerId,
    required this.centerName,
    required this.centerAddress,
    this.fromDeepLink = false,
  });

  @override
  State<ScanCategoriesScreen> createState() => _ScanCategoriesScreenState();
}

class _ScanCategoriesScreenState extends State<ScanCategoriesScreen> {
  List<ScanCategory> categories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final response = await ScanApiService.getCategories(widget.centerId);

      setState(() {
        categories = response.map((e) => ScanCategory.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.fromDeepLink,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.fromDeepLink) {
          handleDetailBack(context, fromDeepLink: true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Scan Categories",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2B6F71),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => handleDetailBack(
              context,
              fromDeepLink: widget.fromDeepLink,
            ),
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCenterHeader(),
                  const SizedBox(height: 8),
                  Expanded(child: _buildGrid(context)),
                ],
              ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildCenterHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: Color(0xFF2B6F71)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.centerName, // Fixed: added widget.
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.centerAddress, // Fixed: added widget.
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================= GRID =================

  Widget _buildGrid(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories available'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.80,
        ),
        itemBuilder: (context, index) {
          final item = categories[index];
          return _categoryCard(context, item);
        },
      ),
    );
  }

  // ================= CARD =================

  Widget _categoryCard(BuildContext context, ScanCategory item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanTypesScreen(
              centerId: widget.centerId,
              categoryId: item.id,
              categoryName: item.title,
              centerName: widget.centerName,
              centerAddress: widget.centerAddress,
              initialScanTypes: item.scanTypes,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade100,
                ),
                child: const Icon(Icons.calendar_month,
                    color: Colors.blue, size: 28),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Total ${item.totalTests} Checkup",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
