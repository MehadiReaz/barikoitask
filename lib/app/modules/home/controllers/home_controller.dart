import 'dart:developer' as developer;
import 'dart:math' as math; // Add this import for min/max functions
import 'package:barikoi_maps_place_picker/barikoi_maps_place_picker.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';

class HomeController extends GetxController {
  static const String apiKey =
      'bkoi_cec95e38429731a785f03d7594507d4c991bc8b66ee86b218c5186f7d6fb0c97';
  static const String baseUrl = 'https://barikoi.xyz/v1/api';

  MaplibreMapController? mapController;
  final Rx<LatLng> currentLocation = LatLng(23.835677, 90.380325).obs;
  final RxString selectedAddress = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool showDirections = false.obs;
  Symbol? currentMarker;
  Line? currentRoute;

  @override
  void onInit() {
    super.onInit();
    getCurrentLocation();
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading.value = true;
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar(
          'Error',
          'Location services are disabled. Please enable location services.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Error',
            'Location permissions are denied',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar(
          'Error',
          'Location permissions are permanently denied. Please enable them in settings.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      currentLocation.value = LatLng(position.latitude, position.longitude);

      if (mapController != null) {
        await moveToCurrentLocation();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to get current location: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> moveToCurrentLocation() async {
    if (mapController != null) {
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          currentLocation.value,
          15.0,
        ),
      );
    }
  }

  Future<void> getReverseGeocode(LatLng location) async {
    isLoading.value = true;
    try {
      // Construct the URL
      final url =
          'https://barikoi.xyz/v1/api/search/reverse/geocode/server/bkoi_cec95e38429731a785f03d7594507d4c991bc8b66ee86b218c5186f7d6fb0c97/place?latitude=${location.latitude}&longitude=${location.longitude}&district=true&post_code=true&country=true&sub_district=true&union=true&pauroshova=true&location_type=true&division=true&address=true&area=true';
      developer.log('Reverse Geocode Request URL: $url');

      // Make the API call
      final response = await http.get(Uri.parse(url));
      developer.log('Response Status Code: ${response.statusCode}');
      developer.log('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        developer.log('Decoded Data: $data');

        // Check for top-level status or error messages that might be in the response
        if (data['status'] != null && data['status'] != 200) {
          throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
        }

        // Check if 'place' exists and is not null
        if (!data.containsKey('place')) {
          throw Exception('Response missing place data');
        }

        final place = data['place'];
        if (place == null) {
          throw Exception('Place data is null');
        }

        // Check for address field
        if (!place.containsKey('address')) {
          // Try alternative fields if 'address' doesn't exist
          final alternativeAddress = place['area'] ??
              place['address_components']?['address'] ??
              place['formatted_address'];

          if (alternativeAddress != null) {
            selectedAddress.value = alternativeAddress.toString();
            await _updateMarker(location);
            return;
          }
          throw Exception('No address information found in response');
        }

        final address = place['address'];
        if (address == null) {
          throw Exception('Address field is null');
        }

        // Update the address and marker
        selectedAddress.value = address.toString();
        await _updateMarker(location);

        developer.log('Successfully updated address: $address');
      } else {
        final errorMsg = 'Failed to get address: HTTP ${response.statusCode}';
        developer.log(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      final errorMsg = e.toString();
      developer.log('Error in getReverseGeocode: $errorMsg');
      Get.snackbar(
        'Error',
        'Failed to get address information: $errorMsg',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

// Helper method to validate and update marker
  Future<void> _updateMarker(LatLng location) async {
    try {
      if (currentMarker != null) {
        await mapController?.removeSymbol(currentMarker!);
      }

      if (mapController == null) {
        throw Exception('Map controller is null');
      }

      currentMarker = await mapController?.addSymbol(
        SymbolOptions(
          geometry: location,
          iconImage:
              'custom-marker', // Make sure this image is available in your map style
          iconSize: 0.5,
        ),
      );

      if (currentMarker == null) {
        throw Exception('Failed to create marker');
      }

      developer.log(
          'Successfully updated marker at: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      developer.log('Error updating marker: $e');
      throw Exception('Failed to update marker: $e');
    }
  }

  Future<void> getDirections(LatLng destination) async {
    try {
      isLoading.value = true;
      await clearRoute();
      var url =
          'https://barikoi.xyz/v1/api/route/$apiKey/${currentLocation.value.longitude},${currentLocation.value.latitude},${destination.longitude},${destination.latitude}?geometries=polyline';
      final response = await http.get(
        Uri.parse(url),
      );
      developer.log(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes']?.isNotEmpty == true &&
            data['routes'][0]['geometry']?['coordinates'] != null) {
          final List<dynamic> coordinates =
              data['routes'][0]['geometry']['coordinates'];

          List<LatLng> points = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          if (points.isNotEmpty) {
            currentRoute = await mapController?.addLine(
              LineOptions(
                geometry: points,
                lineColor: "#FF0000",
                lineWidth: 3.0,
                lineOpacity: 0.8,
              ),
            );

            await _adjustCameraToShowRoute(points);
            showDirections.value = true;
          }
        } else {
          throw Exception('Invalid route data format');
        }
      } else {
        throw Exception('Failed to get directions');
      }
    } catch (e) {
      developer.log(e.toString());
      Get.snackbar(
        'Error',
        'Failed to get directions: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _adjustCameraToShowRoute(List<LatLng> points) async {
    if (points.isEmpty) return;

    double minLat = points.map((p) => p.latitude).reduce(math.min);
    double maxLat = points.map((p) => p.latitude).reduce(math.max);
    double minLng = points.map((p) => p.longitude).reduce(math.min);
    double maxLng = points.map((p) => p.longitude).reduce(math.max);

    // Add padding to the bounds
    double latPadding = (maxLat - minLat) * 0.1;
    double lngPadding = (maxLng - minLng) * 0.1;

    await mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latPadding, minLng - lngPadding),
          northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
        ),
        left: 50,
        right: 50,
        top: 50,
        bottom: 50,
      ),
    );
  }

  Future<void> clearRoute() async {
    if (currentRoute != null) {
      await mapController?.removeLine(currentRoute!);
      currentRoute = null;
    }
  }

  Future<void> clearSelection() async {
    if (currentMarker != null) {
      await mapController?.removeSymbol(currentMarker!);
      currentMarker = null;
    }
    selectedAddress.value = '';
    await clearRoute();
    showDirections.value = false;
  }

  Future<void> handlePickedPlace(PickResult result) async {
    try {
      if (result.latitude == null || result.longitude == null) {
        throw Exception('Invalid location data');
      }

      final location = LatLng(
        double.parse(result.latitude.toString()),
        double.parse(result.longitude.toString()),
      );

      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15.0),
      );

      // Update the marker and address
      selectedAddress.value =
          result.addrComps.toString() ?? 'Address not available';
      await _updateMarker(location);

      // Log additional place data if available
      if (result.areaComps != null) {
        print('Area Components: ${result.areaComps}');
      }
      if (result.district != null) {
        print('District: ${result.district}');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update selected location: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
