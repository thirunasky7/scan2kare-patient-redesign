import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hospitals.dart';
import '../services/hospital_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'profile_screen.dart';
import 'my_bookings_screen.dart';
import '../services/auth_service.dart';
import '../utils/auth_nav.dart';
import 'doctors_screen.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import '../services/location_service.dart';
import '../utils/deeplink_nav.dart';
import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';
import 'favorites_screen.dart';
import 'main_shell.dart';

class HospitalHomeScreen extends StatefulWidget {
  const HospitalHomeScreen({super.key});

  @override
  State<HospitalHomeScreen> createState() => _HospitalHomeScreenState();
}

class _HospitalHomeScreenState extends State<HospitalHomeScreen> {
  String selectedFilter =
      'All'; // Changed from selectedTab to selectedFilter to match home screen

  String _userName = 'Guest';
  String _address = '';

  // Hospital lists
  List<HospitalItem> hospitals = [];
  List<HospitalItem> filteredHospitals = [];
  List<HospitalItem> displayedHospitals = []; // For pagination

  // Loading states
  bool isLoading = true;
  bool isPaginationLoading = false;
  bool hasMoreData = true;

  // Pagination
  int currentPage = 1;
  final int itemsPerPage = 5;
  final ScrollController _scrollController = ScrollController();

  // Hospital Search
  final TextEditingController _hospitalSearchController =
      TextEditingController();
  String searchQuery = '';

