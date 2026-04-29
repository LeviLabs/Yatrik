import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:trip_planner/data/destinations.dart';
import 'package:trip_planner/services/trip_api.dart';
import 'package:trip_planner/trip_decision_screen/trip_itinerary_screen.dart';

class Phase1Screen extends StatefulWidget {
  const Phase1Screen({super.key});

  @override
  State<Phase1Screen> createState() => _Phase1ScreenState();
}

class _Phase1ScreenState extends State<Phase1Screen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final List<_CityData> _cities = const [
    _CityData(name: 'France', flag: '🇫🇷', places: '5 places'),
    _CityData(name: 'Italy', flag: '🇮🇹', places: '6 places'),
    _CityData(name: 'Japan', flag: '🇯🇵', places: '7 places'),
    _CityData(name: 'Thailand', flag: '🇹🇭', places: '4 places'),
    _CityData(name: 'USA', flag: '🇺🇸', places: '8 places'),
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final FixedExtentScrollController _daysScrollController;

  List<Destination> _searchResults = [];

  bool _isSearching = false;
  bool _isPageActive = true;
  bool _didPrecache = false;
  bool _isAnimating = false;
  bool _showSelectedPreview = false;
  bool _showPreferencesPage = false;
  bool _showDurationPage = false;
  bool _showSelectDaysPage = false;
  bool _isSendingToBackend = false;

  bool _showPlanningPage = false;
  bool _planningCompleted = false;
  bool _showDiscoverPage = false;

  Timer? _planningSpinTimer;
  int _planningSpinStep = 0;

  String _selectedPlace = '';
  String _selectedSubtitle = '';
  String _selectedFlag = '🇮🇳';

  final Set<String> _selectedPreferences = {};

  int? _selectedDays;

  List<_SpotData> _spots = [];
  final Set<int> _selectedSpotIndexes = {};

  late final AnimationController _rotationController;
  Timer? _rotationTimer;

  int _centerIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _daysScrollController = FixedExtentScrollController(initialItem: 0);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _rotationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _centerIndex = (_centerIndex + 1) % _cities.length;
          _isAnimating = false;
        });
        _rotationController.reset();
      }
    });

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRotation(immediate: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didPrecache) {
      _didPrecache = true;
      precacheImage(
        const AssetImage('assets/images/gradient_bg.png'),
        context,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      _isPageActive = true;
      if (!_isSearching &&
          !_showSelectedPreview &&
          !_showPreferencesPage &&
          !_showDurationPage &&
          !_showSelectDaysPage &&
          !_showPlanningPage &&
          !_showDiscoverPage) {
        _startRotation(immediate: true);
      }
    } else {
      _isPageActive = false;
      _stopRotation();
    }
  }

  void _startRotation({bool immediate = false}) {
    _stopRotation();

    if (immediate) {
      Future.delayed(const Duration(milliseconds: 120), () {
        _runRotation();
      });
    }

    _rotationTimer = Timer.periodic(const Duration(milliseconds: 1900), (_) {
      _runRotation();
    });
  }

  void _stopRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _rotationController.stop();
    _rotationController.reset();
    _isAnimating = false;
  }

  void _runRotation() {
    if (!mounted ||
        !_isPageActive ||
        _isSearching ||
        _showSelectedPreview ||
        _showPreferencesPage ||
        _showDurationPage ||
        _showSelectDaysPage ||
        _showPlanningPage ||
        _showDiscoverPage) {
      return;
    }
    if (_isAnimating) return;

    _isAnimating = true;
    _rotationController.forward(from: 0);
  }

  int _safeIndex(int index) {
    final int len = _cities.length;
    return ((index % len) + len) % len;
  }

  _CityData _cityAt(int index) {
    return _cities[_safeIndex(index)];
  }

  void _handleSearch(String userText) {
    if (userText.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final query = userText.toLowerCase().trim();
    final List<Destination> localMatches = [];
    final Set<String> seenHeroText = {};

    for (final dest in globalDestinations) {
      final bool nameMatch = dest.name.toLowerCase().contains(query);
      final bool stateMatch = dest.subtitle.toLowerCase().contains(query);

      if (nameMatch || stateMatch) {
        String heroText;
        String subText;

        if (stateMatch && !nameMatch) {
          heroText = dest.subtitle;
          subText = 'India';
        } else {
          heroText = dest.name;
          subText = dest.subtitle;
        }

        if (!seenHeroText.contains(heroText)) {
          localMatches.add(
            Destination(name: heroText, subtitle: subText),
          );
          seenHeroText.add(heroText);
        }
      }
    }

    setState(() {
      _searchResults = localMatches;
    });
  }

  void _openSearch() {
    _stopRotation();

    setState(() {
      _isSearching = true;
      _showSelectedPreview = false;
      _showPreferencesPage = false;
      _showDurationPage = false;
      _showSelectDaysPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchFocus.unfocus();

    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
    });

    if (!_showSelectedPreview &&
        !_showPreferencesPage &&
        !_showDurationPage &&
        !_showSelectDaysPage &&
        !_showPlanningPage &&
        !_showDiscoverPage) {
      _startRotation(immediate: true);
    }
  }

  void _selectPlace(Destination destination) {
    _searchFocus.unfocus();

    setState(() {
      _selectedPlace = destination.name;
      _selectedSubtitle = destination.subtitle;
      _selectedFlag = '🇮🇳';
      _showSelectedPreview = true;
      _showPreferencesPage = false;
      _showDurationPage = false;
      _showSelectDaysPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
    });
  }

  void _editSelectedPlace() {
    setState(() {
      _showSelectedPreview = false;
      _showPreferencesPage = false;
      _showDurationPage = false;
      _showSelectDaysPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
      _isSearching = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _continueWithSelectedPlace() {
    setState(() {
      _showPreferencesPage = true;
      _showSelectedPreview = false;
      _showDurationPage = false;
      _showSelectDaysPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
      _isSearching = false;
    });
  }

  void _continueFromPreferences() {
    setState(() {
      _showDurationPage = true;
      _showPreferencesPage = false;
      _showSelectedPreview = false;
      _showSelectDaysPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
      _isSearching = false;
    });
  }

  void _openSelectDaysPage() {
    _daysScrollController.jumpToItem((_selectedDays ?? 1) - 1);
    setState(() {
      _showSelectDaysPage = true;
      _showDurationPage = false;
      _showPlanningPage = false;
      _showDiscoverPage = false;
    });
  }

  void _confirmSelectedDays() {
    setState(() {
      _showSelectDaysPage = false;
      _showDurationPage = true;
      _showPlanningPage = false;
      _showDiscoverPage = false;
    });
  }

  void _backFromSelectDays() {
    setState(() {
      _showSelectDaysPage = false;
      _showDurationPage = true;
      _showPlanningPage = false;
      _showDiscoverPage = false;
    });
  }

  void _startPlanningSpin() {
    _planningSpinTimer?.cancel();

    _planningSpinTimer = Timer.periodic(
      const Duration(milliseconds: 220),
      (_) {
        if (!mounted || _planningCompleted) return;

        setState(() {
          _planningSpinStep++;
        });
      },
    );
  }

  void _stopPlanningSpin() {
    _planningSpinTimer?.cancel();
    _planningSpinTimer = null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString());
  }

  List<_SpotData> _extractSpotsFromBackend(dynamic result) {
    dynamic rawList;

    if (result is Map<String, dynamic>) {
      rawList = result['recommendations'] ??
          result['recommended_places'] ??
          result['recommended_spots'] ??
          result['spots'] ??
          result['places'] ??
          result['itinerary'] ??
          result['data'] ??
          result['results'] ??
          result['tourist_spots'] ??
          result['output'];
    } else if (result is List) {
      rawList = result;
    }

    if (rawList is! List) return [];

    return rawList.map<_SpotData>((item) {
      if (item is Map<String, dynamic>) {
        final name = (item['name'] ??
                item['place_name'] ??
                item['spot_name'] ??
                item['title'] ??
                item['Place_Name'] ??
                item['Spot_Name'] ??
                item['Tourist_Spot'] ??
                item['Location'] ??
                'Unknown spot')
            .toString();

        final subtitle = (item['description'] ??
                item['subtitle'] ??
                item['type'] ??
                item['category'] ??
                item['address'] ??
                item['City'] ??
                item['city'] ??
                item['State'] ??
                item['state'] ??
                _selectedSubtitle)
            .toString();

        final lat = _toDouble(
          item['lat'] ??
              item['Lat'] ??
              item['latitude'] ??
              item['Latitude'] ??
              item['LAT'],
        );

        final lng = _toDouble(
          item['lng'] ??
              item['Lng'] ??
              item['lon'] ??
              item['Lon'] ??
              item['long'] ??
              item['Long'] ??
              item['longitude'] ??
              item['Longitude'] ??
              item['LNG'],
        );

        final imageUrl = (item['image_url'] ??
                item['image'] ??
                item['photo_url'] ??
                item['thumbnail'] ??
                '')
            .toString();

        final rawCategories = item['categories'];

        final categories = rawCategories is List
            ? rawCategories.map((e) => e.toString()).toList()
            : <String>[];

        return _SpotData(
          name: name,
          subtitle: subtitle,
          lat: lat,
          lng: lng,
          imageUrl: imageUrl,
          categories: categories,
        );
      }

      return _SpotData(
        name: item.toString(),
        subtitle: _selectedSubtitle,
        lat: null,
        lng: null,
        imageUrl: '',
        categories: const [],
      );
    }).toList();
  }

  Future<void> _continueFromDuration() async {
    if (_selectedDays == null) return;
    if (_isSendingToBackend) return;

    setState(() {
      _isSendingToBackend = true;
      _showPlanningPage = true;
      _planningCompleted = false;
      _showDiscoverPage = false;

      _showDurationPage = false;
      _showSelectDaysPage = false;
      _showPreferencesPage = false;
      _showSelectedPreview = false;
      _isSearching = false;
    });

    _startPlanningSpin();

    try {
      final apiFuture = TripApi.sendTripInput(
        city: _selectedPlace,
        state: _selectedSubtitle,
        days: _selectedDays!,
        preferences: _selectedPreferences.toList(),
      );

      final delayFuture = Future.delayed(const Duration(milliseconds: 1500));

      final result = await apiFuture;
      await delayFuture;

      debugPrint("Backend result: $result");

      final fetchedSpots = _extractSpotsFromBackend(result);

      if (!mounted) return;

      _stopPlanningSpin();

      setState(() {
        _spots = fetchedSpots;
        _selectedSpotIndexes
          ..clear()
          ..addAll(List.generate(fetchedSpots.length, (index) => index));

        _planningCompleted = true;
        _isSendingToBackend = false;
      });

      await Future.delayed(const Duration(milliseconds: 650));

      if (!mounted) return;

      setState(() {
        _showPlanningPage = false;
        _showDiscoverPage = true;
      });
    } catch (e) {
      debugPrint("Backend error: $e");

      _stopPlanningSpin();

      if (!mounted) return;

      setState(() {
        _showPlanningPage = false;
        _showDurationPage = true;
        _showDiscoverPage = false;
        _planningCompleted = false;
        _isSendingToBackend = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Backend error: $e"),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRotation();
    _stopPlanningSpin();
    _rotationController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _daysScrollController.dispose();
    super.dispose();
  }

  TextStyle _montserrat({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Montserrat',
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    const panelH = 250.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        height: screenH * 0.88,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Stack(
            children: [
              if (_showDiscoverPage)
                _buildPlanningPageBackground()
              else if (_showPlanningPage)
                _buildPlanningPageBackground()
              else if (_showSelectDaysPage)
                _buildDurationPageBackground()
              else if (_showDurationPage)
                _buildDurationPageBackground()
              else if (_showPreferencesPage)
                _buildPreferencesPageBackground()
              else if (_isSearching)
                _buildSearchPageBackground()
              else
                _buildNormalBackground(),
              if (_showDiscoverPage)
                _buildDiscoverSpotsPage()
              else if (_showPlanningPage)
                _buildPlanningPage()
              else if (_showSelectDaysPage)
                _buildSelectDaysPage()
              else if (_showDurationPage)
                _buildDurationPage()
              else if (_showPreferencesPage)
                _buildPreferencesPage()
              else if (_showSelectedPreview)
                _buildSelectedPreviewUI()
              else if (_isSearching)
                _buildSearchUI(keyboardInset)
              else
                _buildNormalUI(panelH),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalBackground() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/gradient_bg.png',
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _buildSearchPageBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF02B9FD),
              Color(0xFF38B8EE),
              Color(0xFF7EC9F2),
              Color(0xFFB8DDF4),
              Color(0xFFEFF4F8),
              Color(0xFFF4F5F7),
            ],
            stops: [0.0, 0.22, 0.45, 0.66, 0.84, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesPageBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF95CDFF),
              Color(0xFF98D1FE),
              Color(0xFFAED7FF),
              Color(0xFFBADDFD),
              Color(0xFFEFF4F8),
              Color(0xFFF4F5F7),
              Color(0xFFF4F5F7),
            ],
            stops: [
              0.0,
              0.08,
              0.18,
              0.28,
              0.40,
              0.55,
              1.0,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationPageBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB9F2E8),
              Color(0xFFC8F3EA),
              Color(0xFFD7F4ED),
              Color(0xFFE6F6F1),
              Color(0xFFF0F4F3),
              Color(0xFFF4F5F7),
            ],
            stops: [0.0, 0.18, 0.36, 0.56, 0.78, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanningPageBackground() {
    return Positioned.fill(
      child: Container(
        color: Colors.white,
      ),
    );
  }

  Widget _buildSearchUI(double keyboardInset) {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 54),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                        ),
                        onPressed: _closeSearch,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          style: _montserrat(
                            fontSize: 18,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search city or state...',
                            hintStyle: _montserrat(
                              color: Colors.grey,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: _handleSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults.clear());
                          },
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    keyboardInset > 0 ? keyboardInset + 24 : 24,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final destination = _searchResults[index];
                    return _SearchResultTile(
                      title: destination.name,
                      subtitle: destination.subtitle,
                      textStyleBuilder: _montserrat,
                      onTap: () => _selectPlace(destination),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPreviewUI() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 92, 30, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _selectedFlag,
                      style: const TextStyle(fontSize: 44),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedPlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _montserrat(
                          fontSize: 34,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: _editSelectedPlace,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  "Let’s go to $_selectedPlace!",
                  style: _montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.95),
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 26),
                _ContinueButton(
                  onTap: _continueWithSelectedPlace,
                  textStyleBuilder: _montserrat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPage() {
    final chips = [
      ['🏛️', 'Museum'],
      ['🌿', 'Nature'],
      ['🏖️', 'Beach'],
      ['📜', 'History'],
      ['🛕', 'Temple'],
      ['🦁', 'Wildlife'],
      ['🛍️', 'Shopping'],
      ['🍕', 'Foodie'],
    ];

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 88, 26, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '👍',
                  style: TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  'Trip Preferences',
                  style: _montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What should your trip be about?',
                  style: _montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: chips.map((item) {
                    final emoji = item[0];
                    final label = item[1];
                    final isSelected = _selectedPreferences.contains(label);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPreferences.remove(label);
                          } else {
                            _selectedPreferences.add(label);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                isSelected ? Colors.black : Colors.transparent,
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: _montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 42),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.grey.shade500,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Trip Duration',
                      style: _montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _ContinueButton(
                  onTap: _continueFromPreferences,
                  textStyleBuilder: _montserrat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationPage() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 88, 26, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 7),
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      color: Colors.grey.shade500,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Trip Preferences',
                      style: _montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF66DFCF),
                  size: 42,
                ),
                const SizedBox(height: 22),
                Text(
                  'Trip Duration',
                  style: _montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedDays == null
                      ? 'Choose your dates or trip length'
                      : '${_selectedDays!} day${_selectedDays! > 1 ? 's' : ''}',
                  style: _montserrat(
                    fontSize: 14,
                    fontWeight: _selectedDays == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: _selectedDays == null
                        ? Colors.grey.shade500
                        : Colors.black,
                  ),
                ),
                const Spacer(flex: 4),
                InkWell(
                  onTap: _isSendingToBackend
                      ? null
                      : (_selectedDays == null
                          ? _openSelectDaysPage
                          : _continueFromDuration),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSendingToBackend)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        else
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: Colors.black,
                            size: 24,
                          ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDays == null
                              ? 'Select Days'
                              : (_isSendingToBackend
                                  ? 'Planning...'
                                  : 'Continue'),
                          style: _montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningPage() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(34, 0, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      color: Colors.grey.shade500,
                      size: 31,
                    ),
                    const SizedBox(width: 34),
                    Text(
                      'Trip Preferences',
                      style: _montserrat(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.grey.shade500,
                      size: 31,
                    ),
                    const SizedBox(width: 34),
                    Text(
                      'Trip Duration',
                      style: _montserrat(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanningStatusIcon(),
                    const SizedBox(width: 34),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _planningCompleted
                                  ? 'Trip preferences saved!'
                                  : 'Planning your trip',
                              key: ValueKey(_planningCompleted),
                              style: _montserrat(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _planningCompleted
                                  ? "Let's continue"
                                  : "Hold tight while we're setting up\nyour adventure",
                              key: ValueKey('sub_$_planningCompleted'),
                              style: _montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFB6B6BB),
                                height: 1.28,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanningStatusIcon() {
    if (_planningCompleted) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFF35D87C),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 25,
        ),
      );
    }

    return AnimatedRotation(
      turns: _planningSpinStep * 0.15,
      duration: const Duration(milliseconds: 220),
      curve: Curves.linear,
      child: CustomPaint(
        size: const Size(36, 36),
        painter: _DashedCirclePainter(),
      ),
    );
  }

  Widget _buildDiscoverSpotsPage() {
    final selectedCount = _selectedSpotIndexes.length;

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 62, 30, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover spots',
                  style: _montserrat(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 38),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.black,
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(
                        _selectedPlace.isEmpty
                            ? 'Selected place'
                            : _selectedPlace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _montserrat(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF8E8E93),
                      size: 30,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _spots.isEmpty
                      ? Center(
                          child: Text(
                            'No spots found from backend',
                            style: _montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 118),
                          itemCount: _spots.length,
                          itemBuilder: (context, index) {
                            final spot = _spots[index];
                            final isSelected =
                                _selectedSpotIndexes.contains(index);

                            return _DiscoverSpotTile(
                              index: index + 1,
                              spot: spot,
                              isSelected: isSelected,
                              textStyleBuilder: _montserrat,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedSpotIndexes.remove(index);
                                  } else {
                                    _selectedSpotIndexes.add(index);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 38,
            right: 38,
            bottom: 28,
            child: InkWell(
              onTap: () {
                final List<Map<String, dynamic>> selectedSpots =
                    _selectedSpotIndexes.map((i) {
                  final spot = _spots[i];

                  return {
                    'name': spot.name,
                    'subtitle': spot.subtitle,
                    'lat': spot.lat,
                    'lng': spot.lng,
                    'image_url': spot.imageUrl,
                    'categories': spot.categories,
                  };
                }).toList();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripItineraryScreen(
                      placeName: _selectedPlace,
                      totalDays: _selectedDays ?? 1,
                      selectedSpots: selectedSpots,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(34),
              child: Container(
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Add $selectedCount spots',
                    style: _montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectDaysPage() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                width: 52,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 42, 26, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _backFromSelectDays,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 28,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'How many days?',
                  style: _montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.6,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        controller: _daysScrollController,
                        itemExtent: 78,
                        perspective: 0.003,
                        diameterRatio: 1.8,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedDays = index + 1;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 10,
                          builder: (context, index) {
                            final day = index + 1;
                            final isSelected = day == (_selectedDays ?? 1);
                            return Center(
                              child: Text(
                                '$day',
                                style: _montserrat(
                                  fontSize: isSelected ? 64 : 52,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade400,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _confirmSelectedDays,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        'Confirm',
                        style: _montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalUI(double panelH) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F5F6),
                    Color(0x00F5F5F6),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 42,
          left: 0,
          right: 0,
          height: 290,
          child: _buildThreeNameRotation(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: panelH,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: panelH * 0.82,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.08),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where are we going?',
                        style: _montserrat(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.95),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search for your destination',
                        style: _montserrat(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.82),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SearchButton(
                        onTap: _openSearch,
                        textStyleBuilder: _montserrat,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 52,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeNameRotation() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, _) {
        final double t = Curves.easeInOut.transform(_rotationController.value);

        final currentTop = _cityAt(_centerIndex - 1);
        final currentCenter = _cityAt(_centerIndex);
        final currentBottom = _cityAt(_centerIndex + 1);
        final nextBottom = _cityAt(_centerIndex + 2);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _animatedCityRow(
                city: currentTop,
                top: lerpDouble(38, -34, t),
                opacity: lerpDouble(0.12, 0.0, t),
                scale: lerpDouble(0.95, 0.90, t),
                active: false,
              ),
              _animatedCityRow(
                city: currentCenter,
                top: lerpDouble(118, 38, t),
                opacity: lerpDouble(1.0, 0.12, t),
                scale: lerpDouble(1.0, 0.95, t),
                active: t < 0.5,
              ),
              _animatedCityRow(
                city: currentBottom,
                top: lerpDouble(198, 118, t),
                opacity: lerpDouble(0.12, 1.0, t),
                scale: lerpDouble(0.95, 1.0, t),
                active: t >= 0.5,
              ),
              _animatedCityRow(
                city: nextBottom,
                top: lerpDouble(278, 198, t),
                opacity: lerpDouble(0.0, 0.12, t),
                scale: lerpDouble(0.90, 0.95, t),
                active: false,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _animatedCityRow({
    required _CityData city,
    required double top,
    required double opacity,
    required double scale,
    required bool active,
  }) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: _CityRow(
            flag: city.flag,
            city: city.name,
            places: city.places,
            isCenter: active,
            textStyleBuilder: _montserrat,
          ),
        ),
      ),
    );
  }
}

class _CityData {
  final String name;
  final String flag;
  final String places;

  const _CityData({
    required this.name,
    required this.flag,
    required this.places,
  });
}

class _SpotData {
  final String name;
  final String subtitle;
  final double? lat;
  final double? lng;
  final String imageUrl;
  final List<String> categories;

  const _SpotData({
    required this.name,
    required this.subtitle,
    this.lat,
    this.lng,
    this.imageUrl = '',
    this.categories = const [],
  });
}

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

class _DiscoverSpotTile extends StatelessWidget {
  final int index;
  final _SpotData spot;
  final bool isSelected;
  final VoidCallback onTap;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) textStyleBuilder;

  const _DiscoverSpotTile({
    required this.index,
    required this.spot,
    required this.isSelected,
    required this.onTap,
    required this.textStyleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$index.',
                style: textStyleBuilder(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 72,
                color: const Color(0xFFF1F1F3),
                child: spot.imageUrl.isNotEmpty
                    ? Image.network(
                        spot.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _SpotFallbackIcon(
                            categories: spot.categories,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                          );
                        },
                      )
                    : _SpotFallbackIcon(
                        categories: spot.categories,
                      ),
              ),
            ),
            const SizedBox(width: 13),
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
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          spot.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyleBuilder(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    spot.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyleBuilder(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9A9A9F),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) textStyleBuilder;

  const _SearchResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.textStyleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textStyleBuilder(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textStyleBuilder(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String flag;
  final String city;
  final String places;
  final bool isCenter;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) textStyleBuilder;

  const _CityRow({
    required this.flag,
    required this.city,
    required this.places,
    required this.isCenter,
    required this.textStyleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        isCenter ? Colors.black : Colors.black.withOpacity(0.10);

    final Color subColor = isCenter
        ? Colors.black.withOpacity(0.45)
        : Colors.black.withOpacity(0.08);

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          Text(
            flag,
            style: TextStyle(
              fontSize: isCenter ? 34 : 30,
              color: textColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyleBuilder(
                fontSize: isCenter ? 42 : 38,
                fontWeight: FontWeight.w500,
                color: textColor,
                letterSpacing: -1.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            places,
            style: textStyleBuilder(
              fontSize: isCenter ? 16 : 15,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) textStyleBuilder;

  const _SearchButton({
    required this.onTap,
    required this.textStyleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, color: Colors.black, size: 24),
            const SizedBox(width: 10),
            Text(
              "Search",
              style: textStyleBuilder(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;
  final TextStyle Function({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) textStyleBuilder;

  const _ContinueButton({
    required this.onTap,
    required this.textStyleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Continue",
              style: textStyleBuilder(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, color: Colors.black, size: 24),
          ],
        ),
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

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const int dashCount = 10;
    const double strokeWidth = 3.2;

    final Paint paint = Paint()
      ..color = const Color(0xFFC23BD8)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - strokeWidth;

    for (int i = 0; i < dashCount; i++) {
      final double startAngle = (2 * math.pi / dashCount) * i;
      final double sweepAngle = (2 * math.pi / dashCount) * 0.42;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
