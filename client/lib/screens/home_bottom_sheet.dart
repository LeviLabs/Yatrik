import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Extracted Bottom Sheet Content
// ─────────────────────────────────────────────────────────────────────────────
class HomeBottomSheet extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onBack;

  // For updating map from parent screen
  final ValueChanged<Map<String, dynamic>>? onTripSelected;
  final VoidCallback? onTripClosed;

  const HomeBottomSheet({
    super.key,
    required this.scrollController,
    required this.onBack,
    this.onTripSelected,
    this.onTripClosed,
  });

  @override
  State<HomeBottomSheet> createState() => _HomeBottomSheetState();
}

class _HomeBottomSheetState extends State<HomeBottomSheet> {
  Map<String, dynamic>? selectedTrip;

  void _openTrip(Map<String, dynamic> trip) {
    setState(() {
      selectedTrip = trip;
    });

    widget.onTripSelected?.call(trip);

    Future.delayed(const Duration(milliseconds: 80), () {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _closeTrip() {
    setState(() {
      selectedTrip = null;
    });

    widget.onTripClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? 'Welcome Traveler';

    String formattedName = displayName;
    if (displayName.contains(' ')) {
      List<String> nameParts = displayName.split(' ');
      formattedName = '${nameParts[0]}\n${nameParts.sublist(1).join(' ')}!';
    } else {
      formattedName = '$displayName!';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: user == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('trips')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          final List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocs =
              snapshot.data?.docs ?? [];

          final bool hasTrips = tripDocs.isNotEmpty;

          int totalSavedSpots = 0;

          for (final doc in tripDocs) {
            final data = doc.data();
            final value = data['totalSpots'];

            if (value is int) {
              totalSavedSpots += value;
            } else if (value is num) {
              totalSavedSpots += value.toInt();
            } else {
              totalSavedSpots += int.tryParse(value?.toString() ?? '0') ?? 0;
            }
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: selectedTrip != null
                ? _TripDetailSamePage(
                    key: const ValueKey('trip_detail'),
                    scrollController: widget.scrollController,
                    trip: selectedTrip!,
                    onBack: _closeTrip,
                  )
                : CustomScrollView(
                    key: const ValueKey('trip_list'),
                    controller: widget.scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 12, bottom: 20),
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: hasTrips
                                  ? _buildTripsContent(
                                      tripDocs: tripDocs,
                                      totalSavedSpots: totalSavedSpots,
                                    )
                                  : _buildEmptyContent(
                                      formattedName: formattedName,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyContent({
    required String formattedName,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome,\n$formattedName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_walk_outlined,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Import Guide',
                    style: TextStyle(
                      color: Color(0xFFF57C00),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Center(
          child: SizedBox(
            height: 220,
            child: Image.asset(
              'assets/images/globe.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F9FF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFBCE0FD),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.lightBlue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: Colors.blue.shade500,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Import your First Spots',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 140),
      ],
    );
  }

  Widget _buildTripsContent({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tripDocs,
    required int totalSavedSpots,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Spots',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.8,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalSavedSpots Spots Saved',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.signpost_outlined,
                    color: Colors.orange.shade700,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Import Guide',
                    style: TextStyle(
                      color: Color(0xFFF57C00),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 46),
        ...tripDocs.map((doc) {
          final trip = doc.data();
          return _TripPlanSection(
            trip: trip,
            onTap: () => _openTrip(trip),
          );
        }),
        const SizedBox(height: 140),
      ],
    );
  }
}

class _TripPlanSection extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  const _TripPlanSection({
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String placeName = (trip['placeName'] ?? 'Trip').toString();
    final List<_SavedSpotPreview> spots = _TripDataHelper.spotsFromTrip(trip);
    final int totalSpots = _TripDataHelper.toInt(trip['totalSpots']);
    final int shownSpotCount = totalSpots > 0 ? totalSpots : spots.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 42),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '$shownSpotCount Spot${shownSpotCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            if (spots.isEmpty)
              Container(
                height: 166,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const _SavedTripFallbackIcon(),
              )
            else
              SizedBox(
                height: 246,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: spots.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 22),
                  itemBuilder: (context, index) {
                    return _SavedSpotCard(spot: spots[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Same Page Trip Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class _TripDetailSamePage extends StatefulWidget {
  final ScrollController scrollController;
  final Map<String, dynamic> trip;
  final VoidCallback onBack;

  const _TripDetailSamePage({
    super.key,
    required this.scrollController,
    required this.trip,
    required this.onBack,
  });

  @override
  State<_TripDetailSamePage> createState() => _TripDetailSamePageState();
}

class _TripDetailSamePageState extends State<_TripDetailSamePage> {
  int selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String placeName = (widget.trip['placeName'] ?? 'Trip').toString();
    final int totalDays = _TripDataHelper.totalDays(widget.trip);
    final int totalSpots = _TripDataHelper.totalSpots(widget.trip);
    final List<_SavedSpotPreview> allSpots =
        _TripDataHelper.spotsFromTrip(widget.trip);
    final String coverImage =
        allSpots.isNotEmpty ? allSpots.first.imageUrl : '';

    final List<int> dayNumbers = _TripDataHelper.dayNumbers(widget.trip);

    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 18),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Map now changes when Overview / Day tab changes.
                _TripMapInsideBottomSheet(
                  key: ValueKey('trip_map_$selectedTabIndex'),
                  trip: widget.trip,
                  selectedDayNumber:
                      selectedTabIndex == 0 ? null : selectedTabIndex,
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 124,
                          height: 124,
                          color: const Color(0xFFF1F1F3),
                          child: coverImage.isNotEmpty
                              ? Image.network(
                                  coverImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const _SavedTripFallbackIcon();
                                  },
                                  loadingBuilder: (_, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const _SavedTripFallbackIcon();
                                  },
                                )
                              : const _SavedTripFallbackIcon(),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalDays-Day\n$placeName,\nIndia Trip',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$totalDays days • $totalSpots spots',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: widget.onBack,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.black54,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      _GoogleAvatarCircle(),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 26,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  height: 58,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    children: [
                      _DetailTabButton(
                        isSelected: selectedTabIndex == 0,
                        icon: Icons.map_outlined,
                        text: 'Overview',
                        onTap: () {
                          setState(() {
                            selectedTabIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(width: 14),
                      ...dayNumbers.map((dayNumber) {
                        final int index = dayNumber;
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _DetailTabButton(
                            isSelected: selectedTabIndex == index,
                            text: 'Day $dayNumber',
                            onTap: () {
                              setState(() {
                                selectedTabIndex = index;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (selectedTabIndex == 0)
                  _OverviewContent(
                    trip: widget.trip,
                    dayNumbers: dayNumbers,
                  )
                else
                  _SingleDayContent(
                    trip: widget.trip,
                    dayNumber: selectedTabIndex,
                    placeName: placeName,
                  ),

                const SizedBox(height: 140),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Inside Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TripMapInsideBottomSheet extends StatelessWidget {
  final Map<String, dynamic> trip;
  final int? selectedDayNumber;

  const _TripMapInsideBottomSheet({
    super.key,
    required this.trip,
    this.selectedDayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final List<LatLng> points = _TripDataHelper.pointsFromTrip(
      trip,
      selectedDayNumber: selectedDayNumber,
    );

    final LatLng center = _TripDataHelper.centerOfPoints(points);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 260,
          width: double.infinity,
          color: const Color(0xFFF1F1F3),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: _TripDataHelper.zoomForPoints(points),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trip_planner',
              ),
              if (points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 4,
                      color: selectedDayNumber == null
                          ? Colors.deepPurpleAccent
                          : const Color(0xFF20A8FF),
                    ),
                  ],
                ),
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: List.generate(points.length, (index) {
                    return Marker(
                      point: points[index],
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF20A8FF),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF20A8FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTabButton extends StatelessWidget {
  final bool isSelected;
  final String text;
  final IconData? icon;
  final VoidCallback onTap;

  const _DetailTabButton({
    required this.isSelected,
    required this.text,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF202020) : const Color(0xFFF3F3F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 9),
            ],
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade500,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  final Map<String, dynamic> trip;
  final List<int> dayNumbers;

  const _OverviewContent({
    required this.trip,
    required this.dayNumbers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: dayNumbers.map((dayNumber) {
        final spots = _TripDataHelper.spotsForDay(trip, dayNumber);

        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: _DayOverviewCard(
            dayNumber: dayNumber,
            spots: spots,
          ),
        );
      }).toList(),
    );
  }
}

class _DayOverviewCard extends StatelessWidget {
  final int dayNumber;
  final List<_SavedSpotPreview> spots;

  const _DayOverviewCard({
    required this.dayNumber,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    final String distanceText = _TripDataHelper.dayDistanceText(spots);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFEAEAEA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF20A8FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Day $dayNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '$distanceText • ${spots.length} spots',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (spots.isEmpty)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const _SavedTripFallbackIcon(),
            )
          else
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: spots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final spot = spots[index];

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 76,
                      height: 76,
                      color: const Color(0xFFF1F1F3),
                      child: spot.imageUrl.isNotEmpty
                          ? Image.network(
                              spot.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const _SavedTripFallbackIcon();
                              },
                            )
                          : const _SavedTripFallbackIcon(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleDayContent extends StatelessWidget {
  final Map<String, dynamic> trip;
  final int dayNumber;
  final String placeName;

  const _SingleDayContent({
    required this.trip,
    required this.dayNumber,
    required this.placeName,
  });

  @override
  Widget build(BuildContext context) {
    final spots = _TripDataHelper.spotsForDay(trip, dayNumber);
    final String distanceText = _TripDataHelper.dayDistanceText(spots);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                placeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Text(
              '$distanceText • ${spots.length} spots',
              style: TextStyle(
                fontSize: 17,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (spots.isEmpty)
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'No spots found for this day',
                style: TextStyle(
                  color: Colors.black45,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          ...List.generate(spots.length, (index) {
            final spot = spots[index];

            return Column(
              children: [
                _DaySpotTimelineCard(
                  spot: spot,
                  index: index,
                ),
                if (index < spots.length - 1)
                  _TravelBetweenSavedSpots(
                    from: spots[index],
                    to: spots[index + 1],
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _DaySpotTimelineCard extends StatelessWidget {
  final _SavedSpotPreview spot;
  final int index;

  const _DaySpotTimelineCard({
    required this.spot,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xFFE7F6FF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFEDEDEF),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: const Color(0xFFF1F1F3),
                    child: spot.imageUrl.isNotEmpty
                        ? Image.network(
                            spot.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const _SavedTripFallbackIcon();
                            },
                          )
                        : const _SavedTripFallbackIcon(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        '✨',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          spot.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TravelBetweenSavedSpots extends StatelessWidget {
  final _SavedSpotPreview from;
  final _SavedSpotPreview to;

  const _TravelBetweenSavedSpots({
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final double? distanceKm = _TripDataHelper.distanceKmBetween(from, to);
    final String distanceText = _TripDataHelper.formatDistance(distanceKm);
    final String timeText = _TripDataHelper.estimateTravelTime(distanceKm);

    return Padding(
      padding: const EdgeInsets.only(left: 64, top: 10, bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Color(0xFF12A8FF),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '$timeText • $distanceText',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFF12A8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Spot Card
// ─────────────────────────────────────────────────────────────────────────────
class _SavedSpotCard extends StatelessWidget {
  final _SavedSpotPreview spot;

  const _SavedSpotCard({
    required this.spot,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 172,
              width: 236,
              color: const Color(0xFFF1F1F3),
              child: spot.imageUrl.isNotEmpty
                  ? Image.network(
                      spot.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _SavedTripFallbackIcon();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return const _SavedTripFallbackIcon();
                      },
                    )
                  : const _SavedTripFallbackIcon(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            spot.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              height: 1.08,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleAvatarCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL ?? '';
    final displayName = user?.displayName ?? user?.email ?? 'User';
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim().characters.first.toUpperCase()
        : 'U';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF2ECC71),
          width: 3,
        ),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _AvatarFallback(initial: initial);
                },
              )
            : _AvatarFallback(initial: initial),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initial;

  const _AvatarFallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF7D8F99),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SavedSpotPreview {
  final String name;
  final String imageUrl;
  final double? lat;
  final double? lng;

  const _SavedSpotPreview({
    required this.name,
    required this.imageUrl,
    this.lat,
    this.lng,
  });
}

class _SavedTripFallbackIcon extends StatelessWidget {
  const _SavedTripFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.place_outlined,
        color: Color(0xFF9A9A9F),
        size: 36,
      ),
    );
  }
}

class _TripDataHelper {
  static int totalDays(Map<String, dynamic> trip) {
    final days = trip['days'];
    if (days is Map && days.isNotEmpty) return days.length;

    final value = trip['totalDays'];
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '1') ?? 1;
  }

  static int totalSpots(Map<String, dynamic> trip) {
    final value = trip['totalSpots'];

    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();

    return spotsFromTrip(trip).length;
  }

  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static List<int> dayNumbers(Map<String, dynamic> trip) {
    final days = trip['days'];

    if (days is! Map || days.isEmpty) return [1];

    final dayNumbers = <int>[];

    for (final key in days.keys) {
      final String rawKey = key.toString();
      final String cleaned = rawKey.replaceAll(RegExp(r'[^0-9]'), '');
      final int? number = int.tryParse(cleaned);

      if (number != null) {
        dayNumbers.add(number);
      }
    }

    dayNumbers.sort();

    if (dayNumbers.isEmpty) return [1];

    return dayNumbers;
  }

  static List<_SavedSpotPreview> spotsFromTrip(Map<String, dynamic> trip) {
    final days = trip['days'];
    final spotsList = <_SavedSpotPreview>[];

    if (days is! Map) return spotsList;

    final sortedDayNumbers = dayNumbers(trip);

    for (final dayNumber in sortedDayNumbers) {
      spotsList.addAll(spotsForDay(trip, dayNumber));
    }

    return spotsList;
  }

  static List<_SavedSpotPreview> spotsForDay(
    Map<String, dynamic> trip,
    int dayNumber,
  ) {
    final days = trip['days'];
    final spotsList = <_SavedSpotPreview>[];

    if (days is! Map) return spotsList;

    dynamic dayValue;

    if (days['day$dayNumber'] != null) {
      dayValue = days['day$dayNumber'];
    } else if (days['day_$dayNumber'] != null) {
      dayValue = days['day_$dayNumber'];
    } else if (days['Day $dayNumber'] != null) {
      dayValue = days['Day $dayNumber'];
    } else if (days[dayNumber.toString()] != null) {
      dayValue = days[dayNumber.toString()];
    } else {
      for (final entry in days.entries) {
        final key = entry.key.toString();
        final cleaned = key.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned == dayNumber.toString()) {
          dayValue = entry.value;
          break;
        }
      }
    }

    if (dayValue is! Map) return spotsList;

    final spots = dayValue['spots'];
    if (spots is! Map) return spotsList;

    final spotEntries = spots.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

    for (final spotEntry in spotEntries) {
      final spotValue = spotEntry.value;

      if (spotValue is! Map) continue;

      spotsList.add(
        _SavedSpotPreview(
          name: (spotValue['name'] ?? 'Spot').toString(),
          imageUrl: (spotValue['imageUrl'] ?? '').toString(),
          lat: toDouble(
            spotValue['lat'] ?? spotValue['latitude'] ?? spotValue['Lat'],
          ),
          lng: toDouble(
            spotValue['lng'] ??
                spotValue['longitude'] ??
                spotValue['Lng'] ??
                spotValue['lon'],
          ),
        ),
      );
    }

    return spotsList;
  }

  static List<LatLng> pointsFromTrip(
    Map<String, dynamic> trip, {
    int? selectedDayNumber,
  }) {
    if (selectedDayNumber != null) {
      return spotsForDay(trip, selectedDayNumber)
          .where((spot) => spot.lat != null && spot.lng != null)
          .map((spot) => LatLng(spot.lat!, spot.lng!))
          .toList();
    }

    return spotsFromTrip(trip)
        .where((spot) => spot.lat != null && spot.lng != null)
        .map((spot) => LatLng(spot.lat!, spot.lng!))
        .toList();
  }

  static LatLng centerOfPoints(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(21.2514, 81.6296);
    }

    double lat = 0;
    double lng = 0;

    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }

    return LatLng(lat / points.length, lng / points.length);
  }

  static double zoomForPoints(List<LatLng> points) {
    if (points.length <= 1) return 10.5;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);

    if (maxDiff > 2.0) return 6.5;
    if (maxDiff > 1.0) return 7.5;
    if (maxDiff > 0.5) return 8.5;
    if (maxDiff > 0.2) return 9.5;
    if (maxDiff > 0.08) return 10.5;

    return 12.0;
  }

  static String dayDistanceText(List<_SavedSpotPreview> spots) {
    double totalKm = 0;

    for (int i = 0; i < spots.length - 1; i++) {
      final distance = distanceKmBetween(spots[i], spots[i + 1]);

      if (distance != null) {
        totalKm += distance;
      }
    }

    if (totalKm <= 0) {
      return '0 km';
    }

    if (totalKm < 1) {
      return '${(totalKm * 1000).round()}m';
    }

    return '${totalKm.toStringAsFixed(0)}km';
  }

  static double? distanceKmBetween(
    _SavedSpotPreview from,
    _SavedSpotPreview to,
  ) {
    if (from.lat == null ||
        from.lng == null ||
        to.lat == null ||
        to.lng == null) {
      return null;
    }

    return distanceInKm(
      from.lat!,
      from.lng!,
      to.lat!,
      to.lng!,
    );
  }

  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return 'route';

    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    }

    return '${distanceKm.toStringAsFixed(1)}km';
  }

  static String estimateTravelTime(double? distanceKm) {
    if (distanceKm == null) return 'Loading';

    const double averageSpeedKmH = 35.0;
    final int totalMinutes = ((distanceKm / averageSpeedKmH) * 60).round();

    if (totalMinutes <= 0) return '0m';
    if (totalMinutes < 60) return '${totalMinutes}m';

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (minutes == 0) return '${hours}h';

    return '${hours}h ${minutes}m';
  }

  static double distanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371;

    final double dLat = degreeToRadian(lat2 - lat1);
    final double dLon = degreeToRadian(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(degreeToRadian(lat1)) *
            math.cos(degreeToRadian(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusKm * c;
  }

  static double degreeToRadian(double degree) {
    return degree * math.pi / 180;
  }

  static double? toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '');
  }
}
