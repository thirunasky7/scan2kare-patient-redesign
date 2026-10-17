import 'package:flutter/material.dart';
import '../utils/auth_nav.dart';
import 'onboarding_content.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _onboardingPages = [
    OnboardingContent(
      title: "Don't waste your time.",
      description: "",
      imagePath:
          'https://scan2kare.com/public/assets/images/defaultt-icons.png', // Add your image
      color: Colors.blueAccent,
    ),
    OnboardingContent(
      title: "Make a Scan, doctor",
      description:
          "Use our scan feature to quickly find available doctors and specialists.",
      imagePath: 'assets/images/scan.png', // Add your image
      color: Colors.greenAccent,
    ),
    OnboardingContent(
      title: "Appointments",
      description:
          "Manage all your medical appointments in one place with reminders and notifications.",
      imagePath: 'assets/images/appointment.png', // Add your image
      color: Colors.purpleAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button (Top Right)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () {
                    _goToLoginScreen();
                  },
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: _onboardingPages[_currentPage].color,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingPages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildPageContent(_onboardingPages[index]);
                },
              ),
            ),

            // Page Indicators and Next Button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      _onboardingPages.length,
                      (index) => _buildPageIndicator(index),
                    ),
                  ),

                  // Next/Get Started Button
                  FloatingActionButton(
                    backgroundColor: _onboardingPages[_currentPage].color,
                    onPressed: () {
                      if (_currentPage < _onboardingPages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _goToLoginScreen();
                      }
                    },
                    child: Icon(
                      _currentPage == _onboardingPages.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingContent content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image Placeholder (Replace with actual images)
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: content.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services,
              size: 120,
              color: content.color,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            content.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            content.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index
            ? _onboardingPages[_currentPage].color
            : Colors.grey[300],
      ),
    );
  }

  void _goToLoginScreen() {
    goToLogin();
  }
}
