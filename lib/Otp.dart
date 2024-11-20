import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:otpless_flutter/otpless_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'DriverDetails.dart';
import 'Home.dart'; // Import your HomePage here

class OtpInputPage extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  const OtpInputPage(
      {Key? key, required this.phoneNumber, required this.countryCode})
      : super(key: key);

  @override
  _OtpInputPageState createState() => _OtpInputPageState();
}

class _OtpInputPageState extends State<OtpInputPage> {
  final TextEditingController otpController = TextEditingController();
  final _otplessFlutterPlugin = Otpless();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage; // State variable for error message

  Future<bool> checkIfUserExists(String phoneNumber) async {
    var db = await mongo.Db.create(
        "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");
    await db.open();
    var collection = db.collection('driver');
    var existingUser = await collection.findOne({"_id": phoneNumber});
    await db.close();

    return existingUser != null;
  }

  bool _navigated = false; // Add this variable to track navigation status

  void onOtpVerification(dynamic result) async {
    if (!mounted) return;

    if (result != null && result['statusCode'] == 200) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('phoneNumber', widget.phoneNumber);

      // Check if the phone number exists in the database
      bool userExists = await checkIfUserExists(widget.phoneNumber);

      if (!mounted || _navigated) return; // Prevent multiple navigations

      _navigated = true; // Set the flag to true to prevent future navigation

      if (userExists) {
        // If the user exists, navigate to HomePage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => Home()), // Replace with your target page
          (Route<dynamic> route) => false, // This clears all previous routes
        );

        toastification.show(
          alignment: Alignment.bottomCenter,
          context: context,
          title: Text("Welcome back!"),
          type: ToastificationType.success,
          style: ToastificationStyle.flatColored,
          showProgressBar: false,
          autoCloseDuration: const Duration(seconds: 2),
        );
      } else {
        // If the user doesn't exist, navigate to UserDetailsPage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => DriverDetails(
                  phoneNumber:
                      widget.phoneNumber)), // Replace with your target page
          (Route<dynamic> route) => false, // This clears all previous routes
        );

        // Remove loading state after navigating
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      debugPrint("OTP verification failed: $result");
      if (!mounted) return;

      setState(() {
        _isLoading = false; // Stop loading on failure
      });

      toastification.show(
        alignment: Alignment.bottomCenter,
        context: context,
        title: Text('OTP verification failed. Please try again.'),
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> verifyOtp() async {
    if (_formKey.currentState!.validate()) {
      if (_isLoading) return; // Prevent re-entrant calls
      setState(() {
        _isLoading = true;
        _errorMessage = null; // Reset error message
      });

      Map<String, dynamic> arg = {
        "phone": widget.phoneNumber,
        "countryCode": widget.countryCode,
        "otp": otpController.text,
      };
      _otplessFlutterPlugin.startHeadless(onOtpVerification, arg);
    }
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        "OTP has been sent to ",
                        style: TextStyle(
                            fontSize: 35,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Raleway"),
                      ),
                      Text(
                        widget.phoneNumber,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Text(
                      //   "via Whatsapp",
                      //   style: TextStyle(
                      //     fontSize: 12,
                      //     color: Colors.black87,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      SizedBox(height: 50),
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black87)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextFormField(
                            controller: otpController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              focusColor: Colors.black87,
                              hintText: "Enter Your OTP",
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                setState(() {
                                  _errorMessage = 'Please enter the OTP';
                                });
                                return '';
                              }
                              if (value.length != 6) {
                                setState(() {
                                  _errorMessage = 'OTP must be 6 digits';
                                });
                                return '';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      // Display the error message separately
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      const SizedBox(height: 50),
                      GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          HapticFeedback.heavyImpact();
                          verifyOtp();
                        },
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 50,
                            width: 100,
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10)),
                            child: Center(
                              child: Text(
                                "CONFIRM",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Center(child: Lottie.asset("assets/lottie/loading.json")),
        ],
      ),
    );
  }
}
