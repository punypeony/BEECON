import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // gemini-1.5-flash was deprecated; use a current model ID.
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<String> getAccessibilityInsight({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    final prompt = """
You are Beecon, an AI accessibility navigation assistant 
focused on Bonifacio Global City, Philippines.

User profile: $mobilityProfile
Route: $origin to $destination
Route type: $routeType
Accessibility score: $accessibilityScore out of 100
Detected warnings: ${warnings.join(', ')}

Give a short, friendly, context-aware accessibility assessment 
for this specific user profile. Maximum 3 sentences.
Mention specific hazards and give one practical tip.
""";

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      final body = response.body;
      throw Exception('Gemini API error: ${response.statusCode} — $body');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates.first['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    final text = parts.first['text'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    return text.trim();
  }
}
