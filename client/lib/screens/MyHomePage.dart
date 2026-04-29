import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// 👇 1. Mapbox & Location Imports 👇
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'home_bottom_sheet.dart';
import 'profile_page.dart';
import 'import_from_friends_sheet.dart';
import 'saved_trips_sheet.dart';
import 'package:trip_planner/trip_decision_screen/phase1.dart';

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // ── 1. State variable for the plus menu ──
  bool _isMenuOpen = false;

  // 👇 2. Mapbox State Variables 👇
  MapboxMap? mapboxMap;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _openSavedTripsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.15),
      useSafeArea: true,
      builder: (context) => const SavedTripsSheet(),
    );
  }

  // 👇 3. Cinematic Intro Animation 👇
  Future<void> _cinematicMapIntro() async {
    // Phase 1: Swoop down from space to show all of India
    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(78.9629, 20.5937)), // India Center
        zoom: 4.5, // Perfect zoom for the whole country
      ),
      MapAnimationOptions(
        duration: 3000, // Smooth 3-second flight
        startDelay: 300,
      ),
    );

    // I COMMENTED THESE OUT SO IT STAYS IN INDIA!
    // await Future.delayed(const Duration(milliseconds: 3500));
    // _locateUserAndMoveMap();
  }

  // 👇 4. Location Function 👇
  Future<void> _locateUserAndMoveMap() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) return;
    }
    if (permission == geo.LocationPermission.deniedForever) return;

    geo.Position userPos = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    // Phase 3: Smoothly fly to the user's specific location
    mapboxMap?.flyTo(
      CameraOptions(
        center:
            Point(coordinates: Position(userPos.longitude, userPos.latitude)),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 2500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EDD8),
        body: Stack(
          children: [
            // 👇 5. REPLACED COLORED BOX WITH MAPBOX 👇
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey("mapWidget"),
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(78.9629, 20.5937)),
                  // Start completely zoomed out so there are no empty spots!
                  zoom: 0.0,
                ),
                styleUri: MapboxStyles.OUTDOORS,
                onMapCreated: (MapboxMap map) {
                  mapboxMap = map;

                  // Hide the Top Compass
                  mapboxMap?.compass
                      .updateSettings(CompassSettings(enabled: false));

                  // Hide the Black Scale Bar
                  mapboxMap?.scaleBar
                      .updateSettings(ScaleBarSettings(enabled: false));

                  // TRIGGER THE CINEMATIC FLY-IN!
                  _cinematicMapIntro();
                },
              ),
            ),
            // ── Dynamic Island overlay buttons ───────────────────────────────
            Positioned(
              top: topPadding + 8,
              right: 16,
              child: _DynamicIslandButtons(),
            ),

            // ── Bottom sheet (draggable) ───────────────────────
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.22,
              minChildSize: 0.22,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.22, 0.5, 0.85],
              builder: (context, scrollController) {
                return HomeBottomSheet(
                  scrollController: scrollController,
                  onBack: () => _sheetController.animateTo(
                    0.22,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  ),
                );
              },
            ),

            // ── Transparent overlay to dismiss menu when tapping outside ──
            if (_isMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleMenu,
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // ── THE NEW BOTTOM BLUR & DARK FADE ────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 320,
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  opacity: _isMenuOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.0, 0.3],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.25),
                                Colors.black.withOpacity(0.4),
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── The new popup menu ─────────────────────────────────────────
            Positioned(
              bottom: bottomPadding + 106,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isMenuOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedSlide(
                    offset: _isMenuOpen ? Offset.zero : const Offset(0, 0.1),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutQuart,
                    child: IgnorePointer(
                      ignoring: !_isMenuOpen,
                      // 👇 6. PASSED THE TOGGLE FUNCTION HERE 👇
                      child: _PlusMenuOptions(onClose: _toggleMenu),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating Glass Bottom Navigation Bar ──────────────────────────
            Positioned(
              bottom: bottomPadding + 14,
              left: 0,
              right: 0,
              child: Center(
                child: _FloatingGlassCapsuleNavBar(
                  isMenuOpen: _isMenuOpen,
                  onPlusTap: _toggleMenu,
                  onSavedTap: _openSavedTripsSheet,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The new Plus Menu Options Widget (Only Images, No Fallbacks)
// ─────────────────────────────────────────────────────────────────────────────
class _PlusMenuOptions extends StatelessWidget {
  // 👇 7. ADDED THE onClose PARAMETER 👇
  final VoidCallback onClose;

  const _PlusMenuOptions({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E6E5).withOpacity(1.0),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Option 1: Create New Trip ──
                _buildOption(
                  imagePath: 'assets/images/luggage.png',
                  title: 'Create New Trip',
                  subtitle: 'Plan your next adventure',
                  onTap: () {
                    // 👇 8. CALL THE CLOSE FUNCTION BEFORE OPENING THE SHEET 👇
                    onClose();

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withOpacity(0.6),
                      useSafeArea: true,
                      builder: (context) => const Phase1Screen(),
                    );
                  },
                ),
                const SizedBox(height: 10),
                // ── Option 2: Import From Friends ──
                _buildOption(
                  imagePath: 'assets/images/map_pin.png',
                  title: 'Import From Friends',
                  subtitle: 'Enter a friend code to import trip',
                  onTap: () {
                    onClose();

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black.withOpacity(0.6),
                      useSafeArea: true,
                      builder: (context) => ImportFromFriendsSheet(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String imagePath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Image.asset(
                imagePath,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dynamic Island — EXACT SIZING FOR SCREENSHOT (Ultra-slim)
// ─────────────────────────────────────────────────────────────────────────────
class _DynamicIslandButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar button
        GestureDetector(
          onTap: () {
            ProfilePage.show(context);
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: ClipOval(
              child: Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  final String? photoUrl = user?.photoURL;
                  final String name = user?.displayName ?? "User";

                  return Image.network(
                    photoUrl ??
                        'https://ui-avatars.com/api/?name=${name.replaceAll(" ", "+")}&background=random',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, color: Colors.grey, size: 24),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Glass Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingGlassCapsuleNavBar extends StatelessWidget {
  final VoidCallback onPlusTap;
  final VoidCallback onSavedTap;
  final bool isMenuOpen;

  const _FloatingGlassCapsuleNavBar({
    required this.onPlusTap,
    required this.onSavedTap,
    required this.isMenuOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.cases_outlined,
                        size: 28, color: Colors.black45),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onPlusTap,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFF222222),
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedRotation(
                      turns: isMenuOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onSavedTap,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.bookmark,
                        size: 28, color: Color(0xFF1E88E5)),
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
