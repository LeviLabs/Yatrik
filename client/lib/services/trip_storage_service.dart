import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TripStorageService {
  static Future<String?> saveTrip({
    required String placeName,
    required int totalDays,
    required List<Map<String, dynamic>> dayPlans,
    bool isManualSave = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    debugPrint('FIREBASE SAVE USER UID: ${user?.uid}');
    debugPrint('FIREBASE SAVE USER EMAIL: ${user?.email}');

    if (user == null) {
      debugPrint('FIREBASE SAVE FAILED: User is null');
      return null;
    }

    try {
      final Map<String, dynamic> daysMap = {};

      int totalSpots = 0;

      for (final day in dayPlans) {
        final dayNumber = day['day']?.toString() ?? 'unknown';
        final rawSpots = day['spots'];

        final Map<String, dynamic> spotsMap = {};

        if (rawSpots is List) {
          totalSpots += rawSpots.length;

          for (int i = 0; i < rawSpots.length; i++) {
            final spot = rawSpots[i];

            if (spot is Map<String, dynamic>) {
              final rawCategories = spot['categories'];

              spotsMap['spot_${i + 1}'] = {
                'name': spot['name'] ?? '',
                'subtitle': spot['subtitle'] ?? '',
                'lat': spot['lat'] ?? 0.0,
                'lng': spot['lng'] ?? 0.0,
                'imageUrl': spot['imageUrl'] ?? '',
                'categories': rawCategories is List
                    ? rawCategories.map((e) => e.toString()).join(', ')
                    : rawCategories?.toString() ?? '',
              };
            }
          }
        }

        daysMap['day_$dayNumber'] = {
          'day': day['day'] ?? 0,
          'color': day['color'] ?? '',
          'spots': spotsMap,
        };
      }

      final tripDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('trips')
          .doc();

      final savedTripId = tripDocRef.id;

      await tripDocRef.set({
        'savedTripId': savedTripId,
        'placeName': placeName,
        'totalDays': totalDays,
        'totalSpots': totalSpots,
        'days': daysMap,
        'isManualSave': isManualSave,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('FIREBASE SAVE SUCCESS: $savedTripId');

      return savedTripId;
    } catch (e) {
      debugPrint('FIREBASE SAVE ERROR: $e');
      return null;
    }
  }
}
