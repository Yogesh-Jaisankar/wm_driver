import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:toggle_switch/toggle_switch.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0; // 0: Available, 1: Busy
  late mongo.Db db;
  late mongo.DbCollection driversCollection;
  bool _isDbOpen = false;
  bool _isLoading = true; // Loading indicator flag
  String? userId = "6369686307";

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
          await _fetchDriverStatus(); // Fetch status after DB initialization
        }
      } catch (e) {
        print('Error during initialization: $e');
      } finally {
        if (mounted) {
          // Check if the widget is still mounted
          setState(() {
            _isLoading = false; // Hide the loader after initialization
          });
        }
      }
    }
  }

  Future<void> _initializeDb() async {
    try {
      db = await mongo.Db.create(
          "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");
      await db.open();
      driversCollection = db.collection('driver');
      if (mounted) {
        setState(() {
          _isDbOpen = true;
        });
      }
      print('Database initialized and collection ready.');
    } catch (e) {
      print('Database connection error: $e');
    }
  }

  Future<void> _fetchDriverStatus() async {
    if (driversCollection == null || userId == null) {
      print('DriversCollection or userId is not initialized.');
      return;
    }

    try {
      final driver = await driversCollection.findOne({'_id': userId});
      if (driver != null && driver['status'] != null && mounted) {
        // Check if mounted
        setState(() {
          _currentIndex = driver['status'] == 'Available' ? 0 : 1;
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
          'Update result: ${result.isAcknowledged}, Matched: ${result.nMatched}, Modified: ${result.nModified}');
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
                const Text("WM"),
                const SizedBox(width: 30),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ToggleSwitch(
                    initialLabelIndex:
                        _currentIndex, // Initialize with current index
                    totalSwitches: 2,
                    centerText: true,
                    minWidth: 100,
                    activeFgColor: Colors.black,
                    activeBgColor: _currentIndex == 0
                        ? [Colors.lightGreen] // Green for "Available"
                        : [Colors.redAccent], // Red for "Busy"
                    inactiveBgColor: Colors.white70,
                    borderColor: _currentIndex == 0
                        ? [Colors.lightGreen] // Green for "Available"
                        : [Colors.redAccent],
                    borderWidth: 0.5,
                    labels: ['Available', 'Busy'],
                    onToggle: (index) {
                      if (index != null) {
                        setState(() {
                          _currentIndex =
                              index; // Update index and rebuild widget
                        });
                        final status =
                            _currentIndex == 0 ? 'Available' : 'Busy';
                        _updateDriverStatus(
                            status); // Update status in the database
                      }
                    },
                  ),
                ),
                CircleAvatar(
                  radius: 20, // Circle size
                  backgroundImage: const AssetImage('assets/icons/grey.jpeg'),
                  backgroundColor:
                      Colors.grey[200], // Fallback background color
                )
              ],
            ),
          ),
          body: _isDbOpen
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        "assets/lottie/loading.json",
                      ),
                      Text(
                        textAlign: TextAlign.center,
                        "Please wait while we search for orders...",
                        style: TextStyle(
                            fontSize: 18,
                            fontFamily: "Raleway",
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                )
              : const SizedBox.shrink(), // Hide Lottie when not initialized
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.black87,
              ), // Spinner in the center
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    if (_isDbOpen) db.close(); // Close the database connection
    super.dispose();
  }
}
