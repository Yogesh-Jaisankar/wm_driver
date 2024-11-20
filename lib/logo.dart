import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator package
import 'package:image_picker/image_picker.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:toastification/toastification.dart';

import 'Email.dart';

class Logo extends StatefulWidget {
  final String userid;
  const Logo({super.key, required this.userid});

  @override
  State<Logo> createState() => _LogoState();
}

class _LogoState extends State<Logo> {
  File? _selectedImage;
  bool _isDbOpen = false;
  bool _isUploading = false; // Track the upload state
  late mongo.Db db;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _initializeDb();
  }

  // Initialize MongoDB connection
  Future<void> _initializeDb() async {
    try {
      db = await mongo.Db.create(
          "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");
      await db.open();
      setState(() {
        _isDbOpen = true;
      });
    } catch (e) {
      print('Database connection error: $e');
    }
  }

  // Select image from gallery
  Future<void> _selectImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Image selection error: $e');
    }
  }

  // Fetch current location (latitude and longitude)
  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      toastification.show(
        alignment: Alignment.bottomCenter,
        context: context,
        title: const Text('Location services are disabled.'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        toastification.show(
          alignment: Alignment.bottomCenter,
          context: context,
          title: const Text('Location permission denied.'),
          type: ToastificationType.warning,
          style: ToastificationStyle.flatColored,
          showProgressBar: false,
          autoCloseDuration: const Duration(seconds: 2),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      toastification.show(
        alignment: Alignment.bottomCenter,
        context: context,
        title: const Text('Location permission denied forever.'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    // Get current position (latitude and longitude)
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    toastification.show(
      alignment: Alignment.bottomCenter,
      context: context,
      title: const Text('Location fetched successfully.'),
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      showProgressBar: false,
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  // Upload selected image and location to MongoDB
  Future<void> _uploadImageAndLocation() async {
    if (_selectedImage == null) {
      toastification.show(
        alignment: Alignment.bottomCenter,
        context: context,
        title: const Text('Please select an image first.'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      toastification.show(
        alignment: Alignment.bottomCenter,
        context: context,
        title: const Text('Please allow location access.'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    if (!_isDbOpen) {
      print("Database is not open.");
      return;
    }

    setState(() {
      _isUploading = true; // Start uploading
    });

    try {
      // Get the image in base64
      final imageBytes = await _selectedImage!.readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      // Get MongoDB collection
      final collection = db.collection('driver');

      // Update the document with image, latitude, and longitude
      final updateResult = await collection.updateOne(
          mongo.where.eq('_id', widget.userid),
          mongo.modify
            ..set('logo', imageBase64)
            ..set('latitude', _latitude)
            ..set('longitude', _longitude)
            ..set('status', "Available"));

      if (updateResult.isSuccess) {
        toastification.show(
          alignment: Alignment.bottomCenter,
          context: context,
          title: const Text('Image and Location uploaded successfully!'),
          type: ToastificationType.success,
          style: ToastificationStyle.flatColored,
          showProgressBar: false,
          autoCloseDuration: const Duration(seconds: 2),
        );

        // Navigate to next page after successful upload
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpEmailPage(userid: widget.userid),
          ),
        );
      } else {
        print(
            'No document found with the specified ID or nothing was updated.');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isUploading = false; // Stop uploading
      });
      await db.close();
      setState(() {
        _isDbOpen = false;
      });
    }
  }

  @override
  void dispose() {
    if (_isDbOpen) {
      db.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 30),
                Text(
                  "Upload your Photo",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Raleway",
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  width: 150,
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _selectedImage == null
                        ? Image.asset(
                            "assets/icons/grey.jpeg",
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                SizedBox(height: 30),
                GestureDetector(
                  onTap: _selectImage,
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
                          "Select Image",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Raleway",
                              fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                GestureDetector(
                  onTap: _getLocation, // Call location function
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
                          "Allow Location",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Raleway",
                              fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                _isUploading // Show loading indicator while uploading
                    ? CircularProgressIndicator()
                    : GestureDetector(
                        onTap: _uploadImageAndLocation,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Center(
                              child: Text(
                                "Upload and Continue",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: "Raleway",
                                    fontSize: 18),
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
    );
  }
}
