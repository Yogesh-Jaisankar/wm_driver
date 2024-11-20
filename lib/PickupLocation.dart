import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickupLocationPage extends StatefulWidget {
  final Map<String, dynamic> pickupLocation;

  const PickupLocationPage({Key? key, required this.pickupLocation})
      : super(key: key);

  @override
  _PickupLocationPageState createState() => _PickupLocationPageState();
}

class _PickupLocationPageState extends State<PickupLocationPage> {
  late double latitude;
  late double longitude;
  bool isNearPickup = false;

  @override
  void initState() {
    super.initState();
    latitude = widget.pickupLocation['coordinates'][1];
    longitude = widget.pickupLocation['coordinates'][0];
    _checkProximity();
  }

  Future<void> _checkProximity() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );
      if (distance <= 500) {
        setState(() {
          isNearPickup = true;
        });
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _showOtpDialog() async {
    String otp = "";

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
            onChanged: (value) {
              otp = value;
            },
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
                if (otp.length == 4) {
                  Navigator.of(context).pop(); // Close the dialog
                  _startRide(otp);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please enter a valid 4-digit OTP."),
                    ),
                  );
                }
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  void _startRide(String otp) {
    // Logic for starting the ride with the entered OTP
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Ride started with OTP: $otp")),
    );
    // Navigate or update the UI after starting the ride
    Navigator.pop(context, "Ride Started");
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
                  _showOtpDialog(); // Show OTP dialog
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
