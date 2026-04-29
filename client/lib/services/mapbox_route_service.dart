import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:trip_planner/services/mapbox_config.dart';

class MapboxRouteResult {
  final double distanceKm;
  final double durationMinutes;

  /// Route geometry coordinates in Mapbox format:
  /// [longitude, latitude]
  final List<List<double>> coordinates;

  const MapboxRouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.coordinates,
  });

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    }

    return '${distanceKm.toStringAsFixed(1)}km';
  }

  String get formattedDuration {
    final totalMinutes = durationMinutes.round();

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
}

class MapboxRouteService {
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  /// Get road route between two places using Mapbox Directions API.
  ///
  /// Mapbox needs coordinates in this order:
  /// longitude,latitude
  ///
  /// Example:
  /// fromLng,fromLat;toLng,toLat
  static Future<MapboxRouteResult?> getDrivingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/driving/'
      '$fromLng,$fromLat;$toLng,$toLat'
      '?geometries=geojson'
      '&overview=full'
      '&steps=false'
      '&access_token=${MapboxConfig.accessToken}',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final routes = data['routes'];

      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final firstRoute = routes.first;

      if (firstRoute is! Map<String, dynamic>) {
        return null;
      }

      final distanceRaw = firstRoute['distance'];
      final durationRaw = firstRoute['duration'];
      final geometry = firstRoute['geometry'];

      if (distanceRaw == null || durationRaw == null) {
        return null;
      }

      if (geometry is! Map<String, dynamic>) {
        return null;
      }

      final rawCoordinates = geometry['coordinates'];

      if (rawCoordinates is! List) {
        return null;
      }

      final coordinates = rawCoordinates
          .whereType<List>()
          .map<List<double>>((point) {
            if (point.length < 2) {
              return <double>[];
            }

            final lng = _toDouble(point[0]);
            final lat = _toDouble(point[1]);

            if (lng == null || lat == null) {
              return <double>[];
            }

            return <double>[lng, lat];
          })
          .where((point) => point.length == 2)
          .toList();

      return MapboxRouteResult(
        distanceKm: _toDouble(distanceRaw)! / 1000,
        durationMinutes: _toDouble(durationRaw)! / 60,
        coordinates: coordinates,
      );
    } catch (e) {
      return null;
    }
  }

  /// Optional walking route if you need it later.
  static Future<MapboxRouteResult?> getWalkingRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/walking/'
      '$fromLng,$fromLat;$toLng,$toLat'
      '?geometries=geojson'
      '&overview=full'
      '&steps=false'
      '&access_token=${MapboxConfig.accessToken}',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final routes = data['routes'];

      if (routes is! List || routes.isEmpty) {
        return null;
      }

      final firstRoute = routes.first;

      if (firstRoute is! Map<String, dynamic>) {
        return null;
      }

      final distanceRaw = firstRoute['distance'];
      final durationRaw = firstRoute['duration'];
      final geometry = firstRoute['geometry'];

      if (distanceRaw == null || durationRaw == null) {
        return null;
      }

      if (geometry is! Map<String, dynamic>) {
        return null;
      }

      final rawCoordinates = geometry['coordinates'];

      if (rawCoordinates is! List) {
        return null;
      }

      final coordinates = rawCoordinates
          .whereType<List>()
          .map<List<double>>((point) {
            if (point.length < 2) {
              return <double>[];
            }

            final lng = _toDouble(point[0]);
            final lat = _toDouble(point[1]);

            if (lng == null || lat == null) {
              return <double>[];
            }

            return <double>[lng, lat];
          })
          .where((point) => point.length == 2)
          .toList();

      return MapboxRouteResult(
        distanceKm: _toDouble(distanceRaw)! / 1000,
        durationMinutes: _toDouble(durationRaw)! / 60,
        coordinates: coordinates,
      );
    } catch (e) {
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
