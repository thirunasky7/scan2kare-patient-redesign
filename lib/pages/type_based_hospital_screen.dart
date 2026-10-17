import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hospitals.dart';
import 'scanner_screen.dart';
import '../services/hospital_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'doctors_screen.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import '../services/location_service.dart';
import '../utils/deeplink_nav.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/favorites_service.dart';
import '../widgets/favorite_button.dart';

class TypeBasedHospitalScreen extends StatefulWidget {
  final String? type;

  const TypeBasedHospitalScreen({
    super.key,
    this.type,
  });

  @override
  State<TypeBasedHospitalScreen> createState() =>
      _TypeBasedHospitalScreenState();
}

enum _LocationStatus {
  unknown,
  loading,
  granted,
  denied,
  disabled,
  permanentlyDenied
}

class _TypeBasedHospitalScreenState extends State<TypeBasedHospitalScreen>
    with WidgetsBindingObserver {
  String _userName = 'Guest';
  String _address = '';

  // Hospital lists
  List<HospitalItem> hospitals = [];
  List<HospitalItem> displayedHospitals = []; // For pagination

  // Loading states
  bool isLoading = true;
  bool isPaginationLoading = false;
  bool hasMoreData = true;

  // Location state
  _LocationStatus _locationStatus = _LocationStatus.unknown;

  // Pagination
  int currentPage = 1;
  final int itemsPerPage = 20;
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
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _loadSavedLocation();
    _scrollController.addListener(_onScroll);
    homeNavigationTick.addListener(_closeLocationSearch);
  }

  @override
  void dispose() {
    homeNavigationTick.removeListener(_closeLocationSearch);
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _locationSearchController.dispose();
    _hospitalSearchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have changed location settings while the app was in the
      // background. Refresh location status and reload hospitals if needed.
      _loadSavedLocation();
    }
  }

  // ================= LOCATION METHODS =================

  Future<void> _loadSavedLocation() async {
    setState(() => _locationStatus = _LocationStatus.loading);

    // First verify location permission/service state before trying to load.
    final locationState = await _checkLocationState();
    if (locationState != _LocationStatus.granted) {
      setState(() {
        _locationStatus = locationState;
        isLoading = false;
      });
      return;
    }

    final savedLocation = await LocationService.loadLocation();
    if (savedLocation != null) {
      setState(() {
        _address = savedLocation['address'];
        _locationStatus = _LocationStatus.granted;
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
          _locationStatus = _LocationStatus.granted;
        });

        await loadHospitalsWithLocation(position.latitude, position.longitude);
      } catch (e) {
        final newState = await _checkLocationState();
        setState(() {
          _locationStatus = newState;
          isLoading = false;
        });
      }
    }
  }

  /// Checks the current location service and permission state.
  ///
  /// This method determines whether location services are enabled and if the
  /// app has the necessary location permissions. It returns a status enum
  /// that can be used to display appropriate UI prompts.
  ///
  /// **Returns:**
  /// - `_LocationStatus.granted`: Location services enabled and permission granted
  /// - `_LocationStatus.disabled`: Location services are disabled
  /// - `_LocationStatus.denied`: Location permission is denied
  /// - `_LocationStatus.permanentlyDenied`: Location permission is permanently denied
  Future<_LocationStatus> _checkLocationState() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _LocationStatus.disabled;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return _LocationStatus.permanentlyDenied;
    }
    if (permission == LocationPermission.denied) {
      return _LocationStatus.denied;
    }
    return _LocationStatus.granted;
  }

  /// Requests location permission from the user and reloads the screen if granted.
  ///
  /// This method checks if location services are enabled before requesting
  /// permission. If services are disabled, it sets the location status to
  /// disabled (which will prompt the user to enable services via the UI).
  /// If permission is granted, it loads the saved location and reloads hospitals.
  ///
  /// **Behavior:**
  /// - If location services are disabled: Sets status to `_LocationStatus.disabled`
  /// - If permission is permanently denied: Sets status to `_LocationStatus.permanentlyDenied`
  /// - If permission is denied: Sets status to `_LocationStatus.denied`
  /// - If permission is granted: Loads saved location and reloads hospitals
  ///
  /// **Side effects:**
  /// - Updates `_locationStatus` state
  /// - Calls `_loadSavedLocation()` on success
  Future<void> _requestLocationPermission() async {
    setState(() => _locationStatus = _LocationStatus.loading);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('DEBUG: Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      setState(() => _locationStatus = _LocationStatus.disabled);
      debugPrint('DEBUG: Location status set to disabled');
      return;
    }

    final permission = await Geolocator.requestPermission();
    debugPrint('DEBUG: Permission result: $permission');
    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = _LocationStatus.permanentlyDenied);
      debugPrint('DEBUG: Location status set to permanently denied');
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() => _locationStatus = _LocationStatus.denied);
      debugPrint('DEBUG: Location status set to denied');
      return;
    }

    debugPrint('DEBUG: Permission granted, loading saved location');
    await _loadSavedLocation();
  }

  Future<void> loadHospitals() async {
    setState(() => _locationStatus = _LocationStatus.loading);

    final locationState = await _checkLocationState();
    if (locationState != _LocationStatus.granted) {
      setState(() {
        _locationStatus = locationState;
        isLoading = false;
      });
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<HospitalItem> data;

      // Check if type is provided - use type-based API
      if (widget.type != null && widget.type!.isNotEmpty) {
        data = await HospitalService.fetchHospitalsByType(
          widget.type!,
          pos.latitude.toString(),
          pos.longitude.toString(),
        );
      } else {
        // Otherwise use location-based API
        data = await HospitalService.fetchNearbyHospitals(
          pos.latitude,
          pos.longitude,
        );
      }

      // Sort hospitals alphabetically by name (ascending order)
      if (data.isNotEmpty) {
        data.sort((a, b) => a.distance.compareTo(b.distance));
      }

      setState(() {
        hospitals = data;
        _resetPagination();
        isLoading = false;
      });
    } catch (e) {
      final newState = await _checkLocationState();
      setState(() {
        _locationStatus = newState;
        isLoading = false;
      });
    }
  }

  Future<void> loadHospitalsWithLocation(double lat, double lng) async {
    setState(() {
      isLoading = true;
      currentPage = 1;
      displayedHospitals = []; // Clear displayed hospitals
      hospitals = []; // Clear hospitals list
    });

    try {
      List<HospitalItem> data = [];
      // CASE 1: Type-based filtering (when type is provided)
      if (widget.type != null && widget.type!.isNotEmpty) {
        try {
          // Try to fetch hospitals by type with location parameters
          data = await HospitalService.fetchHospitalsByType(
            widget.type!,
            lat.toString(),
            lng.toString(),
          );

          // If type-based API returns empty, try location-based as fallback
          if (data.isEmpty) {
            data = await HospitalService.fetchNearbyHospitals(lat, lng);

            if (data.isNotEmpty) {
              data = data
                  .where((h) =>
                      h.type.toLowerCase() == widget.type!.toLowerCase() ||
                      (widget.type!.toLowerCase() == "hospital" &&
                          (h.type.toLowerCase() == "hospital" ||
                              h.type.toLowerCase() == "clinic")))
                  .toList();
            }
          }
        } catch (e) {
          data = await HospitalService.fetchNearbyHospitals(lat, lng);
          if (data.isNotEmpty) {
            data = data
                .where((h) =>
                    h.type.toLowerCase() == widget.type!.toLowerCase() ||
                    (widget.type!.toLowerCase() == "hospital" &&
                        (h.type.toLowerCase() == "hospital" ||
                            h.type.toLowerCase() == "clinic")))
                .toList();
          }
        }
      }
      // CASE 2: Location-based only (no type provided)
      else {
        try {
          data = await HospitalService.fetchNearbyHospitals(lat, lng);
        } catch (e) {
          data = [];
        }
      }

      // Sort hospitals alphabetically by name
      if (data.isNotEmpty) {
        data.sort((a, b) => a.distance.compareTo(b.distance));
        // CRITICAL FIX: Update hospitals list and reset pagination
        setState(() {
          hospitals = data;
          isLoading = false;
        });

        // Call this after hospitals are set
        _resetPagination();
      } else {
        setState(() {
          hospitals = [];
          isLoading = false;
        });

        // Show appropriate message to user
        if (mounted) {
          String message = widget.type != null
              ? "No ${widget.type} hospitals found in your area"
              : "No hospitals found in your area";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to load hospitals. Please try again."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        hospitals = [];
        isLoading = false;
      });
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
      setState(() {
        _isSearching = false;
        isLoading = true; // Show loading immediately
      });

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
        _locationSearchController.clear();
        predictions = [];
        _searchFocusNode.unfocus();
      });

      // Force reload with new location
      await loadHospitalsWithLocation(location.lat, location.lng);
    } catch (e) {
      setState(() {
        predictions = [];
        _isSearching = false;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error selecting location: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> useCurrentLocation() async {
    setState(() {
      _isSearching = false;
      isLoading = true;
    });

    final ready = await LocationService.ensureLocationReady(context);
    if (!ready) {
      final newState = await _checkLocationState();
      setState(() {
        _locationStatus = newState;
        isLoading = false;
      });
      return;
    }

    try {
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
        _locationSearchController.clear();
        _locationStatus = _LocationStatus.granted;
      });

      await loadHospitalsWithLocation(position.latitude, position.longitude);
    } catch (e) {
      final newState = await _checkLocationState();
      setState(() {
        _locationStatus = newState;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error getting location: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // Future<void> useCurrentLocation() async {
  //   try {
  //     setState(() {
  //       _isSearching = false;
  //       isLoading = true;
  //     });

  //     final position = await LocationService.getCurrentLocation();
  //     final address = await LocationService.getAddressFromLatLng(
  //         position.latitude, position.longitude);

  //     await LocationService.saveLocation(
  //       address,
  //       position.latitude,
  //       position.longitude,
  //     );

  //     setState(() {
  //       _address = address;
  //       _locationSearchController.clear(); // Clear location search
  //     });

  //     await loadHospitalsWithLocation(position.latitude, position.longitude);

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Location updated"),
  //           duration: const Duration(seconds: 2),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint("Error getting current location: $e");
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Error getting location"),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //     setState(() => isLoading = false);
  //   }
  // }

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

  void _goHomeFromFooter() {
    _closeLocationSearch();
    navigateToHome(context);
  }

  // ================= PAGINATION METHODS =================

  void _resetPagination() {
    setState(() {
      currentPage = 1;
      hasMoreData = hospitals.isNotEmpty;
      displayedHospitals = [];
    });
    _loadMoreData();
  }

  void _loadMoreData() {
    if (!hasMoreData || isPaginationLoading) {
      return;
    }

    final startIndex = (currentPage - 1) * itemsPerPage;

    if (startIndex >= hospitals.length) {
      setState(() {
        hasMoreData = false;
      });
      return;
    }

    setState(() {
      isPaginationLoading = true;
    });

    // Small delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          final endIndex = (startIndex + itemsPerPage) < hospitals.length
              ? startIndex + itemsPerPage
              : hospitals.length;

          final newItems = hospitals.sublist(startIndex, endIndex);
          displayedHospitals.addAll(newItems);

          currentPage++;
          isPaginationLoading = false;

          if (displayedHospitals.length >= hospitals.length) {
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

  // ================= SEARCH METHODS =================

  void filterHospitalsBySearch(String query) {
    setState(() {
      searchQuery = query;
      _applySearch();
    });
  }

  void _applySearch() {
    if (searchQuery.isEmpty) {
      // Reset pagination with all hospitals
      _resetPagination();
      return;
    }

    final filtered = hospitals
        .where((hospital) =>
            hospital.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            hospital.address.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

// ? ADD THIS LINE
    filtered.sort((a, b) => a.distance.compareTo(b.distance));

    // Update displayed hospitals with filtered results
    setState(() {
      displayedHospitals = filtered.take(itemsPerPage).toList();
      currentPage = 2; // Next page will load from index itemsPerPage
      hasMoreData = filtered.length > itemsPerPage;
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

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: _buildLocationSearchPanel()),
        bottomNavigationBar: AppBottomNav(
          current: AppNavTab.recentHospital,
          onHome: _goHomeFromFooter,
          onScan: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerScreen()),
          ),
          onRecentHospital: () => navigateToRecentHospitalTab(context),
        ),
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
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.recentHospital,
        onHome: _goHomeFromFooter,
        onScan: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        onRecentHospital: () => navigateToRecentHospitalTab(context),
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
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: GestureDetector(
        onTap: _toggleSearch,
        child: Column(
          children: [
            Text(
              _userName,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _address.isNotEmpty ? _address : "Tap to set location",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          // Screen Title based on type
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.type != null
                  ? '${widget.type!.toUpperCase()} HOSPITALS'
                  : 'NEARBY HOSPITALS',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF243C90),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildSearchBar(), // Hospital search bar
          const SizedBox(height: 12),
          _buildBannerCard(),
          const SizedBox(height: 12),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : hospitals.isEmpty
                  ? _buildEmptyState()
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

  // ================= EMPTY STATE =================

  Widget _buildEmptyState() {
    final bool needsLocationAction = _locationStatus != _LocationStatus.granted;

    String title;
    String message;
    String actionLabel;
    IconData icon;
    VoidCallback onAction;

    switch (_locationStatus) {
      case _LocationStatus.disabled:
        title = 'Location services are disabled';
        message =
            'Please enable location services on your device to find nearby hospitals.';
        actionLabel = 'Open Location Settings';
        icon = Icons.location_off;
        onAction = Geolocator.openLocationSettings;
        break;
      case _LocationStatus.denied:
      case _LocationStatus.permanentlyDenied:
      case _LocationStatus.unknown:
        title = 'Location permission required';
        message =
            'We need your location to show nearby hospitals. Please grant location permission.';
        actionLabel = _locationStatus == _LocationStatus.permanentlyDenied
            ? 'Open App Settings'
            : 'Grant Permission';
        icon = Icons.location_searching;
        onAction = _locationStatus == _LocationStatus.permanentlyDenied
            ? Geolocator.openAppSettings
            : _requestLocationPermission;
        break;
      case _LocationStatus.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      case _LocationStatus.granted:
        title = 'No hospitals found';
        message = widget.type != null
            ? 'No ${widget.type} hospitals found in your area.'
            : 'No hospitals found in your area.';
        actionLabel = 'Retry';
        icon = Icons.local_hospital_outlined;
        onAction = _loadSavedLocation;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(0xFF243C90),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF243C90),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF243C90),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (needsLocationAction)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: _toggleSearch,
                  child: const Text('Search location manually'),
                ),
              ),
          ],
        ),
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.type != null
                    ? "Explore ${widget.type} hospitals near you"
                    : "Connect with the hospitals nearby you",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                          size: 16, color: Colors.blue),
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
}
