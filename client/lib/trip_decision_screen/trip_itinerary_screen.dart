import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_planner/services/mapbox_config.dart';
import 'package:trip_planner/services/mapbox_route_service.dart';
import 'package:trip_planner/services/trip_storage_service.dart';
import 'package:trip_planner/services/trip_invite_service.dart';

class TripItineraryScreen extends StatefulWidget {
  final String placeName;
  final int totalDays;
  final List<Map<String, dynamic>> selectedSpots;

  const TripItineraryScreen({
    super.key,
    required this.placeName,
    required this.totalDays,
    required this.selectedSpots,
  });

  @override
  State<TripItineraryScreen> createState() => _TripItineraryScreenState();
}

class _TripItineraryScreenState extends State<TripItineraryScreen> {
  late final List<TripItinerarySpot> allSpots;
  late final List<TripDayPlan> dayPlans;

  final Map<String, MapboxRouteResult> routeCache = {};
  bool isLoadingRoadRoutes = false;
  bool tripSaveAttempted = false;
  bool isManualSavingTrip = false;
  bool manualTripSaved = false;
  String? manualSavedTripId;

  // -1 = Overview
  // 0 = Day 1
  // 1 = Day 2
  int selectedTabIndex = -1;

  final List<Color> dayColors = const [
    Color(0xFF12A8FF), // Day 1 Blue
    Color(0xFF9C5CFF), // Day 2 Purple
    Color(0xFFFFA31A), // Day 3 Orange
    Color(0xFF2ECC71), // Day 4 Green
    Color(0xFFFF4D4D), // Day 5 Red
    Color(0xFF00C2A8), // Day 6 Teal
    Color(0xFFFF6FB1), // Day 7 Pink
    Color(0xFF7A5CFF), // Day 8 Indigo
    Color(0xFFFFC107), // Day 9 Amber
    Color(0xFF00B8D9), // Day 10 Cyan
  ];