  // Google Places Integration - Separate controller for location
  final FlutterGooglePlacesSdk places =
      FlutterGooglePlacesSdk("AIzaSyCdntEDArTMSulXGyjZgzCcXc-KYCileLA");
  final TextEditingController _locationSearchController =
      TextEditingController();
  List<AutocompletePrediction> predictions = [];
  Timer? _debounce;
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadSavedLocation();
    _scrollController.addListener(_onScroll);
    homeNavigationTick.addListener(_closeLocationSearch);
  }

  @override
  void dispose() {
    homeNavigationTick.removeListener(_closeLocationSearch);
    _debounce?.cancel();
    _locationSearchController.dispose();
    _hospitalSearchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ================= LOCATION METHODS =================

  Future<void> _loadSavedLocation() async {
    final savedLocation = await LocationService.loadLocation();
    if (savedLocation != null) {
      setState(() {
        _address = savedLocation['address'];
      });
      await loadHospitalsWithLocation(
        savedLocation['latitude'],
        savedLocation['longitude'],
      );
    } else {
      // If no saved location, use device location with full address
      try {
        final position = await LocationService.getCurrentLocation();
        final address = await LocationService.getAddressFromLatLng(
          position.latitude,
          position.longitude,
        );

        await LocationService.saveLocation(
          address,
          position.latitude,
          position.longitude,
        );

        setState(() {
          _address = address;
        });

        await loadHospitalsWithLocation(position.latitude, position.longitude);
      } catch (e) {
        loadHospitals();
      }
    }
  }

  Future<void> loadHospitals() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final data = await HospitalService.fetchNearbyHospitals(
        pos.latitude,
        pos.longitude,
      );

      // Sort hospitals alphabetically by name (ascending order)
      data.sort((a, b) => a.distance.compareTo(b.distance));

      setState(() {
        hospitals = data;
        filteredHospitals = data;
        _resetPagination();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Hospital API error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> loadHospitalsWithLocation(double lat, double lng) async {
    setState(() {
      isLoading = true;
      currentPage = 1;
      displayedHospitals = [];
    });

    try {
      final data = await HospitalService.fetchNearbyHospitals(lat, lng);

      // Sort hospitals alphabetically by name (ascending order)
      data.sort((a, b) => a.distance.compareTo(b.distance));

      setState(() {
        hospitals = data;
        filteredHospitals = data;
        _loadMoreData();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Hospital API error: $e");
      setState(() => isLoading = false);
    }
  }

  // ================= GOOGLE PLACES METHODS =================

  void onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      getPredictions(value);
    });
  }

  Future<void> getPredictions(String input) async {
    if (input.isEmpty) {
      setState(() => predictions = []);
      return;
    }

    final result = await places.findAutocompletePredictions(
      input,
      countries: ["in"],
    );

    setState(() {
      predictions = result.predictions;
    });
  }

  Future<void> selectPlace(AutocompletePrediction prediction) async {
    try {
      final details = await places.fetchPlace(
        prediction.placeId,
        fields: [PlaceField.Location, PlaceField.Name, PlaceField.Address],
      );

      final location = details.place!.latLng!;
      final formattedAddress =
          details.place!.address ?? prediction.fullText ?? "Selected Location";

      // Save to SharedPreferences
      await LocationService.saveLocation(
        formattedAddress,
        location.lat,
        location.lng,
      );

      setState(() {
        _address = formattedAddress;
        _locationSearchController.clear(); // Clear location search
        predictions = [];
        _isSearching = false;
        _searchFocusNode.unfocus();
      });

      await loadHospitalsWithLocation(location.lat, location.lng);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location updated"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error selecting place: $e");
      setState(() {
        predictions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      _isSearching = false;
      isLoading = true;
    });

    final ready = await LocationService.ensureLocationReady(context);
    if (!ready) {
      setState(() => isLoading = false);
      return;
    }

    try {
      setState(() {
        _isSearching = false;
        isLoading = true;
      });

      final position = await LocationService.getCurrentLocation();
      final address = await LocationService.getAddressFromLatLng(
          position.latitude, position.longitude);

      await LocationService.saveLocation(
        address,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _address = address;
        _locationSearchController.clear(); // Clear location search
      });

      await loadHospitalsWithLocation(position.latitude, position.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location updated"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error getting current location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error getting location"),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _locationSearchController.clear();
        predictions = [];
        _searchFocusNode.unfocus();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeLocationSearch() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isSearching && _locationSearchController.text.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      predictions = [];
      _locationSearchController.clear();
    });
  }

  // ================= PAGINATION METHODS =================

  void _resetPagination() {
    currentPage = 1;
    hasMoreData = true;
    displayedHospitals = [];
    _loadMoreData();
  }

  void _loadMoreData() {
    if (!hasMoreData || isPaginationLoading) return;

    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= filteredHospitals.length) {
      setState(() {
        hasMoreData = false;
      });
      return;
    }

    setState(() {
      isPaginationLoading = true;
    });

    // Simulate network delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          final newItems =
              filteredHospitals.skip(startIndex).take(itemsPerPage).toList();
          displayedHospitals.addAll(newItems);
          currentPage++;
          isPaginationLoading = false;

          if (displayedHospitals.length >= filteredHospitals.length) {
            hasMoreData = false;
          }
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  // ================= FILTER METHODS =================

  void filterHospitals(String type) {
    setState(() {
      selectedFilter = type;
      _applyFilters();
    });
  }

  void filterHospitalsBySearch(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    // Start with all hospitals
    List<HospitalItem> results = List.from(hospitals);

    // Apply type filter - exactly like home screen
    if (selectedFilter != "All") {
      if (selectedFilter == "Hospital") {
        // For Hospital filter, show both Hospital and Clinic types
        results = results
            .where((h) =>
                h.type.toLowerCase() == "hospital" ||
                h.type.toLowerCase() == "clinic")
            .toList();
      } else {
        // For other filters (like Diagnostics)
        results = results
            .where((h) => h.type.toLowerCase() == selectedFilter.toLowerCase())
            .toList();
      }
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      results = results
          .where((hospital) =>
              hospital.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              hospital.address
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Sort results alphabetically by name
    results.sort((a, b) => a.distance.compareTo(b.distance));

    setState(() {
      filteredHospitals = results;
      _resetPagination();
    });
  }

  // ================= NAVIGATION =================

  void _openDoctors(HospitalItem hospital) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorListScreen(
          hospitalId: hospital.id,
          hospitalName: hospital.name,
          hospitalAddress: hospital.address,
        ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Stephen James';
      _address = prefs.getString('address') ?? 'Chitlapakkam, Chennai';
    });
  }

  // ================= FILTER BUTTON (like home screen) =================

  Widget filterButton(String text) {
    bool isSelected = selectedFilter == text;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFF2B6F71) : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 36),
      ),
      onPressed: () => filterHospitals(text),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: _buildLocationSearchPanel()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/gradient.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSearchPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _toggleSearch,
              ),
              Expanded(
                child: TextField(
                  controller: _locationSearchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: "Search for your area, city...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _locationSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _locationSearchController.clear();
                              setState(() => predictions = []);
                            },
                          )
                        : null,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
            ],
          ),
        ),
        if (_locationSearchController.text.isEmpty)
          ListTile(
            leading:
                const Icon(Icons.my_location, color: Color(0xFF243C90)),
            title: const Text(
              "Use My Current Location",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: useCurrentLocation,
          ),
        Expanded(
          child: ListView.builder(
            itemCount: predictions.length,
            itemBuilder: (context, index) {
              final p = predictions[index];
              return ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(p.fullText ?? ""),
                subtitle: Text(p.secondaryText),
                onTap: () => selectPlace(p),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= APP BAR =================

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, // ✅ same color
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black),
        onPressed: openMainDrawer,
      ),
      centerTitle: true,
      title: GestureDetector(
        onTap: _toggleSearch,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _userName,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 200), // ✅ FIX WIDTH
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      _address.isNotEmpty ? _address : "Tap to set location",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Favourites',
          icon: const Icon(Icons.favorite_border, color: Colors.black),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesScreen()),
          ),
        ),
      ],
    );
  }

  // ================= BODY =================

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter buttons like home screen
          Container(
            margin: const EdgeInsets.only(right: 15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    filterButton("All"),
                    const SizedBox(width: 12),
                    filterButton("Hospital"),
                    const SizedBox(width: 12),
                    filterButton("Clinic"),
                    const SizedBox(width: 12),
                    filterButton("Diagnostics"),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchBar(), // Hospital search bar
          const SizedBox(height: 12),
          _buildBannerCard(),
          const SizedBox(height: 12),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredHospitals.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text("No hospitals found"),
                      ),
                    )
                  : Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedHospitals.length,
                          itemBuilder: (context, index) {
                            final hospital = displayedHospitals[index];
                            return hospitalCard(
                              hospital,
                              onTap: () => _openDoctors(hospital),
                            );
                          },
                        ),
                        if (isPaginationLoading)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (!hasMoreData && displayedHospitals.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              "No more hospitals",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
        ],
      ),
    );
  }

  // ================= SEARCH BAR =================

  Widget _buildSearchBar() {
    return TextField(
      controller: _hospitalSearchController,
      onChanged: filterHospitalsBySearch,
      decoration: InputDecoration(
        hintText: "Search by Hospital/Clinic name",
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _hospitalSearchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _hospitalSearchController.clear();
                  filterHospitalsBySearch('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  // ================= BANNER =================

  Widget _buildBannerCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blue.shade50,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Connect with the hospitals nearby you",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              "https://images.unsplash.com/photo-1586773860418-d37222d8fce3",
              width: 140,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 140,
                  height: 120,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // ================= HOSPITAL CARD =================

  Widget hospitalCard(HospitalItem hospital, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    hospital.image,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_hospital,
                                size: 40, color: Colors.grey.shade600),
                            const SizedBox(height: 4),
                            Text(
                              'Image\nunavailable',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: FavoriteButton(
                    type: FavoritesService.hospital,
                    id: hospital.id,
                    background: Colors.white.withOpacity(0.85),
                    padding: const EdgeInsets.all(6),
                    snapshot: {
                      'id': hospital.id,
                      'name': hospital.name,
                      'image': hospital.image,
                      'address': hospital.address,
                      'hospital_type': hospital.type,
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hospital.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(hospital.address,
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text("${hospital.rating}"),
                      const SizedBox(width: 6),
                      Text("(${hospital.reviews} Reviews)"),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Color(0xFF2B6F71)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${hospital.distance.toStringAsFixed(2)} km / ${hospital.time}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.local_hospital, size: 16),
                      const SizedBox(width: 4),
                      Text(hospital.type),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DRAWER =================

  Drawer appDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                "assets/scan-logo.png",
                width: 120,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("My Profile"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileUpdateScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text("My Bookings"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    goToLogin();
  }
}
