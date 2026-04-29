import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedTripsSheet extends StatelessWidget {
  const SavedTripsSheet({super.key});

  List<_SavedSpotItem> _extractSpots(Map<String, dynamic> tripData) {
    final List<_SavedSpotItem> spots = [];
    final days = tripData['days'];

    if (days is Map) {
      final dayEntries = days.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

      for (final dayEntry in dayEntries) {
        final dayData = dayEntry.value;

        if (dayData is Map) {
          final rawSpots = dayData['spots'];

          if (rawSpots is Map) {
            final spotEntries = rawSpots.entries.toList()
              ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

            for (final spotEntry in spotEntries) {
              final spotData = spotEntry.value;

              if (spotData is Map) {
                spots.add(
                  _SavedSpotItem(
                    name: (spotData['name'] ?? 'Unknown Spot').toString(),
                    imageUrl: (spotData['imageUrl'] ?? '').toString(),
                  ),
                );
              }
            }
          }
        }
      }
    }

    return spots;
  }

  int _getTotalSavedSpots(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int total = 0;

    for (final doc in docs) {
      final data = doc.data();
      final totalSpots = data['totalSpots'];

      if (totalSpots is int) {
        total += totalSpots;
      } else {
        total += _extractSpots(data).length;
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
      child: user == null
          ? _buildEmptySavedState()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('trips')
                  .where('isManualSave', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptySavedState();
                }

                final totalSavedSpots = _getTotalSavedSpots(docs);

                return CustomScrollView(
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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'My Saved',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalSavedSpots Spots Saved',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 44),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final trip = docs[index].data();
                          final placeName =
                              (trip['placeName'] ?? 'Saved Trip').toString();
                          final totalSpots = trip['totalSpots'] is int
                              ? trip['totalSpots'] as int
                              : _extractSpots(trip).length;
                          final spots = _extractSpots(trip);

                          return _SavedTripSection(
                            placeName: placeName,
                            totalSpots: totalSpots,
                            spots: spots,
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 130),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildEmptySavedState() {
    return Column(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'My Saved',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.8,
              ),
            ),
          ),
        ),
        const Spacer(),
        Icon(
          Icons.bookmark_border_rounded,
          size: 82,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 18),
        const Text(
          'No saved trips yet',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Saved trip plans will appear here',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _SavedTripSection extends StatelessWidget {
  final String placeName;
  final int totalSpots;
  final List<_SavedSpotItem> spots;

  const _SavedTripSection({
    required this.placeName,
    required this.totalSpots,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  placeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Text(
                '$totalSpots ${totalSpots == 1 ? 'Spot' : 'Spots'}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: spots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final spot = spots[index];

                return SizedBox(
                  width: 238,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 238,
                          height: 156,
                          color: const Color(0xFFF1F1F3),
                          child: spot.imageUrl.isNotEmpty
                              ? Image.network(
                                  spot.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const _SavedSpotFallback();
                                  },
                                )
                              : const _SavedSpotFallback(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        spot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.06,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
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

class _SavedSpotFallback extends StatelessWidget {
  const _SavedSpotFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.place_outlined,
        color: Colors.grey.shade500,
        size: 36,
      ),
    );
  }
}

class _SavedSpotItem {
  final String name;
  final String imageUrl;

  const _SavedSpotItem({
    required this.name,
    required this.imageUrl,
  });
}
