import 'dart:convert';
import 'package:http/http.dart' as http;

class TripApi {
  static const String baseUrl = "https://yatrik.onrender.com";

  static Future<Map<String, dynamic>> sendTripInput({
    required String city,
    required String state,
    required int days,
    required List<String> preferences,
  }) async {
    final url = Uri.parse("$baseUrl/recommend");

    final body = {
      "City": city,
      "State": state,
      "Days": days,
      "Is_Museum": preferences.contains("Museum") ? 1 : 0,
      "Is_Nature": preferences.contains("Nature") ? 1 : 0,
      "Is_Beach": preferences.contains("Beach") ? 1 : 0,
      "Is_History": preferences.contains("History") ? 1 : 0,
      "Is_Temple": preferences.contains("Temple") ? 1 : 0,
      "Is_Wildlife": preferences.contains("Wildlife") ? 1 : 0,
      "Is_Shopping": preferences.contains("Shopping") ? 1 : 0,
      "Is_Foodie": preferences.contains("Foodie") ? 1 : 0,
    };

    print("Sending to backend: $body");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    print("Backend status: ${response.statusCode}");
    print("Backend response: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Backend error: ${response.body}");
    }
  }
}
