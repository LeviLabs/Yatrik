import 'dart:convert';
import 'package:flutter/services.dart';

// 1. The blueprint for your data
class Destination {
  final String name;
  final String subtitle;

  Destination({required this.name, required this.subtitle});

  // Converts a JSON map into a Destination object
  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
}

// 2. The global list that will hold your 120+ locations in RAM
List<Destination> globalDestinations = [];

// 3. The function that reads your assets/cities.json
Future<void> loadGlobalDestinations() async {
  try {
    // Read the string from assets
    final String response = await rootBundle.loadString('assets/cities.json');

    // Decode the string into a List
    final List<dynamic> data = json.decode(response);

    // Convert the List of Maps into a List of Destination objects
    globalDestinations =
        data.map((json) => Destination.fromJson(json)).toList();

    print(
        "✅ Successfully loaded ${globalDestinations.length} destinations into memory.");
  } catch (e) {
    print("❌ Failed to load destinations: $e");
  }
}
