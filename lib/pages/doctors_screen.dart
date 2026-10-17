import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../models/doctor_api_response.dart';
import '../services/hospital_service.dart';
import '../services/favorites_service.dart';
import '../utils/deeplink_nav.dart';
import '../widgets/favorite_button.dart';
import 'doctor_profile_screen.dart';

class DoctorListScreen extends StatefulWidget {
  final String hospitalName;
  final String hospitalAddress;
  final int hospitalId;
  final String? hospitalIdString; // Added for string IDs
  /// True when opened via App Link / QR URL (back → Home).
  final bool fromDeepLink;

  const DoctorListScreen({
    super.key,
    required this.hospitalId,
    required this.hospitalName,
    required this.hospitalAddress,
    this.hospitalIdString, // Optional parameter
    this.fromDeepLink = false,
  });

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  /// TAB / FILTER — specialization (not department)
  String selectedSpecialization = 'All Doctors';

  /// SEARCH
  String searchText = '';

  List<Doctor> allDoctors = [];
  List<String> specializationList = ['All Doctors'];

  bool isLoading = true;
  String? errorMessage;

  List<Doctor> get filteredDoctors {
    return allDoctors.where((doctor) {
      if (selectedSpecialization != 'All Doctors' &&
          doctor.specialization.toLowerCase().trim() !=
              selectedSpecialization.toLowerCase().trim()) {
        return false;
      }

      if (!doctor.name.toLowerCase().contains(searchText.toLowerCase())) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadDoctors();
  }

  Future<void> loadDoctors() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Use string ID if available, otherwise use int ID
      final dynamic hospitalIdToUse =
          widget.hospitalIdString ?? widget.hospitalId;

      final DoctorApiResponse response =
          await HospitalService.fetchDoctorsWithMeta(hospitalIdToUse);

      setState(() {
        allDoctors = response.doctors;

        // Specialization tabs (alphabetical, "All Doctors" first).
        // Prefer API specializations; fall back to names on doctor records.
        final fromApi = response.specializations.values
            .where((s) => s.trim().isNotEmpty)
            .toSet();
        final fromDoctors = response.doctors
            .map((d) => d.specialization.trim())
            .where((s) => s.isNotEmpty && s.toLowerCase() != 'general')
            .toSet();
        final names = {...fromApi, ...fromDoctors}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        specializationList = ['All Doctors', ...names];

        if (!specializationList.contains(selectedSpecialization)) {
          selectedSpecialization = 'All Doctors';
        }

        isLoading = false;
      });

      // If no doctors found, show a message
      if (response.doctors.isEmpty) {
        _showNoDoctorsDialog();
      }
    } catch (e) {
      debugPrint('Error loading doctors: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });

      // Show error dialog
      _showErrorDialog(e.toString());
    }
  }

  void _showNoDoctorsDialog() {
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Doctors Found'),
          content: const Text(
              'No doctors are available for this hospital at the moment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to load doctors: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              loadDoctors(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void openFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        String tempSpecialization = selectedSpecialization;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Specialization',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: specializationList.contains(tempSpecialization)
                        ? tempSpecialization
                        : null,
                    items: specializationList
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          tempSpecialization = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B6F71),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        this.setState(() {
                          selectedSpecialization = tempSpecialization;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Apply filter',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildTab(String text) {
    final bool isSelected = selectedSpecialization == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedSpecialization = text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B6F71) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2B6F71) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent, // ✅ same color
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Column(
            children: [
              Text(
                widget.hospitalName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0x1F62C6FF),
          elevation: 0,
          centerTitle: true,
          title: Column(
            children: [
              Text(
                widget.hospitalName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Error loading doctors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loadDoctors,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B6F71),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !widget.fromDeepLink,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.fromDeepLink) {
          handleDetailBack(context, fromDeepLink: true);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0x1F62C6FF),
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.hospitalName,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.hospitalAddress,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => handleDetailBack(
            context,
            fromDeepLink: widget.fromDeepLink,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              /// SPECIALIZATION TABS
              if (specializationList.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: specializationList
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: buildTab(s),
                          ),
                        )
                        .toList(),
                  ),
                )
              else
                const SizedBox.shrink(),

              const SizedBox(height: 16),

              /// SEARCH
              TextField(
                onChanged: (value) => setState(() => searchText = value),
                decoration: InputDecoration(
                  hintText: 'Search by doctor name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed:
                        specializationList.length > 1 ? openFilter : null,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// LIST
              Expanded(
                child: filteredDoctors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No doctors found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredDoctors.length,
                        itemBuilder: (_, index) =>
                            DoctorCard(doctor: filteredDoctors[index]),
                      ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class DoctorCard extends StatelessWidget {
  final Doctor doctor;

  const DoctorCard({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    // Safely get the parent widget data
    final doctorListScreen =
        context.findAncestorWidgetOfExactType<DoctorListScreen>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (doctorListScreen != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorProfileScreen(
                  doctor: doctor,
                  hospitalName: doctorListScreen.hospitalName,
                  hospitalAddress: doctorListScreen.hospitalAddress,
                  hospitalId: doctorListScreen.hospitalId,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: Image.network(
                    doctor.imagePath,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.grey.shade700,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialization,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              FavoriteButton(
                type: FavoritesService.doctor,
                id: doctor.id,
                size: 22,
                snapshot: {
                  'id': doctor.id,
                  'name': doctor.name,
                  'image': doctor.imagePath,
                  'qualification': doctor.specialization,
                  'hospital_name': doctorListScreen?.hospitalName ?? '',
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
