import 'dart:convert';

import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiInsightResult {
  const GeminiInsightResult({
    required this.text,
    required this.eventDetected,
    required this.webSearchUsed,
  });

  final String text;
  final bool eventDetected;
  final bool webSearchUsed;
}

class GeminiService {
  static const String _model = 'gemini-2.0-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const Duration _preCallDelay = Duration(seconds: 1);
  static const Duration _rateLimitRetryDelay = Duration(seconds: 2);

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String? _cacheKey;
  GeminiInsightResult? _cachedResponse;

  Future<GeminiInsightResult> getAccessibilityInsight({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
    List<String> timeAdjustmentReasons = const [],
  }) async {
    final now = DateTime.now();
    final cacheKey = _buildCacheKey(
      mobilityProfile: mobilityProfile,
      routeType: routeType,
      accessibilityScore: accessibilityScore,
      warnings: warnings,
      origin: origin,
      destination: destination,
      dayKey: '${now.year}-${now.month}-${now.day}-${now.hour}',
    );

    if (_cacheKey == cacheKey && _cachedResponse != null) {
      return _cachedResponse!;
    }

    await Future.delayed(_preCallDelay);

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }

    final prompt = _buildPrompt(
      mobilityProfile: mobilityProfile,
      routeType: routeType,
      accessibilityScore: accessibilityScore,
      warnings: warnings,
      origin: origin,
      destination: destination,
      now: now,
    );

    try {
      var response = await _postGenerateContent(apiKey, prompt, useWebSearch: true);

      if (response.statusCode == 429) {
        await Future.delayed(_rateLimitRetryDelay);
        response = await _postGenerateContent(apiKey, prompt, useWebSearch: true);
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Gemini API error: ${response.statusCode}',
        );
      }

      final text = _parseResponse(response);
      final eventDetected = AccessibilityScorer.detectEventActivity(text);
      final result = GeminiInsightResult(
        text: text,
        eventDetected: eventDetected,
        webSearchUsed: true,
      );

      _cacheKey = cacheKey;
      _cachedResponse = result;
      return result;
    } catch (_) {
      return GeminiInsightResult(
        text: buildFallbackInsight(
          adjustedScore: accessibilityScore,
          mobilityProfile: mobilityProfile,
          timeAdjustmentReasons: timeAdjustmentReasons,
        ),
        eventDetected: false,
        webSearchUsed: false,
      );
    }
  }

  String buildFallbackInsight({
    required int adjustedScore,
    required String mobilityProfile,
    required List<String> timeAdjustmentReasons,
  }) {
    final reasonText = timeAdjustmentReasons.isEmpty
        ? ''
        : '${timeAdjustmentReasons.join('. ')}.';
    return 'Score: $adjustedScore/100 for $mobilityProfile profile.'
        '${reasonText.isNotEmpty ? ' $reasonText' : ''} '
        'AI web search temporarily unavailable.';
  }

  String _buildPrompt({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
    required DateTime now,
  }) {
    final dayOfWeek = _weekdays[now.weekday - 1];
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final time = '$displayHour:$minute $period';

    return """
You are Beecon, an AI accessibility navigation assistant
for Bonifacio Global City (BGC), Taguig, Philippines.

User mobility profile: $mobilityProfile
Route: $origin to $destination
Route type: $routeType
Base accessibility score: $accessibilityScore/100
Detected warnings: ${warnings.join(', ')}
Current date and time: $dayOfWeek, $date at $time

First, search the web for:
1. Any events, festivals, concerts, or gatherings
   happening in BGC today that may affect pedestrian
   accessibility or crowd levels
2. Any road closures or construction updates in BGC

Then give a context-aware accessibility insight in
maximum 3 sentences:
- Mention the score and what it means for this profile
- Mention any relevant events or crowd conditions found
- Give one practical tip for this specific user

If no events are found just focus on the route
and time-of-day crowd patterns.
Keep it friendly and direct.
""";
  }

  String _buildCacheKey({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required List<String> warnings,
    required String origin,
    required String destination,
    required String dayKey,
  }) {
    return [
      mobilityProfile,
      routeType,
      accessibilityScore,
      origin,
      destination,
      warnings.join('|'),
      dayKey,
    ].join('::');
  }

  Future<http.Response> _postGenerateContent(
    String apiKey,
    String prompt, {
    required bool useWebSearch,
  }) {
    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    };

    if (useWebSearch) {
      body['tools'] = [
        {
          'type': 'web_search_20250305',
          'name': 'web_search',
        },
      ];
    }

    return http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  String _parseResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    if (content == null) {
      throw Exception('No content from Gemini');
    }

    final parts = content['parts'] as List<dynamic>?;
    if (parts != null && parts.isNotEmpty) {
      final textBlocks = parts
          .map((part) {
            final map = part as Map<String, dynamic>;
            return map['text'] as String? ?? '';
          })
          .where((text) => text.isNotEmpty)
          .join(' ')
          .trim();

      if (textBlocks.isNotEmpty) return textBlocks;
    }

    throw Exception('Empty response from Gemini');
  }
}
