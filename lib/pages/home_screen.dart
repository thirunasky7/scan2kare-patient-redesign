import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'doctors_screen.dart';
import 'profile_screen.dart';
import '../services/hospital_service.dart';
import '../services/auth_service.dart';
import '../utils/auth_nav.dart';
import '../utils/token_storage.dart';
import '../models/hospitals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/banner_slider.dart';
import '../widgets/spotlight_slider.dart';
import '../models/SeamlessHospital.dart';
import '../widgets/seamless_hospital_widget.dart';
import 'my_bookings_screen.dart';
import 'live_appointment_screen.dart';
import '../widgets/connect_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/appointment_service.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import 'dart:convert';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import '../services/location_service.dart';
import '../widgets/health_care_card.dart';
import '../widgets/service_cards_widget.dart';
import 'type_based_hospital_screen.dart';
import '../utils/deeplink_nav.dart';
import '../utils/local_storage.dart';
import 'health_hub_screen.dart';
import 'second_opinion_page.dart';
import 'health_hub_video_screen.dart';
import '../widgets/health_hub_slider.dart';
import 'my_opinions_screen.dart';
import '../widgets/priority_service.dart';
import 'gyno_byte_landing.dart';
import '../config/api_config.dart';
import 'favorites_screen.dart';
import 'main_shell.dart';

enum ServiceType { all, hospital, clinic, diagnostic }

class ServiceItem {
  final String title;
  final String subtitle;
  final String image;
  final ServiceType type;

