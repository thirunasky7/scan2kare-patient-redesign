import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class LocationService {
  static const String _keyAddress = 'saved_address';
  static const String _keyLat = 'saved_latitude';
  static const String _keyLng = 'saved_longitude';
  static const String _googleApiKey = "AIzaSyCdntEDArTMSulXGyjZgzCcXc-KYCileLA";

  // Save location
  static Future<void> saveLocation(
      String address, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAddress, address);
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
  }

  // Load saved location
  static Future<Map<String, dynamic>?> loadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyAddress);
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);

    if (address != null && lat != null && lng != null) {
      return {
        'address': address,
        'latitude': lat,
        'longitude': lng,
      };
    }
    return null;
  }

  // Clear saved location
  static Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
  }

  /// Verifies location services and permissions, optionally requesting permission.
  ///
  /// This method checks if location services are enabled and if the app has
  /// the necessary location permissions. If services are disabled or permissions
  /// are denied, it shows a user-friendly Snackbar with an action button to open
  /// system settings.
  ///
  /// **Behavior:**
  /// - If location services are disabled: Shows Snackbar with "Open Location Settings" action
  /// - If permission is permanently denied: Shows Snackbar with "Open App Settings" action
  /// - If permission is denied: Requests permission via system dialog
  /// - If permission is granted: Returns true
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for showing SnackBars
  ///
  /// **Returns:**
  /// - `true` if location access is ready (services enabled and permission granted)
  /// - `false` if location access is not available (user must enable via settings)
  static Future<bool> ensureLocationReady(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('DEBUG LocationService: Service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location services are disabled. Please enable them to use your current location.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: Colors.white,
              onPressed: Geolocator.openLocationSettings,
            ),
          ),
        );
      }
      debugPrint('DEBUG LocationService: Services disabled, returning false');
      return false;
    }

    final permission = await Geolocator.checkPermission();
    debugPrint('DEBUG LocationService: Current permission: $permission');
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location permission is permanently denied. Please enable it in app settings.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Open Settings',
              textColor: Colors.white,
              onPressed: Geolocator.openAppSettings,
            ),
          ),
        );
      }
      debugPrint(
          'DEBUG LocationService: Permission permanently denied, returning false');
      return false;
    }

    if (permission == LocationPermission.denied) {
      final newPermission = await Geolocator.requestPermission();
      debugPrint(
          'DEBUG LocationService: Requested permission, result: $newPermission');
      if (newPermission == LocationPermission.denied ||
          newPermission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission is required to use your current location.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Open Settings',
                textColor: Colors.white,
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
        debugPrint(
            'DEBUG LocationService: Permission denied after request, returning false');
        return false;
      }
    }

    debugPrint('DEBUG LocationService: Location ready, returning true');
    return true;
  }

  /// Gets the current device location using GPS/network.
  ///
  /// This method checks if location services are enabled and if the app has
  /// the necessary permissions before requesting the current position.
  ///
  /// **Behavior:**
  /// - Checks if location services are enabled (throws exception if disabled)
  /// - Checks if location permission is granted (throws exception if denied)
  /// - Requests permission if not yet granted
  /// - Returns current position with high accuracy
  ///
  /// **Returns:** Current device position (latitude, longitude, accuracy)
  ///
  /// **Throws:**
  /// - Exception if location services are disabled
  /// - Exception if location permissions are denied or permanently denied
  static Future<Position> getCurrentLocation() async {
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

  /// Gets the human-readable address for the current device location.
  ///
  /// This method retrieves the current GPS coordinates and converts them to
  /// a human-readable address using the Google Places API.
  ///
  /// **Returns:** Human-readable address string or error message if failed
  static Future<String> getRealAddressFromCurrentLocation() async {
    try {
      Position position = await getCurrentLocation();
      String realAddress = await getAddressFromLatLngWithPlacesApi(
          position.latitude, position.longitude);
      return realAddress;
    } catch (e) {
      debugPrint("Error getting real address: $e");
      return "Unable to get address";
    }
  }

  /// Converts latitude/longitude coordinates to a human-readable address using Google Places API.
  ///
  /// This method uses the Google Places Nearby Search API to find the closest
  /// place to the given coordinates, then retrieves detailed place information
  /// to get a formatted address. This is more reliable than the basic Geocoding API.
  ///
  /// **Parameters:**
  /// - [lat]: Latitude coordinate
  /// - [lng]: Longitude coordinate
  ///
  /// **Returns:** Human-readable address string or "Current Location" if failed
  static Future<String> getAddressFromLatLngWithPlacesApi(
      double lat, double lng) async {
    try {
      // Use Places API nearby search to find the closest place
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=100' // 100 meters radius
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final place = data['results'][0];

          // Get the place details for more accurate address
          String placeId = place['place_id'];
          String detailedAddress = await getPlaceDetails(placeId);

          if (detailedAddress.isNotEmpty &&
              detailedAddress != "Unknown Location") {
            return detailedAddress;
          }

          // Fallback to place name and vicinity
          String name = place['name'] ?? '';
          String vicinity = place['vicinity'] ?? '';

          if (name.isNotEmpty && vicinity.isNotEmpty) {
            return "$name, $vicinity";
          } else if (name.isNotEmpty) {
            return name;
          }
        }
      }

      return "Current Location";
    } catch (e) {
      debugPrint("Places API error: $e");
      return "Current Location";
    }
  }

  /// Gets detailed place information using Google Place ID.
  ///
  /// This method retrieves detailed information about a place using its
  /// Place ID, including the formatted address, name, and vicinity.
  ///
  /// **Parameters:**
  /// - [placeId]: Google Place ID for the location
  ///
  /// **Returns:** Formatted address string or empty string if failed
  static Future<String> getPlaceDetails(String placeId) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=formatted_address,name,vicinity'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];

          // Return formatted address if available
          if (result['formatted_address'] != null) {
            return result['formatted_address'];
          }

          // Fallback to name + vicinity
          String name = result['name'] ?? '';
          String vicinity = result['vicinity'] ?? '';

          if (name.isNotEmpty && vicinity.isNotEmpty) {
            return "$name, $vicinity";
          } else if (name.isNotEmpty) {
            return name;
          }
        }
      }

      return "";
    } catch (e) {
      debugPrint("Place details error: $e");
      return "";
    }
  }

  /// Converts latitude/longitude coordinates to address using Google Geocoding API.
  ///
  /// This is an alternative method that uses the Google Geocoding API for
  /// reverse geocoding. Note: Requires the Geocoding API to be enabled in
  /// Google Cloud Console.
  ///
  /// **Parameters:**
  /// - [lat]: Latitude coordinate
  /// - [lng]: Longitude coordinate
  ///
  /// **Returns:** Formatted address string or "Current Location" if failed
  static Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=en';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return result['formatted_address'] ?? "Current Location";
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint(
              "Geocoding API not enabled. Please enable it in Google Cloud Console");
          return "Enable Geocoding API";
        }
      }

      return "Current Location";
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      return "Current Location";
    }
  }

  // Get place name (using Places API directly)
  static Future<String> getPlaceNameFromLatLng(double lat, double lng) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=50'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final place = data['results'][0];
          String name = place['name'] ?? '';
          String vicinity = place['vicinity'] ?? '';

          if (name.isNotEmpty && vicinity.isNotEmpty) {
            return "$name, $vicinity";
          } else if (name.isNotEmpty) {
            return name;
          }
        }
      }

      return "Current Location";
    } catch (e) {
      debugPrint("Place name error: $e");
      return "Current Location";
    }
  }

  // Get short address for display
  static String getShortAddress(String fullAddress) {
    if (fullAddress.isEmpty ||
        fullAddress == "Current Location" ||
        fullAddress == "Enable Geocoding API") {
      return "Select Location";
    }

    List<String> parts = fullAddress.split(',');
    if (parts.length > 2) {
      return parts.sublist(parts.length - 3).join(',').trim();
    }
    return fullAddress;
  }
}
