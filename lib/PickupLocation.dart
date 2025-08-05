import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'RoutePage.dart';

class PickupLocationPage extends StatefulWidget {
  final Map<String, dynamic> pickupLocation;

  PickupLocationPage({Key? key, required this.pickupLocation})
      : super(key: key);

  @override
  _PickupLocationPageState createState() => _PickupLocationPageState();
}

class _PickupLocationPageState extends State<PickupLocationPage> {
  late double latitude;
  late double longitude;
  bool isNearPickup = false;
  bool _isFetchingLocation = false; // To track ongoing operations

  @override
  void initState() {
    super.initState();
    latitude = widget.pickupLocation['coordinates'][1];
    longitude = widget.pickupLocation['coordinates'][0];
    _checkProximity();
  }

  @override
  void dispose() {
    _isFetchingLocation = false; // Stop any ongoing fetch
    super.dispose();
  }

  Future<void> _checkProximity() async {
    try {
      _isFetchingLocation = true;
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!_isFetchingLocation) return; // Ensure the widget is not disposed

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );

      if (mounted) {
        setState(() {
          isNearPickup = distance <= 3000;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error getting location: $e");
      }
    }
  }

  Future<void> _showOtpDialog() async {
    if (!mounted) return; // Ensure the widget is still in the widget tree
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter OTP"),
          content: TextField(
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              hintText: "Enter 4-digit OTP",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _startRide(); // Start the ride
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  void _startRide() {
    if (!mounted) return; // Ensure the widget is still in the widget tree
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoutePage(
          currentLocation: LatLng(
            widget.pickupLocation['coordinates'][1],
            widget.pickupLocation['coordinates'][0],
          ),
          dropLocation: LatLng(12.8912559, 80.08100089999999), // Example drop
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: 14.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pickup Location"),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              markers: {
                Marker(
                  markerId: const MarkerId("pickupLocation"),
                  position: LatLng(latitude, longitude),
                  infoWindow: const InfoWindow(
                    title: "Pickup Location",
                  ),
                ),
              },
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (isNearPickup) {
                  _showOtpDialog();
                } else {
                  Navigator.pop(context); // Go back
                }
              },
              child: Text(isNearPickup ? "Start Ride" : "Back"),
            ),
          ),
        ],
      ),
    );
  }
}
