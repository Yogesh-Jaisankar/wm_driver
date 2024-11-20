import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'Home.dart';

class OtpEmailPage extends StatefulWidget {
  final String userid;
  const OtpEmailPage({super.key, required this.userid});
  @override
  State<OtpEmailPage> createState() => _OtpEmailPageState();
}

class _OtpEmailPageState extends State<OtpEmailPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String _requestId = '';
  bool _isOtpSent = false;
  final FocusNode _EmailFocusNode = FocusNode();
  bool _isDbOpen = false; // Track the database connection state
  late mongo.Db db;
  bool _isLocationFetched = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    // Request focus to open the keyboard
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_EmailFocusNode);
    });

    _initializeDb();
  }

  // Function to send OTP
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showToast('Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    const url = 'https://auth.otpless.app/auth/v1/initiate/otp';
    const clientId = 'BMLA40B09523RI0YC53JLVRFIRCD3H4B';
    const clientSecret = 'iagegm2vpok0r0blncbyrio9yuktx8y6';

    final headers = {
      'Content-Type': 'application/json',
      'clientId': clientId,
      'clientSecret': clientSecret,
    };

    final body = jsonEncode({
      'email': email,
      'channels': ['EMAIL'],
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isOtpSent = true;
          _requestId = data['requestId']; // Save requestId for OTP verification
        });
        _showToast('OTP sent successfully to $email');
      } else {
        _showToast('Failed to send OTP. Please try again.');
      }
    } catch (e) {
      _showToast('Error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to verify OTP
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showToast('Please enter the OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    const url = 'https://auth.otpless.app/auth/v1/verify/otp';
    const clientId = 'BMLA40B09523RI0YC53JLVRFIRCD3H4B';
    const clientSecret = 'iagegm2vpok0r0blncbyrio9yuktx8y6';

    final headers = {
      'Content-Type': 'application/json',
      'clientId': clientId,
      'clientSecret': clientSecret,
    };

    final body = jsonEncode({
      'requestId': _requestId, // Using the saved requestId
      'otp': otp,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        // Navigate to the home screen after successful OTP verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Home()),
        );
        _showToast('Email verified successfully!');

        _StoreEmail();
      } else {
        _showToast('Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showToast('Error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to show toast messages
  void _showToast(String message) {
    toastification.show(
      alignment: Alignment.topLeft,
      context: context,
      title: Text(message),
      type: ToastificationType.warning,
      style: ToastificationStyle.flatColored,
      showProgressBar: false,
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  Future<void> _initializeDb() async {
    db = await mongo.Db.create(
        "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");
    await db.open();
    setState(() {
      _isDbOpen = true; // Set DB open state
    });
  }

  Future<void> _StoreEmail() async {
    String email = _emailController.text;
    final collection = db.collection('driver'); // Your collection name

    final updateResult = await collection.updateOne(
      mongo.where.eq('_id',
          widget.userid), // Replace userId with actual user document's _id
      mongo.modify.set('Email', email), // Set the new logo field
    );
  }

  // Function to get user's current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showToast(
          "Location services are disabled. Please enable them to continue.");
      return;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showToast(
            "Location permission denied. Please allow location access to continue.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showToast(
          "Location permissions are permanently denied. Please enable them in settings.");
      return;
    }

    // Fetch the user's location
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLocationFetched = true;
      });

      _showToast("Location fetched successfully!");
    } catch (e) {
      _showToast("Error fetching location: $e");
    }
  }

  // Function to store location in the database
  Future<void> _storeLocation() async {
    if (!_isLocationFetched || _latitude == null || _longitude == null) {
      _showToast("Please fetch your location first.");
      return;
    }

    final collection = db.collection('driver');

    final updateResult = await collection.updateOne(
      mongo.where.eq('_id', widget.userid),
      mongo.modify
          .set('latitude', _latitude)
          .set('longitude', _longitude), // Save latitude and longitude
    );

    if (updateResult.isAcknowledged) {
      _showToast("Location stored successfully!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Home(),
        ),
      );
    } else {
      _showToast("Failed to store location. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              if (!_isOtpSent) ...[
                Text(
                  "Enter Your mail address",
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Raleway",
                      fontSize: 20),
                ),
                SizedBox(height: 25),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.black87,
                      )),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      focusNode: _EmailFocusNode,
                      style: TextStyle(fontWeight: FontWeight.bold),
                      controller: _emailController,
                      cursorColor: Colors.black87,
                      decoration: InputDecoration(
                        hintText: "wm@example.com",
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? Center(child: Lottie.asset("assets/lottie/loading.json"))
                    : Center(
                        child: GestureDetector(
                        onTap: () {
                          _sendOtp();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: 50,
                            width: 150,
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: Text(
                                "Send OTP",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      )),
              ] else ...[
                Text(
                  "OTP has been sent to \n ${_emailController.text}",
                  style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Raleway",
                      fontSize: 20),
                ),
                SizedBox(height: 25),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.black87,
                      )),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      cursorColor: Colors.black87,
                      controller: _otpController,
                      decoration: InputDecoration(
                        hintText: 'Enter OTP',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? Center(child: Lottie.asset("assets/lottie/loading.json"))
                    : Center(
                        child: GestureDetector(
                          onTap: () {
                            _verifyOtp();
                          },
                          child: Container(
                            height: 50,
                            width: 150,
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: Text(
                                "Verify OTP",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
