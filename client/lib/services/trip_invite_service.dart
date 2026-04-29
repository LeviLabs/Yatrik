import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripInviteService {
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    final code = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'YTR-$code';
  }

  static Future<String?> createTripInvite({
    required String placeName,
    required int totalDays,
    required List<Map<String, dynamic>> dayPlans,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final code = _generateInviteCode();

    int totalSpots = 0;
    final Map<String, dynamic> daysMap = {};

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

    await FirebaseFirestore.instance.collection('trip_invites').doc(code).set({
      'code': code,
      'ownerUid': user.uid,
      'ownerEmail': user.email,
      'placeName': placeName,
      'totalDays': totalDays,
      'totalSpots': totalSpots,
      'days': daysMap,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
    });

    return code;
  }

  static Future<Map<String, dynamic>?> getTripByInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();

    final doc = await FirebaseFirestore.instance
        .collection('trip_invites')
        .doc(cleanCode)
        .get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();

    if (data == null) {
      return null;
    }

    final expiresAt = data['expiresAt'];

    if (expiresAt is Timestamp) {
      if (DateTime.now().isAfter(expiresAt.toDate())) {
        return null;
      }
    }

    return data;
  }

  static Future<String?> importTripByInviteCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final inviteData = await getTripByInviteCode(code);

    if (inviteData == null) {
      return null;
    }

    final tripDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('trips')
        .doc();

    final savedTripId = tripDocRef.id;

    await tripDocRef.set({
      'savedTripId': savedTripId,
      'importedFromCode': inviteData['code'],
      'importedFromUid': inviteData['ownerUid'],
      'placeName': inviteData['placeName'] ?? '',
      'totalDays': inviteData['totalDays'] ?? 1,
      'totalSpots': inviteData['totalSpots'] ?? 0,
      'days': inviteData['days'] ?? {},
      'isManualSave': true,
      'isImportedTrip': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return savedTripId;
  }
}
