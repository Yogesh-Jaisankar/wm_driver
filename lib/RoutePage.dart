import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'FarePage.dart';

class RoutePage extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng dropLocation;

  const RoutePage({
    Key? key,
    required this.currentLocation,
    required this.dropLocation,
  }) : super(key: key);

  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  String _distance = '';
  String _duration = '';

  @override
  void initState() {
    super.initState();
    _addMarkers();
    _drawRoute();
  }

  void _addMarkers() {
    _markers.add(Marker(
      markerId: const MarkerId("currentLocation"),
      position: widget.currentLocation,
      infoWindow: const InfoWindow(title: "Current Location"),
    ));
    _markers.add(Marker(
      markerId: const MarkerId("dropLocation"),
      position: widget.dropLocation,
      infoWindow: const InfoWindow(title: "Drop Location"),
    ));
  }

  Future<void> _drawRoute() async {
    final response = await http.get(
      Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${widget.currentLocation.latitude},${widget.currentLocation.longitude}&destination=${widget.dropLocation.latitude},${widget.dropLocation.longitude}&key=AIzaSyA2Nqezz1idcqRvJRXEu68O7t2aJC99Tyw',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final routes = data['routes'];
      if (routes != null && routes.isNotEmpty) {
        final points = routes[0]['overview_polyline']['points'];
        final legs = routes[0]['legs'][0];
        setState(() {
          _distance = legs['distance']['text'];
          _duration = legs['duration']['text'];
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: _decodePolyline(points),
              color: Colors.black87,
              width: 5,
            ),
          );
        });
      }
    } else {
      print('Failed to load directions: ${response.body}');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.currentLocation,
              zoom: 14.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Distance: $_distance',
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Duration: $_duration',
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                double distanceInKm =
                    double.tryParse(_distance.split(' ')[0]) ??
                        0.0; // Assumes distance text is like "10.5 km"
                double fare =
                    distanceInKm * 7; // Fare calculation at Rs. 7 per km
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FarePage(amount: fare),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Finish Ride',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
