import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // gemini-1.5-flash was deprecated; use a current model ID.
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const Duration _rateLimitRetryDelay = Duration(seconds: 2);

  DateTime? _lastCallAt;

  Future<String> getAccessibilityInsight({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
  }) async {
    await _applyDebounce();

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

    try {
      var response = await _postGenerateContent(apiKey, prompt);

      if (response.statusCode == 429) {
        await Future.delayed(_rateLimitRetryDelay);
        try {
          response = await _postGenerateContent(apiKey, prompt);
        } catch (_) {
          return _rateLimitFallback(accessibilityScore);
        }
        if (response.statusCode != 200) {
          return _rateLimitFallback(accessibilityScore);
        }
      } else if (response.statusCode != 200) {
        throw Exception(
          'Gemini API error: ${response.statusCode} — ${response.body}',
        );
      }

      return _parseResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _applyDebounce() async {
    final now = DateTime.now();
    if (_lastCallAt != null) {
      final elapsed = now.difference(_lastCallAt!);
      if (elapsed < _debounceDelay) {
        await Future.delayed(_debounceDelay - elapsed);
      }
    }
    _lastCallAt = DateTime.now();
  }

  String _rateLimitFallback(int score) =>
      'Accessibility score: $score/100. Please check route warnings before proceeding.';

  Future<http.Response> _postGenerateContent(String apiKey, String prompt) {
    return http.post(
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
  }

  String _parseResponse(http.Response response) {
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
