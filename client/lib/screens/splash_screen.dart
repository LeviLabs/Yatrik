import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'MyHomePage.dart';
import 'intro_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 👇 This forces Flutter to draw the UI FIRST, then start the timer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeUser();
    });
  }

  Future<void> _routeUser() async {
    // ⏳ Guaranteed 2.5 second wait time
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const MyHomePage(title: 'Yatrik')),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                IntroPage()), // or const IntroPage() if it requires it
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF9),
      body: Center(
        child: Image.asset(
          'assets/images/Yatrik_logo.png', // Make sure this perfectly matches your file name!
          width: 220,
          color: Colors.black,
        ),
      ),
    );
  }
}
