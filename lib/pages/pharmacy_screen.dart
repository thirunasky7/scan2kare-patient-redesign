import 'package:flutter/material.dart';
import '../widgets/common_drawer.dart';

class PharmacyScreen extends StatelessWidget {
  const PharmacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CommonDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pharmacy"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                "https://scan2kare.com/public/app-images/hospital-default.png",
                width: 80,
                height: 80,
                fit: BoxFit.cover, // or BoxFit.contain
              ),
              const SizedBox(height: 20),
              const Text(
                "Coming Soon",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // Subtitle
              Text(
                "Pharmacy feature will be available soon.\nStay tuned!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 30),

              // Back Button
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Go Back"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
