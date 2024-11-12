import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:barikoi_maps_place_picker/barikoi_maps_place_picker.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  static const styleId = 'osm-liberty';
  static const mapUrl =
      'https://map.barikoi.com/styles/$styleId/style.json?key=${HomeController.apiKey}';

  // Initial position for Dhaka, Bangladesh
  static const kInitialPosition = LatLng(23.835677, 90.380325);

  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(() => MaplibreMap(
                initialCameraPosition: CameraPosition(
                  target: controller.currentLocation.value,
                  zoom: 15.0,
                ),
                styleString: mapUrl,
                onMapCreated: (MaplibreMapController mapController) async {
                  controller.mapController = mapController;
                  await controller.getCurrentLocation();
                },
                onMapClick: (point, latLng) =>
                    controller.getReverseGeocode(latLng),
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.None,
                myLocationRenderMode: MyLocationRenderMode.NORMAL,
              )),

          // Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showPlacePicker(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              'Search places...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            right: 16,
            bottom: 200,
            child: FloatingActionButton(
              heroTag: 'currentLocation',
              onPressed: () => controller.moveToCurrentLocation(),
              child: const Icon(Icons.my_location),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
            ),
          ),

          // Bottom Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Obx(() => _buildBottomPanel()),
          ),
        ],
      ),
    );
  }

  void _showPlacePicker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlacePicker(
          apiKey: HomeController.apiKey,
          initialPosition: controller.currentLocation.value,
          useCurrentLocation: true,
          selectInitialPosition: true,
          usePinPointingSearch: true,
          getAdditionalPlaceData: [
            PlaceDetails.area_components,
            PlaceDetails.addr_components,
            PlaceDetails.district
          ],
          onPlacePicked: (result) {
            Navigator.of(context).pop();
            controller.handlePickedPlace(
              result,
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (controller.isLoading.value) {
      return Container(
        height: 100,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (controller.selectedAddress.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Location',
                    style: Get.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.clearSelection(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                controller.selectedAddress.value,
                style: Get.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (controller.currentMarker != null) {
                      final markerPosition =
                          controller.currentMarker!.options.geometry!;
                      controller.getDirections(markerPosition);
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
