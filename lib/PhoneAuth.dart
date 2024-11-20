import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:otpless_flutter/otpless_flutter.dart';
import 'package:toastification/toastification.dart';

import 'Otp.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({Key? key}) : super(key: key);

  @override
  _PhoneInputPageState createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController phoneController = TextEditingController();
  final _otplessFlutterPlugin = Otpless();
  bool isInitIos = false;
  bool isLoading = false; // Loading state
  static const String appId = "H36KQYXL24MCA0LISYA9";

  final FocusNode _phoneFocusNode = FocusNode(); // Create a FocusNode

  @override
  void initState() {
    super.initState();
    startTimer();
    if (Platform.isAndroid) {
      _otplessFlutterPlugin.initHeadless(appId);
      _otplessFlutterPlugin.setHeadlessCallback(onHeadlessResult);
      debugPrint("init headless sdk is called for android");
    }

    // Request focus to open the keyboard
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  void onHeadlessResult(dynamic result) {
    setState(() {
      isLoading = false; // Stop loading once result is received
    });
    debugPrint("Phone auth response: $result");
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => OtpInputPage(
          phoneNumber: phoneController.text,
          countryCode: '+91',
        ),
      ),
    );
  }

  Future<void> startPhoneAuth() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Check if phone number is exactly 10 digits
    if (phoneController.text.length != 10) {
      toastification.show(
        alignment: Alignment.topLeft,
        context: context,
        title: Text('Please enter a valid phone number'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return; // Stop execution if validation fails
    }

    // Start showing loading indicator
    setState(() {
      isLoading = true;
    });

    try {
      if (Platform.isIOS && !isInitIos) {
        _otplessFlutterPlugin.initHeadless(appId);
        _otplessFlutterPlugin.setHeadlessCallback(onHeadlessResult);
        isInitIos = true;
      }

      Map<String, dynamic> arg = {
        "phone": phoneController.text,
        "countryCode": "91", // Change country code as required
      };

      // Start phone authentication
      await _otplessFlutterPlugin.startHeadless(onHeadlessResult, arg);
    } catch (e) {
      debugPrint("Error in phone authentication: $e");
      setState(() {
        isLoading = false; // Stop loading if error occurs
      });
    }
  }

  Timer? timer; // Declare timer variable
  int currentIndex = 0; // Current index for cycling texts
  List<String> texts = [
    "Hello!!",
    "வணக்கம்!!",
    "नमस्ते!!",
    "నమస్కారం!!",
    "ഹലോ!!",
    "ನಮಸ್ಕಾರ"
  ];

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 2), (Timer t) {
      setState(() {
        currentIndex = (currentIndex + 1) % texts.length; // Cycle through texts
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _phoneFocusNode.dispose(); // Dispose of the FocusNode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                Container(
                  height: 100,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      texts[currentIndex],
                      style: TextStyle(fontSize: 40, fontFamily: "Raleway"),
                    ),
                  ),
                ),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black87, width: .5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextFormField(
                      style: TextStyle(fontWeight: FontWeight.bold),
                      maxLength: 10,
                      maxLines: 1,
                      cursorColor: Colors.black87,
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      focusNode: _phoneFocusNode, // Set the FocusNode
                      decoration: InputDecoration(
                          hintText: "Phone Number",
                          border: InputBorder.none,
                          counterText: ""),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: "Read our ",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: "Raleway",
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: "Privacy and Policy",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Raleway",
                          color: Colors.black,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _loadContent('assets/privacy_policy.txt')
                                .then((content) {
                              _showDialog(
                                  context, "Privacy and Policy", content);
                            });
                          },
                      ),
                      TextSpan(
                        text: " and Tap Agree and continue to accept our ",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: "Raleway",
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: "Terms and Conditions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: "Raleway",
                          color: Colors.black,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _loadContent('assets/tc.txt').then((content) {
                              _showDialog(
                                  context, "Terms and Conditions", content);
                            });
                          },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                isLoading
                    ? Container(
                        child: Center(
                            child: Lottie.asset("assets/lottie/loading.json")),
                      ) // Show loading indicator
                    : Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors
                              .black, // Set the background color to black
                          borderRadius: BorderRadius.circular(
                              8.0), // Optional: Adjust the border radius
                        ),
                        child: CupertinoButton(
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            startPhoneAuth();
                          },
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 10.0),
                          child: const Text(
                            "Agree and Continue",
                            style: TextStyle(
                                fontFamily: "Raleway",
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors
                                    .white), // Text color set to white
                          ),
                          color: Colors
                              .transparent, // Make button itself transparent, color is handled by Container
                        ),
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<String> _loadContent(String path) async {
  return await rootBundle.loadString(path);
}

void _showDialog(BuildContext context, String title, String content) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: "Raleway",
          ),
        ),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text(
              "Close",
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      );
    },
  );
}