  ServiceItem({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.type,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'Guest';
  String _address = '';
  String _shortAddress = ''; // For displaying shorter version if needed
  String selectedFilter = 'All';

  List<HospitalItem> hospitals = [];
  List<HospitalItem> filteredHospitals = [];
  List<HospitalItem> displayHospitals = []; // For limited display (8 items)

  bool isLoading = true;
  bool isAppointmentLoading = true;

  AppointmentModel? nearestAppointment;
  List<AppointmentModel> upcomingList = [];

  // Google Places Integration - Separate controller for location search
  final FlutterGooglePlacesSdk places =
      FlutterGooglePlacesSdk("AIzaSyCdntEDArTMSulXGyjZgzCcXc-KYCileLA");
  List<AutocompletePrediction> predictions = [];
  Timer? _debounce;
  bool _isSearching = false;
  final TextEditingController _locationSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    checkToken();
    _loadSavedLocation();
    _userName = LocalStorage.displayNameNotifier.value;
    LocalStorage.displayNameNotifier.addListener(_onDisplayNameChanged);
    homeNavigationTick.addListener(_onHomeNavigation);
    _loadUserProfile();
    fetchUpcomingAppointments();
  }

  void _onHomeNavigation() {
    if (!mounted) return;
    _closeLocationSearch();
  }

  void _closeLocationSearch() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isSearching && _locationSearchController.text.isEmpty) return;
    setState(() {
      _isSearching = false;
      predictions = [];
      _locationSearchController.clear();
    });
  }

  void _onDisplayNameChanged() {
    if (!mounted) return;
    final name = LocalStorage.displayNameNotifier.value;
    if (name.isNotEmpty && name != _userName) {
      setState(() => _userName = name);
    }
  }

  String formatDate(String date) {
    DateTime d = DateTime.parse(date);
    return DateFormat("EEE, dd MMM yyyy").format(d);
  }

  String formatTime(String time) {
    DateTime t = DateTime.parse("2026-01-01 $time");
    return DateFormat("HH:mm").format(t);
  }

  Future<void> _loadSavedLocation() async {
    final savedLocation = await LocationService.loadLocation();
    if (savedLocation != null) {
      setState(() {
        _address = savedLocation['address'];
        _shortAddress = LocationService.getShortAddress(_address);
      });
      await loadHospitalsWithLocation(
        savedLocation['latitude'],
        savedLocation['longitude'],
      );
    } else {
      // If no saved location, use device location with real address
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
          _shortAddress = LocationService.getShortAddress(address);
        });

        await loadHospitalsWithLocation(position.latitude, position.longitude);
      } catch (e) {
        loadHospitals();
      }
    }
  }

  // Helper method to get shorter version of address for display
  String _getShortAddress(String fullAddress) {
    if (fullAddress.isEmpty) return "Tap to set location";

    // Try to get a shorter version (city/area name)
    List<String> parts = fullAddress.split(',');
    if (parts.length > 2) {
      // Return last 2-3 parts for shorter display
      return parts.sublist(parts.length - 3).join(',').trim();
    }
    return fullAddress;
  }

  // Google Places Search Methods
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

      // Get the formatted address from the place details
      String formattedAddress = details.place!.address ?? "";

      // If address is empty, try to get it from primary text
      if (formattedAddress.isEmpty) {
        formattedAddress = prediction.fullText ?? "Selected Location";
      }

      // Save to SharedPreferences
      await LocationService.saveLocation(
        formattedAddress,
        location.lat,
        location.lng,
      );

      setState(() {
        _address = formattedAddress;
        _shortAddress = LocationService.getShortAddress(formattedAddress);
        _locationSearchController.clear();
        predictions = [];
        _isSearching = false;
        _searchFocusNode.unfocus();
      });

      await loadHospitalsWithLocation(location.lat, location.lng);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location updated: $_shortAddress"),
            duration: const Duration(seconds: 2),
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
      final position = await LocationService.getCurrentLocation();

      // Get actual address from coordinates
      final address = await LocationService.getAddressFromLatLng(
          position.latitude, position.longitude);

      await LocationService.saveLocation(
        address,
        position.latitude,
        position.longitude,
      );

      setState(() {
        _address = address;
        _shortAddress = LocationService.getShortAddress(address);
        _locationSearchController.clear();
      });

      await loadHospitalsWithLocation(position.latitude, position.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location updated: $_shortAddress"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      //debugPrint("Error getting current location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error getting location: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> loadHospitalsWithLocation(double lat, double lng) async {
    setState(() => isLoading = true);

    try {
      final data = await HospitalService.fetchNearbyHospitals(lat, lng);

      // Sort hospitals alphabetically by name (ascending order)
      data.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        hospitals = data;
        filteredHospitals = data;
        _updateDisplayHospitals(); // Update display list (limit to 8)
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Hospital API error: $e");
      setState(() => isLoading = false);
    }
  }

  // Update display hospitals based on filtered list (limited to 8)
  void _updateDisplayHospitals() {
    displayHospitals = filteredHospitals.take(8).toList();
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

  Widget _upcomingAppointmentCard() {
    if (isAppointmentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (nearestAppointment == null) {
      return const SizedBox();
    }

    final appt = nearestAppointment!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF243C90), Color(0xFF243C90)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Upcoming Appointments",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _infoBox(
                  Icons.calendar_today,
                  formatDate(appt.appointmentDate),
                  "Appointment Date",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoBox(
                  Icons.access_time,
                  formatTime(appt.appointmentTime),
                  "Appointment Time",
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: appt.profileImage.isNotEmpty
                          ? Image.network(
                              appt.profileImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const CircleAvatar(
                                radius: 22,
                                child: Icon(Icons.person),
                              ),
                            )
                          : const CircleAvatar(
                              radius: 22,
                              child: Icon(Icons.person),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.doctorName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (appt.specialization.isNotEmpty)
                          Text(
                            appt.specialization,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        if (appt.hospitalName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            appt.hospitalName,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                LiveAppointmentScreen.routeFromAppointment(appt),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white24,
              ),
              child: const Text('Live View'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchUpcomingAppointments() async {
    try {
      final token = await TokenStorage.getToken();

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/home-upcoming-appointments"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        final data = jsonData['data'];

        if (data is List) {
          upcomingList = data
              .map((e) => AppointmentModel.fromJson(e))
              .where(_isActiveHomeUpcoming)
              .toList();
        } else if (data != null) {
          final appt = AppointmentModel.fromJson(data);
          upcomingList = _isActiveHomeUpcoming(appt) ? [appt] : [];
        }

        nearestAppointment = getNearestAppointmentModel(upcomingList);

        setState(() {
          isAppointmentLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Appointment API error: $e");
      setState(() => isAppointmentLoading = false);
    }
  }

  bool _isActiveHomeUpcoming(AppointmentModel a) {
    final s = a.status.toLowerCase().trim();
    if (s == 'cancelled' || s == 'canceled' || s == 'cancel') return false;
    if (s == 'completed' ||
        s == 'complete' ||
        s == 'done' ||
        s == 'attended' ||
        s == 'no_show') {
      return false;
    }
    return true;
  }

  AppointmentModel? getNearestAppointmentModel(List<AppointmentModel> list) {
    DateTime now = DateTime.now();

    final futureAppointments = list.where((a) {
      final apptDateTime =
          DateTime.parse("${a.appointmentDate} ${a.appointmentTime}");
      return apptDateTime.isAfter(now);
    }).toList();

    if (futureAppointments.isEmpty) return null;

    futureAppointments.sort((a, b) {
      final aTime = DateTime.parse("${a.appointmentDate} ${a.appointmentTime}");
      final bTime = DateTime.parse("${b.appointmentDate} ${b.appointmentTime}");
      return aTime.compareTo(bTime);
    });

    return futureAppointments.first;
  }

  Future<void> _loadUserProfile() async {
    // Show cached name immediately (e.g. after Edit Profile → back).
    final cached = LocalStorage.displayNameNotifier.value;
    if (cached.isNotEmpty && mounted && cached != _userName) {
      setState(() => _userName = cached);
    }

    try {
      final data = await AuthService.getUserProfile();
      final apiName = (data['name'] ?? '').toString().trim();
      await LocalStorage.syncDisplayPrefs({
        'name': apiName.isNotEmpty ? apiName : cached,
        'address': data['address'] ?? '',
        'email': data['email'] ?? '',
      });

      if (!mounted) return;
      setState(() {
        if (apiName.isNotEmpty) {
          _userName = apiName;
        } else if (cached.isNotEmpty) {
          _userName = cached;
        } else {
          _userName = 'Guest';
        }
        if (_address.isEmpty) {
          _address = data['address'] ?? '';
          _shortAddress = _getShortAddress(_address);
        }
      });
    } catch (e) {
      debugPrint("Profile load error: $e");
      if (!mounted) return;
      if (cached.isNotEmpty && cached != _userName) {
        setState(() => _userName = cached);
      }
    }
  }

  void checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint("Token in Home: ${prefs.getString('token')}");
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> loadHospitals() async {
    try {
      Position pos = await _determinePosition();

      final data = await HospitalService.fetchNearbyHospitals(
        pos.latitude,
        pos.longitude,
      );

      // Sort hospitals alphabetically by name (ascending order)
      data.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        hospitals = data;
        filteredHospitals = data;
        _updateDisplayHospitals(); // Update display list (limit to 8)
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Location/Hospital API error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await AuthService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
      await LocalStorage.clear();
    }

    if (mounted) {
      goToLogin();
    }
  }

  @override
  void dispose() {
    homeNavigationTick.removeListener(_onHomeNavigation);
    LocalStorage.displayNameNotifier.removeListener(_onDisplayNameChanged);
    _debounce?.cancel();
    _locationSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent, // ✅ same color
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.black),
        onPressed: () async {
          await _loadUserProfile();
          openMainDrawer();
        },
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
              constraints: const BoxConstraints(maxWidth: 200),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.black),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      _address.isNotEmpty ? _address : "Tap to set location",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black,
                      ),
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
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BannerSlider(),
          const SizedBox(height: 16),
          const ServiceCardsWidget(),
          const SizedBox(height: 8),
          const PriorityServices(),
          const SizedBox(height: 12),
          _upcomingAppointmentCard(),
        ],
      ),
    );
  }

  Widget _serviceIcon(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(icon, color: color, size: 22),
            ),

            const SizedBox(height: 8),

            /// FIXED HEIGHT TEXT AREA
            SizedBox(
              height: 32,
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthPriorityCard(BuildContext context) {
    return Container(
      height: 140,
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF243C90), Color(0xFF429FF0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      // child: Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     Text("Healthcare system",
      //         style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
      //     const SizedBox(height: 14),
      //     Text("Health is priority",
      //         style: GoogleFonts.poppins(
      //             fontSize: 14,
      //             color: Colors.white,
      //             fontWeight: FontWeight.w700)),
      //     const SizedBox(height: 8),
      //     OutlinedButton(
      //       onPressed: () {},
      //       style: OutlinedButton.styleFrom(
      //         backgroundColor: Colors.white,
      //         side: const BorderSide(color: Colors.white, width: 1),
      //         shape: RoundedRectangleBorder(
      //           borderRadius: BorderRadius.circular(0),
      //         ),
      //       ),
      //       child: const Text("KNOW MORE"),
      //     ),
      //   ],
      // ),
    );
  }

  Drawer appDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Image.asset(
                      "assets/scan-logo.png",
                      width: 100,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),

                  /// My Profile
                  _drawerItem(Icons.person_outline, "My Profile", () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileUpdateScreen(),
                      ),
                    );
                    _loadUserProfile();
                  }),

                  /// My Bookings
                  _drawerItem(Icons.book, "My Bookings", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    );
                  }),

                  /// Health Hub Articles
                  _drawerItem(Icons.article, "Health Hub Articles", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HealthHubScreen(),
                      ),
                    );
                  }),

                  /// Health Hub Videos
                  _drawerItem(Icons.video_library, "Health Hub Videos", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HealthHubVideoScreen(),
                      ),
                    );
                  }),

                  /// Second Opinion
                  _drawerItem(Icons.message, "Second Opinion", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyOpinionsScreen(),
                      ),
                    );
                  })
                ],
              ),
            ),

            /// Logout Button
            SizedBox(
              width: double.infinity,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DRAWER ITEM =================

Widget _drawerItem(IconData icon, String title, VoidCallback? onTap) {
  return Column(
    children: [
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
}

Widget _infoBox(IconData icon, String value, String label) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
  );
}
