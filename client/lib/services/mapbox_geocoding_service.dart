import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trip_planner/services/mapbox_config.dart';

class MapboxGeocodedPlace {
  final double lat;
  final double lng;
  final String placeName;

  const MapboxGeocodedPlace({
    required this.lat,
    required this.lng,
    required this.placeName,
  });
}

class MapboxGeocodingService {
  static const String _baseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Searches a place name and returns better Mapbox coordinates.
  ///
  /// Example query:
  /// Nandanvan Zoo Raipur Chhattisgarh India
  ///
  /// Mapbox returns coordinates as:
  /// [longitude, latitude]
  static Future<MapboxGeocodedPlace?> searchPlace({
    required String query,
  }) async {
    final encodedQuery = Uri.encodeComponent(query.trim());

    if (encodedQuery.isEmpty) {
      return null;
    }

    final uri = Uri.parse(
      '$_baseUrl/$encodedQuery.json'
      '?country=in'
      '&limit=1'
      '&types=poi,address,place,locality,neighborhood'
      '&access_token=${MapboxConfig.accessToken}',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final features = data['features'];

      if (features is! List || features.isEmpty) {
        return null;
      }

      final firstFeature = features.first;

      if (firstFeature is! Map<String, dynamic>) {
        return null;
      }

      final center = firstFeature['center'];

      if (center is! List || center.length < 2) {
        return null;
      }

      final lng = _toDouble(center[0]);
      final lat = _toDouble(center[1]);

      if (lat == null || lng == null) {
        return null;
      }

      return MapboxGeocodedPlace(
        lat: lat,
        lng: lng,
        placeName: firstFeature['place_name']?.toString() ?? query,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }
}
