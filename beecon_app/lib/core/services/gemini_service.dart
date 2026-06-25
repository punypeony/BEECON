import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const Duration _preCallDelay = Duration(seconds: 1);
  static const Duration _rateLimitRetryDelay = Duration(seconds: 2);

  String? _cacheKey;
  String? _cachedResponse;

  Future<String> getAccessibilityInsight({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
  }) async {
    final cacheKey = _buildCacheKey(
      mobilityProfile: mobilityProfile,
      routeType: routeType,
      accessibilityScore: accessibilityScore,
      warnings: warnings,
      origin: origin,
      destination: destination,
    );

    if (_cacheKey == cacheKey && _cachedResponse != null) {
      return _cachedResponse!;
    }

    await Future.delayed(_preCallDelay);

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
        if (response.statusCode == 429 || response.statusCode != 200) {
          return _rateLimitFallback(accessibilityScore);
        }
      } else if (response.statusCode != 200) {
        throw Exception(
          'Gemini API error: ${response.statusCode} — ${response.body}',
        );
      }

      final text = _parseResponse(response);
      _cacheKey = cacheKey;
      _cachedResponse = text;
      return text;
    } catch (e) {
      rethrow;
    }
  }

  String _buildCacheKey({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
  }) {
    return [
      mobilityProfile,
      routeType,
      accessibilityScore,
      origin,
      destination,
      warnings.join('|'),
    ].join('::');
  }

  String _rateLimitFallback(int score) =>
      'Route scored $score/100. AI insight temporarily unavailable.';

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
