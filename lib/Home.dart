import 'dart:async'; // Import Timer for polling
import 'dart:convert'; // For base64 decoding

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator for location
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:toggle_switch/toggle_switch.dart';

import 'PickupLocation.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0; // 0: Available, 1: Busy
  late mongo.Db db;
  late mongo.DbCollection driversCollection;
  late mongo.DbCollection rideRequestsCollection;
  bool _isDbOpen = false;
  bool _isLoading = true; // Loading indicator flag
  String? userId = "6369686307";
  ImageProvider? _avatarImage;
  List<Map<String, dynamic>> _rideRequests =
      []; // Holds the decoded base64 image

  Timer? _pollingTimer; // Nullable type
  // Timer for polling ride requests

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (userId != null) {
      try {
        await _initializeDb(); // Ensure database is initialized
        if (_isDbOpen) {
          await _fetchDriverStatus(); // Fetch driver status
          await _fetchRideRequests(); // Fetch initial ride requests
          _startPolling(); // Start polling for new ride requests
        }
      } catch (e) {
        print('Error during initialization: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Hide the loader after initialization
          });
        }
      }
    }
  }

  Future<void> _initializeDb() async {
    try {
      // Create a separate variable for the first database (Drivers)
      var db1 = await mongo.Db.create(
          "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");

      // Create a separate variable for the second database (Users)
      var db2 = await mongo.Db.create(
          "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Users?retryWrites=true&w=majority&appName=wm");

      // Open both databases
      await db1.open();
      await db2.open();

      // Use the first database for driversCollection
      driversCollection = db1.collection('driver');
      // Use the second database for rideRequestsCollection
      rideRequestsCollection = db2.collection('ride_requests');

      print('Database initialized.');

      // Fetch the driver's current position and update the location
      Position position = await _getCurrentLocation();
      await _updateDriverLocation(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _isDbOpen = true; // Set DB open state to true
        });
      }
    } catch (e) {
      print('Database connection error: $e');
    }
  }

  Future<void> _fetchRideRequests() async {
    db = await mongo.Db.create(
        "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Users?retryWrites=true&w=majority&appName=wm");
    await db.open();
    rideRequestsCollection = db.collection('ride_requests');

    if (rideRequestsCollection == null || userId == null) {
      print('RideRequestsCollection or userId is not initialized.');
      return;
    }

    try {
      // Fetch all pending ride requests without any proximity check
      final requests =
          await rideRequestsCollection.find({'status': 'pending'}).toList();

      // Fetch the current location of the driver
      Position currentPosition = await _getCurrentLocation();

      // Calculate the distance from the driver's current location to each ride request
      for (var rideRequest in requests) {
        // Extract latitude and longitude from the pickup_location field
        List pickupCoordinates = rideRequest['pickup_location']['coordinates'];
        double pickupLat = pickupCoordinates[1]; // Latitude is the second value
        double pickupLng = pickupCoordinates[0]; // Longitude is the first value

        // Calculate distance from driver's location to pickup point
        double distanceInMeters = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          pickupLat,
          pickupLng,
        );

        // Convert the distance from meters to kilometers
        double distanceInKm = distanceInMeters / 1000;

        // Format the distance to a more readable string (1 km, 2.5 km, etc.)
        rideRequest['distance'] = '${distanceInKm.toStringAsFixed(2)} km';
      }

      setState(() {
        _rideRequests = requests; // Update the list of ride requests
      });
    } catch (e) {
      print('Error fetching ride requests: $e');
    }
  }

  Future<void> _acceptRideRequest(String rideRequestId) async {
    if (rideRequestsCollection == null || userId == null) {
      print('RideRequestsCollection or userId is not initialized.');
      return;
    }

    try {
      // Find the ride request details
      final rideRequest =
          await rideRequestsCollection.findOne({'_id': rideRequestId});
      if (rideRequest == null) {
        print('Ride request not found.');
        return;
      }

      // Update the ride request status and assign the driver
      final result = await rideRequestsCollection.updateOne(
        {'_id': rideRequestId},
        {
          r'$set': {
            'status': 'accepted',
            'driver_id': userId,
          }
        },
      );

      if (result.isAcknowledged) {
        // After acceptance, update driver status to 'Busy'
        await _updateDriverStatus('Busy');

        // Navigate to the PickupLocationPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickupLocationPage(
              pickupLocation: rideRequest['pickup_location'],
            ),
          ),
        );

        print('Ride accepted successfully');
        setState(() {
          // Remove the accepted ride from the list
          _rideRequests
              .removeWhere((request) => request['_id'] == rideRequestId);
        });
      }
    } catch (e) {
      print('Error accepting ride request: $e');
    }
  }

  Future<Position> _getCurrentLocation() async {
    print("Fetching driver's current location...");
    // Get the current position using geolocator
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      throw Exception("Location services are disabled.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print("Location permission denied");
        throw Exception("Location permission denied");
      }
    }

    // Get the position after permission is granted
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return position;
  }

  Future<void> _updateDriverLocation(double latitude, double longitude) async {
    if (driversCollection == null || userId == null) {
      print('DriversCollection or userId is not initialized.');
      return;
    }

    try {
      final result = await driversCollection.updateOne(
        {'_id': userId},
        {
          r'$set': {
            'latitude': latitude,
            'longitude': longitude,
          }
        },
        upsert: true,
      );
      print('Updated location: Latitude: $latitude, Longitude: $longitude');
      print(
          'Update result: ${result.isAcknowledged}, Matched: ${result.nMatched}, Modified: ${result.nModified}');
    } catch (e) {
      print('Error updating driver location: $e');
    }
  }

  Future<void> _fetchDriverStatus() async {
    if (driversCollection == null || userId == null) {
      print('DriversCollection or userId is not initialized.');
      return;
    }

    try {
      final driver = await driversCollection.findOne({'_id': userId});
      if (driver != null && mounted) {
        // Update status
        setState(() {
          _currentIndex = driver['status'] == 'Available' ? 0 : 1;

          // Decode the base64 logo
          if (driver['logo'] != null) {
            final decodedBytes = base64Decode(driver['logo']);
            _avatarImage = MemoryImage(decodedBytes);
            print("Avatar image loaded from database.");
          }
        });
      }
    } catch (e) {
      print('Error fetching driver status: $e');
    }
  }

  Future<void> _updateDriverStatus(String status) async {
    if (driversCollection == null || userId == null) {
      print('DriversCollection or userId is not initialized.');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true; // Show loading indicator while updating
      });
    }

    try {
      final result = await driversCollection.updateOne(
        {'_id': userId},
        {
          r'$set': {'status': status}
        },
        upsert: true,
      );
      print(
          'Updated status: $status. Result: ${result.isAcknowledged}, Matched: ${result.nMatched}, Modified: ${result.nModified}');
    } catch (e) {
      print('Error updating driver status: $e');
    } finally {
      if (mounted) {
        // Check if the widget is still mounted
        setState(() {
          _isLoading = false; // Hide the loader after updating
        });
      }
    }
  }

  // Start polling the server every 30 seconds for new ride requests
  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _fetchRideRequests(); // Fetch new ride requests
    });
  }

  @override
  void dispose() {
    if (_isDbOpen) db.close(); // Close the database connection
    _pollingTimer
        ?.cancel(); // Stop the polling timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text(
                  "WM",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: "Raleway",
                      fontSize: 20),
                ),
                const SizedBox(width: 30),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: ToggleSwitch(
                    customTextStyles: [
                      TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Raleway",
                          fontSize: 15),
                    ],
                    initialLabelIndex:
                        _currentIndex, // Initialize with current index
                    totalSwitches: 2,
                    centerText: true,
                    borderWidth: 1,
                    activeFgColor: Colors.orange,
                    activeBgColor: [Colors.black87],
                    borderColor: [Colors.black87],
                    inactiveBgColor: Colors.white70,
                    labels: const ['Available', 'Busy'],
                    onToggle: (index) {
                      setState(() {
                        _currentIndex = index!;
                      });
                      _updateDriverStatus(index == 0 ? 'Available' : 'Busy');
                    },
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _rideRequests.isEmpty
                        ? Center(
                            child: Text('No ride requests available.'),
                          )
                        : ListView.builder(
                            itemCount: _rideRequests.length,
                            itemBuilder: (context, index) {
                              final rideRequest = _rideRequests[index];
                              return ListTile(
                                title: Text(rideRequest['distance'] ??
                                    'Distance not available'),
                                trailing: GestureDetector(
                                  onTap: () {
                                    _acceptRideRequest(rideRequest['_id']);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius:
                                              BorderRadius.circular(15)),
                                      height: 50,
                                      width: 100,
                                      child: Center(
                                          child: Text(
                                        "Accept",
                                        style: TextStyle(color: Colors.white),
                                      )),
                                    ),
                                  ),
                                ),
                                // trailing: ElevatedButton(
                                //   onPressed: () {
                                //     // Handle accept ride
                                //     _acceptRideRequest(rideRequest['_id']);
                                //   },
                                //   child: const Text('Accept'),
                                // ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
