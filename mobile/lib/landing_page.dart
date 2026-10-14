import 'dart:ui';
import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/material.dart';
import 'package:mtaaworks/sign_up_page.dart';

import 'login_page.dart';

// Changed to StatefulWidget to allow state changes
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // Moved state variable outside the build method so it persists
  int _currentIndex = 0;

  final List<String> images = [
    'images/image1.jpg',
    'images/image2.jpeg',
    'images/image3.jpg',
    'images/image4.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 35),
              Text(
                'Get Started!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Instant Credit Insights \n in Your Pocket.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.045,
                  color: Colors.grey,
                  height: 1.3,
                ),
              ),

              Expanded(
                child: Center(
                  child: CarouselSlider(
                    options: CarouselOptions(
                      height: 300.0,
                      autoPlay: true,
                      enlargeCenterPage: true,
                      aspectRatio: 16 / 9,
                      viewportFraction: 1,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
                    items: images.map((imagePath) {
                      return Builder(
                        builder: (BuildContext context) {
                          return Image.asset(
                            imagePath,
                            width: 300,
                            fit: BoxFit.contain,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: images.asMap().entries.map((entry) {
                  int index = entry.key;
                  return _buildDot(isActive: _currentIndex == index);
                }).toList(),
              ),

              const SizedBox(height: 48),

              // Sign Up button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context)=>SignUpPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Sign Up'),
                ),
              ),

              const SizedBox(height: 12),

              // Log In button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context)=>LoginPage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(
                      color: Colors.black,
                      width: 1,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Log In'),
                ),
              ),

              const SizedBox(height: 30),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot({bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 20 : 9,
      height: 9,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF8B35F0) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
