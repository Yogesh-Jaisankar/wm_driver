import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Home.dart';
import 'PhoneAuth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          // Show a loading indicator while checking the status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else {
            // Navigate to the appropriate screen
            if (snapshot.data?['isLoggedIn'] == true) {
              return Home(); // Pass phone number to Home
            } else {
              return PhoneInputPage(); // User needs to log in
            }
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn =
        prefs.getBool('isLoggedIn') ?? false; // Default to false if not set
    String? phoneNumber =
        prefs.getString('phoneNumber'); // Retrieve phone number
    return {
      'isLoggedIn': isLoggedIn,
      'phoneNumber': phoneNumber
    }; // Return both values
  }
}