  @override
  void initState() {
    super.initState();

    MapboxOptions.setAccessToken(MapboxConfig.accessToken);

    allSpots = widget.selectedSpots
        .where((spot) => spot['lat'] != null && spot['lng'] != null)
        .map((spot) {
      return TripItinerarySpot(
        name: spot['name']?.toString() ?? 'Unknown spot',
        subtitle: spot['subtitle']?.toString() ?? '',
        lat: double.tryParse(spot['lat'].toString()) ?? 0.0,
        lng: double.tryParse(spot['lng'].toString()) ?? 0.0,
        imageUrl: spot['image_url']?.toString() ?? '',
        categories: spot['categories'] is List
            ? List<String>.from(spot['categories'])
            : <String>[],
      );
    }).toList();

    dayPlans = buildDayPlans(allSpots, widget.totalDays);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await loadRoadRoutes();
      await saveCurrentTripToFirebase();
    });
  }

  Color getDayColor(int dayIndex) {
    return dayColors[dayIndex % dayColors.length];
  }

  String routeKey(TripItinerarySpot from, TripItinerarySpot to) {
    return '${from.lat},${from.lng}-${to.lat},${to.lng}';
  }

  Future<void> loadRoadRoutes() async {
    if (isLoadingRoadRoutes) return;

    isLoadingRoadRoutes = true;

    for (final day in dayPlans) {
      for (int i = 0; i < day.spots.length - 1; i++) {
        final from = day.spots[i];
        final to = day.spots[i + 1];
        final key = routeKey(from, to);

        if (routeCache.containsKey(key)) continue;

        final result = await MapboxRouteService.getDrivingRoute(
          fromLat: from.lat,
          fromLng: from.lng,
          toLat: to.lat,
          toLng: to.lng,
        );

        if (result != null) {
          routeCache[key] = result;
        }
      }
    }

    isLoadingRoadRoutes = false;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> saveCurrentTripToFirebase() async {
    if (tripSaveAttempted) return;

    tripSaveAttempted = true;

    try {
      await TripStorageService.saveTrip(
        placeName: widget.placeName,
        totalDays: safeDays,
        dayPlans: _buildSavedDaysForFirebase(),
        isManualSave: false,
      );
    } catch (_) {
      // Saving should not block the itinerary screen.
    }
  }

  Future<void> saveTripCopyManually() async {
    if (isManualSavingTrip || manualTripSaved) return;

    setState(() {
      isManualSavingTrip = true;
    });

    try {
      final savedTripId = await TripStorageService.saveTrip(
        placeName: widget.placeName,
        totalDays: safeDays,
        dayPlans: _buildSavedDaysForFirebase(),
        isManualSave: true,
      );

      if (!mounted) return;

      if (savedTripId != null) {
        setState(() {
          manualTripSaved = true;
          manualSavedTripId = savedTripId;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip saved: $savedTripId'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save trip'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save trip'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isManualSavingTrip = false;
        });
      }
    }
  }

  Future<void> showInviteBottomSheet() async {
    String? inviteCode;
    bool isLoading = true;
    bool codeRequested = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> createCodeOnce() async {
              if (codeRequested) return;
              codeRequested = true;

              final code = await TripInviteService.createTripInvite(
                placeName: widget.placeName,
                totalDays: safeDays,
                dayPlans: _buildSavedDaysForFirebase(),
              );

              if (!context.mounted) return;

              setSheetState(() {
                inviteCode = code;
                isLoading = false;
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              createCodeOnce();
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.58,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Invite Friends',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 34,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFE9F8FF),
                          Color(0xFFBDEBFF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFBCE0FD),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.placeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.luggage_rounded,
                              color: Colors.blue.shade400,
                              size: 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${allSpots.length} spots',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.blue.shade500,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${safeDays}-Day ${widget.placeName} Trip',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Center(
                          child: Text(
                            'TRIP INVITE CODE',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.black,
                                    ),
                                  )
                                : SelectableText(
                                    inviteCode ?? 'Unable to create code',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: inviteCode == null
                        ? null
                        : () {
                            Clipboard.setData(
                              ClipboardData(text: inviteCode!),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite code copied'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    child: Container(
                      width: double.infinity,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(38),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Copy Invite Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _buildSavedDaysForFirebase() {
    return dayPlans.map((day) {
      final spots = day.spots.map((spot) {
        return {
          'name': spot.name,
          'subtitle': spot.subtitle,
          'lat': spot.lat,
          'lng': spot.lng,
          'imageUrl': spot.imageUrl,
          'categories': spot.categories,
        };
      }).toList();

      final routeSegments = <Map<String, dynamic>>[];

      for (int i = 0; i < day.spots.length - 1; i++) {
        final from = day.spots[i];
        final to = day.spots[i + 1];
        final route = routeCache[routeKey(from, to)];

        routeSegments.add({
          'from': from.name,
          'to': to.name,
          'fromLat': from.lat,
          'fromLng': from.lng,
          'toLat': to.lat,
          'toLng': to.lng,
          'distanceKm': route?.distanceKm,
          'durationMinutes': route?.durationMinutes,
          'routeCoordinates': route?.coordinates,
        });
      }

      return {
        'day': day.day,
        'color': '#${day.color.value.toRadixString(16).padLeft(8, '0')}',
        'spots': spots,
        'routeSegments': routeSegments,
      };
    }).toList();
  }

  double? getRoadDistanceForPlan(TripDayPlan plan) {
    if (plan.spots.length <= 1) return 0;

    double total = 0;

    for (int i = 0; i < plan.spots.length - 1; i++) {
      final from = plan.spots[i];
      final to = plan.spots[i + 1];
      final route = routeCache[routeKey(from, to)];

      if (route == null) {
        return null;
      }

      total += route.distanceKm;
    }

    return total;
  }

  int get safeDays {
    return widget.totalDays.clamp(1, 10);
  }

  double degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = degreesToRadians(lat2 - lat1);
    final dLng = degreesToRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(degreesToRadians(lat1)) *
            math.cos(degreesToRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  List<TripItinerarySpot> sortByNearestNeighbor(
    List<TripItinerarySpot> spots,
  ) {
    if (spots.length <= 1) return spots;

    final remaining = List<TripItinerarySpot>.from(spots);
    final sorted = <TripItinerarySpot>[];

    TripItinerarySpot current = remaining.removeAt(0);
    sorted.add(current);

    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final distanceA = calculateDistanceKm(
          current.lat,
          current.lng,
          a.lat,
          a.lng,
        );

        final distanceB = calculateDistanceKm(
          current.lat,
          current.lng,
          b.lat,
          b.lng,
        );

        return distanceA.compareTo(distanceB);
      });

      current = remaining.removeAt(0);
      sorted.add(current);
    }

    return sorted;
  }

  List<TripDayPlan> buildDayPlans(
    List<TripItinerarySpot> spots,
    int totalDays,
  ) {
    final days = totalDays.clamp(1, 10);
    final sortedSpots = sortByNearestNeighbor(spots);

    final grouped = List.generate(days, (_) => <TripItinerarySpot>[]);

    if (sortedSpots.isEmpty) {
      return List.generate(days, (index) {
        return TripDayPlan(
          day: index + 1,
          color: getDayColor(index),
          spots: const [],
          totalDistanceKm: 0,
        );
      });
    }

    final baseCount = sortedSpots.length ~/ days;
    final remainder = sortedSpots.length % days;

    int cursor = 0;

    for (int dayIndex = 0; dayIndex < days; dayIndex++) {
      final countForDay = baseCount + (dayIndex < remainder ? 1 : 0);

      for (int j = 0; j < countForDay; j++) {
        if (cursor < sortedSpots.length) {
          grouped[dayIndex].add(sortedSpots[cursor]);
          cursor++;
        }
      }
    }

    return List.generate(days, (index) {
      final daySpots = grouped[index];

      return TripDayPlan(
        day: index + 1,
        color: getDayColor(index),
        spots: daySpots,
        totalDistanceKm: calculateDayDistance(daySpots),
      );
    });
  }

  double calculateDayDistance(List<TripItinerarySpot> spots) {
    if (spots.length <= 1) return 0;

    double total = 0;

    for (int i = 0; i < spots.length - 1; i++) {
      total += calculateDistanceKm(
        spots[i].lat,
        spots[i].lng,
        spots[i + 1].lat,
        spots[i + 1].lng,
      );
    }

    return total;
  }

  double calculateDistanceBetweenSpots(
    TripItinerarySpot a,
    TripItinerarySpot b,
  ) {
    return calculateDistanceKm(a.lat, a.lng, b.lat, b.lng);
  }

  String estimateTravelTime(double distanceKm) {
    // Approx average local road speed.
    const averageSpeedKmH = 35.0;

    final totalMinutes = ((distanceKm / averageSpeedKmH) * 60).round();

    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  TripDayPlan? get selectedDayPlan {
    if (selectedTabIndex < 0) return null;
    if (selectedTabIndex >= dayPlans.length) return null;
    return dayPlans[selectedTabIndex];
  }

  List<TripDayPlan> get visibleMapPlans {
    final selected = selectedDayPlan;

    if (selected != null) {
      return [selected];
    }

    return dayPlans;
  }

  String get coverImage {
    for (final spot in allSpots) {
      if (spot.imageUrl.isNotEmpty) {
        return spot.imageUrl;
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final totalSpots = allSpots.length;
    final selectedDay = selectedDayPlan;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _MapboxItineraryMap(
            key: ValueKey(
                'itinerary_map_${selectedTabIndex}_${routeCache.length}'),
            dayPlans: visibleMapPlans,
            routeCache: routeCache,
          ),
          Positioned(
            top: 52,
            left: 24,
            child: _CircleIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ),
          Positioned(
            top: 52,
            right: 24,
            child: _SaveTripButton(
              isSaving: isManualSavingTrip,
              isSaved: manualTripSaved,
              savedTripId: manualSavedTripId,
              onTap: saveTripCopyManually,
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.56,
            minChildSize: 0.56,
            maxChildSize: 0.88,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildTripHeader(totalSpots),
                    const SizedBox(height: 16),
                    _buildTabs(),
                    const SizedBox(height: 16),
                    if (selectedDay == null)
                      _buildOverview()
                    else
                      _buildDayDetails(selectedDay),
                    const SizedBox(height: 36),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeader(int totalSpots) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SpotImageBox(
          imageUrl: coverImage,
          categories: const [],
          size: 112,
          borderRadius: 22,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${safeDays}-Day ${widget.placeName},\nIndia Trip',
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.10,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$safeDays days • $totalSpots spots',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _GoogleAvatarCircle(),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFFA31A),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: showInviteBottomSheet,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.ios_share_rounded,
              color: Colors.grey.shade500,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _TabChip(
            text: 'Overview',
            icon: Icons.map_outlined,
            isSelected: selectedTabIndex == -1,
            onTap: () {
              setState(() {
                selectedTabIndex = -1;
              });
            },
          ),
          const SizedBox(width: 12),
          ...List.generate(dayPlans.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TabChip(
                text: 'Day ${index + 1}',
                icon: null,
                isSelected: selectedTabIndex == index,
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
    );
  }

  Widget _buildOverview() {
    return Column(
      children: dayPlans.map(_buildOverviewDayCard).toList(),
    );
  }

  Widget _buildOverviewDayCard(TripDayPlan plan) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTabIndex = plan.day - 1;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFEDEDEF),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: plan.color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'Day ${plan.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  '${getRoadDistanceForPlan(plan) == null ? 'Loading' : '${getRoadDistanceForPlan(plan)!.toStringAsFixed(0)}km'} • ${plan.spots.length} spots',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plan.spots.length > 5 ? 6 : plan.spots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final hiddenCount =
                      plan.spots.length > 5 ? plan.spots.length - 5 : 0;

                  if (index == 5 && hiddenCount > 0) {
                    return Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFEFF1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '+$hiddenCount',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black54,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }

                  final spot = plan.spots[index];

                  return _SpotImageBox(
                    imageUrl: spot.imageUrl,
                    categories: spot.categories,
                    size: 64,
                    borderRadius: 12,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetails(TripDayPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.placeName,
                style: TextStyle(
                  fontSize: 25,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${getRoadDistanceForPlan(plan) == null ? 'Loading' : '${getRoadDistanceForPlan(plan)!.toStringAsFixed(0)}km'} • ${plan.spots.length} spots',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (plan.spots.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'No spots added for Day ${plan.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          )
        else
          ...List.generate(plan.spots.length, (index) {
            final spot = plan.spots[index];

            return Column(
              children: [
                _buildDaySpotCard(
                  plan: plan,
                  spot: spot,
                  index: index,
                ),
                if (index < plan.spots.length - 1)
                  _buildTravelBetween(
                    from: plan.spots[index],
                    to: plan.spots[index + 1],
                  ),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildDaySpotCard({
    required TripDayPlan plan,
    required TripItinerarySpot spot,
    required int index,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: plan.color.withOpacity(0.12),
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
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Container(
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
                _SpotImageBox(
                  imageUrl: spot.imageUrl,
                  categories: spot.categories,
                  size: 88,
                  borderRadius: 16,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _CategoryPill(categories: spot.categories),
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

  Widget _buildTravelBetween({
    required TripItinerarySpot from,
    required TripItinerarySpot to,
  }) {
    final route = routeCache[routeKey(from, to)];
    final bool routeReady = route != null;
    final String time = routeReady ? route.formattedDuration : 'Loading';
    final String distanceText = routeReady ? route.formattedDistance : 'route';

    return Padding(
      padding: const EdgeInsets.only(left: 64, top: 12, bottom: 12),
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
                  routeReady ? '$time • $distanceText' : 'Loading road route',
                  style: const TextStyle(
                    fontSize: 18,
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
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF12A8FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapboxItineraryMap extends StatefulWidget {
  final List<TripDayPlan> dayPlans;
  final Map<String, MapboxRouteResult> routeCache;

  const _MapboxItineraryMap({
    super.key,
    required this.dayPlans,
    required this.routeCache,
  });

  @override
  State<_MapboxItineraryMap> createState() => _MapboxItineraryMapState();
}

class _MapboxItineraryMapState extends State<_MapboxItineraryMap> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? pointManager;
  PolylineAnnotationManager? polylineManager;

  List<TripItinerarySpot> get allVisibleSpots {
    return widget.dayPlans.expand((plan) => plan.spots).toList();
  }

  @override
  void didUpdateWidget(covariant _MapboxItineraryMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (mapboxMap != null) {
      _drawMapData();
    }
  }

  CameraOptions get initialCameraOptions {
    final spots = allVisibleSpots;

    if (spots.isEmpty) {
      return CameraOptions(
        center: Point(
          coordinates: Position(81.6296, 21.2514),
        ),
        zoom: 8.0,
      );
    }

    double avgLat = 0;
    double avgLng = 0;

    for (final spot in spots) {
      avgLat += spot.lat;
      avgLng += spot.lng;
    }

    avgLat = avgLat / spots.length;
    avgLng = avgLng / spots.length;

    return CameraOptions(
      center: Point(
        coordinates: Position(avgLng, avgLat),
      ),
      zoom: spots.length <= 2 ? 11.0 : 9.0,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();

    await _drawMapData();
  }

  Future<void> _drawMapData() async {
    if (pointManager == null || polylineManager == null) return;

    await pointManager!.deleteAll();
    await polylineManager!.deleteAll();

    await _drawRouteLines();
    await _drawSpotMarkers();
    await _moveCameraToVisibleSpots();
  }

  Future<void> _drawRouteLines() async {
    if (polylineManager == null) return;

    final options = <PolylineAnnotationOptions>[];

    for (final plan in widget.dayPlans) {
      if (plan.spots.length < 2) continue;

      for (int i = 0; i < plan.spots.length - 1; i++) {
        final from = plan.spots[i];
        final to = plan.spots[i + 1];
        final key = '${from.lat},${from.lng}-${to.lat},${to.lng}';
        final route = widget.routeCache[key];

        List<Position> positions;

        if (route != null && route.coordinates.isNotEmpty) {
          positions = route.coordinates.map((point) {
            return Position(point[0], point[1]);
          }).toList();
        } else {
          positions = [
            Position(from.lng, from.lat),
            Position(to.lng, to.lat),
          ];
        }

        options.add(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: positions),
            lineColor: plan.color.value,
            lineWidth: 6,
            lineOpacity: 0.95,
          ),
        );
      }
    }

    if (options.isNotEmpty) {
      await polylineManager!.createMulti(options);
    }
  }

  Future<void> _drawSpotMarkers() async {
    if (pointManager == null) return;

    final options = <PointAnnotationOptions>[];

    for (final plan in widget.dayPlans) {
      for (int i = 0; i < plan.spots.length; i++) {
        final spot = plan.spots[i];
        final markerImage = await _createNumberMarkerImage(
          number: i + 1,
          color: plan.color,
        );

        options.add(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(spot.lng, spot.lat),
            ),
            image: markerImage,
            iconSize: 0.72,
          ),
        );
      }
    }

    if (options.isNotEmpty) {
      await pointManager!.createMulti(options);
    }
  }

  Future<Uint8List> _createNumberMarkerImage({
    required int number,
    required Color color,
  }) async {
    const double size = 96;
    const double strokeWidth = 8;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.drawCircle(
      center.translate(0, 3),
      (size / 2) - strokeWidth,
      shadowPaint,
    );

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      center,
      (size / 2) - strokeWidth,
      fillPaint,
    );

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(
      center,
      (size / 2) - strokeWidth,
      strokePaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: color,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _moveCameraToVisibleSpots() async {
    final spots = allVisibleSpots;

    if (mapboxMap == null || spots.isEmpty) return;

    double minLat = spots.first.lat;
    double maxLat = spots.first.lat;
    double minLng = spots.first.lng;
    double maxLng = spots.first.lng;

    for (final spot in spots) {
      minLat = math.min(minLat, spot.lat);
      maxLat = math.max(maxLat, spot.lat);
      minLng = math.min(minLng, spot.lng);
      maxLng = math.max(maxLng, spot.lng);
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);

    double zoom = 10.5;

    if (maxDiff > 2.0) {
      zoom = 6.5;
    } else if (maxDiff > 1.0) {
      zoom = 7.5;
    } else if (maxDiff > 0.5) {
      zoom = 8.5;
    } else if (maxDiff > 0.2) {
      zoom = 9.5;
    } else if (maxDiff > 0.08) {
      zoom = 10.5;
    } else {
      zoom = 12.0;
    }

    await mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(centerLng, centerLat),
        ),
        zoom: zoom,
      ),
      MapAnimationOptions(
        duration: 700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.46,
      width: double.infinity,
      child: MapWidget(
        key: const ValueKey('separate_itinerary_mapbox_map'),
        styleUri: MapboxStyles.STANDARD,
        cameraOptions: initialCameraOptions,
        onMapCreated: _onMapCreated,
      ),
    );
  }
}

class TripItinerarySpot {
  final String name;
  final String subtitle;
  final double lat;
  final double lng;
  final String imageUrl;
  final List<String> categories;

  const TripItinerarySpot({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.imageUrl,
    required this.categories,
  });
}

class TripDayPlan {
  final int day;
  final Color color;
  final List<TripItinerarySpot> spots;
  final double totalDistanceKm;

  const TripDayPlan({
    required this.day,
    required this.color,
    required this.spots,
    required this.totalDistanceKm,
  });
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
      width: 42,
      height: 42,
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
      color: const Color(0xFFF1F1F3),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black54,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _SaveTripButton extends StatelessWidget {
  final bool isSaving;
  final bool isSaved;
  final String? savedTripId;
  final VoidCallback onTap;

  const _SaveTripButton({
    required this.isSaving,
    required this.isSaved,
    required this.savedTripId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = isSaving || isSaved;

    return Material(
      color: isSaved ? const Color(0xFF35D87C) : Colors.white,
      borderRadius: BorderRadius.circular(30),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSaving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.grey.shade700,
                  ),
                )
              else
                Icon(
                  isSaved ? Icons.check_circle_rounded : Icons.bookmark_rounded,
                  color: isSaved ? Colors.white : Colors.grey.shade600,
                  size: 23,
                ),
              const SizedBox(width: 8),
              Text(
                isSaving ? 'Saving' : (isSaved ? 'Saved' : 'Save'),
                style: TextStyle(
                  color: isSaved ? Colors.white : Colors.grey.shade700,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(
            icon,
            color: Colors.grey.shade600,
            size: 31,
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.text,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF242424) : const Color(0xFFF2F2F3),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          height: 52,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                  size: 24,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade500,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotImageBox extends StatelessWidget {
  final String imageUrl;
  final List<String> categories;
  final double size;
  final double borderRadius;

  const _SpotImageBox({
    required this.imageUrl,
    required this.categories,
    required this.size,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFF1F1F3),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _SpotFallbackIcon(categories: categories);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;

                  return _SpotFallbackIcon(categories: categories);
                },
              )
            : _SpotFallbackIcon(categories: categories),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final List<String> categories;

  const _CategoryPill({
    required this.categories,
  });

  String get firstCategory {
    if (categories.isEmpty) return 'Place';
    return categories.first;
  }

  IconData get icon {
    final lower = firstCategory.toLowerCase();

    if (lower.contains('museum')) return Icons.museum_outlined;
    if (lower.contains('nature')) return Icons.park_rounded;
    if (lower.contains('beach')) return Icons.beach_access_rounded;
    if (lower.contains('history')) return Icons.account_balance_rounded;
    if (lower.contains('temple')) return Icons.temple_hindu_rounded;
    if (lower.contains('wildlife')) return Icons.pets_rounded;
    if (lower.contains('shopping')) return Icons.shopping_bag_rounded;

    return Icons.place_rounded;
  }

  Color get color {
    final lower = firstCategory.toLowerCase();

    if (lower.contains('nature')) return const Color(0xFF2ECC71);
    if (lower.contains('beach')) return const Color(0xFF12A8FF);
    if (lower.contains('history')) return const Color(0xFFFFA31A);
    if (lower.contains('temple')) return const Color(0xFF9C5CFF);
    if (lower.contains('wildlife')) return const Color(0xFFFF6FB1);
    if (lower.contains('shopping')) return const Color(0xFFFF4D4D);
    if (lower.contains('museum')) return const Color(0xFF00B8D9);

    return const Color(0xFF12A8FF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            firstCategory,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotFallbackIcon extends StatelessWidget {
  final List<String> categories;

  const _SpotFallbackIcon({
    required this.categories,
  });

  IconData _iconForCategory() {
    final lowerCategories = categories.map((e) => e.toLowerCase()).toList();

    if (lowerCategories.any((e) => e.contains('museum'))) {
      return Icons.museum_outlined;
    }

    if (lowerCategories.any((e) => e.contains('nature'))) {
      return Icons.park_outlined;
    }

    if (lowerCategories.any((e) => e.contains('beach'))) {
      return Icons.beach_access_outlined;
    }

    if (lowerCategories.any((e) => e.contains('history'))) {
      return Icons.account_balance_outlined;
    }

    if (lowerCategories.any((e) => e.contains('temple'))) {
      return Icons.temple_hindu_outlined;
    }

    if (lowerCategories.any((e) => e.contains('wildlife'))) {
      return Icons.pets_outlined;
    }

    if (lowerCategories.any((e) => e.contains('shopping'))) {
      return Icons.shopping_bag_outlined;
    }

    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        _iconForCategory(),
        color: const Color(0xFF9A9A9F),
        size: 30,
      ),
    );
  }
}
