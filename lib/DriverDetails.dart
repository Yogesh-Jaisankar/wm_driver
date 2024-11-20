import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:toastification/toastification.dart';

import 'logo.dart';

class DriverDetails extends StatefulWidget {
  final String phoneNumber;
  const DriverDetails({super.key, required this.phoneNumber});

  @override
  State<DriverDetails> createState() => _DriverDetailsState();
}

class _DriverDetailsState extends State<DriverDetails> {
  final TextEditingController resnameController = TextEditingController();
  final FocusNode _ResNameFocusNode = FocusNode();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Request focus to open the keyboard
    Future.delayed(Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(_ResNameFocusNode);
    });
  }

  Future<void> storeUserData() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    var db = await mongo.Db.create(
        "mongodb+srv://wm:7806@wm.4lglk.mongodb.net/Drivers?retryWrites=true&w=majority&appName=wm");
    await db.open();
    var collection = db.collection('driver');

    var existingUser = await collection.findOne({"_id": widget.phoneNumber});

    if (existingUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Restaurant with this phone number already exists!')),
      );
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    } else {
      var userData = {
        "_id": widget.phoneNumber,
        "name": resnameController.text,
      };

      var result = await collection.insertOne(userData);

      setState(() {
        isLoading = false; // Hide loading indicator
      });

      if (result.isSuccess) {
        toastification.show(
          alignment: Alignment.bottomCenter,
          context: context,
          title: Text('Restaurant name saved successfully!'),
          type: ToastificationType.success,
          style: ToastificationStyle.flatColored,
          showProgressBar: false,
          autoCloseDuration: const Duration(seconds: 2),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => Logo(userid: widget.phoneNumber)),
          (Route<dynamic> route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user details!')),
        );
      }
    }

    await db.close();
  }

  bool validateInputs() {
    if (resnameController.text.isEmpty) {
      toastification.show(
        alignment: Alignment.topLeft,
        context: context,
        title: Text('Enter Restaurant name to continue...'),
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        showProgressBar: false,
        autoCloseDuration: const Duration(seconds: 2),
      );
      return false;
    }
    return true;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Text(
                "Your name to beregistered?",
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Raleway",
                    fontSize: 20),
              ),
              SizedBox(height: 30),
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
                    controller: resnameController,
                    focusNode: _ResNameFocusNode,
                    cursorColor: Colors.black87,
                    decoration: InputDecoration(
                      hintText: "Enter Your Name",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () async {
                    FocusScope.of(context).unfocus();
                    if (validateInputs()) {
                      await storeUserData();
                    }
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
                          "CONTINUE",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isLoading)
                Center(
                  child: Lottie.asset(
                    'assets/lottie/loading.json', // Path to your Lottie file
                    width: 200,
                    height: 200,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
