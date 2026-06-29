import 'dart:convert';

import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:beecon_app/features/routing/services/safety_scorer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiInsightResult {
  const GeminiInsightResult({
    required this.text,
    required this.accessibilityInsight,
    required this.safetyTip,
    required this.eventDetected,
    required this.safetyAdvisoryDetected,
    required this.webSearchUsed,
  });

  final String text;
  final String accessibilityInsight;
  final String safetyTip;
  final bool eventDetected;
  final bool safetyAdvisoryDetected;
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
    required int safetyScore,
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
      safetyScore: safetyScore,
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
      safetyScore: safetyScore,
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
      final parsed = _parseInsightSections(text);
      final eventDetected = AccessibilityScorer.detectEventActivity(text);
      final safetyAdvisoryDetected = SafetyScorer.detectSafetyAdvisory(text);

      final result = GeminiInsightResult(
        text: text,
        accessibilityInsight: parsed.accessibility,
        safetyTip: parsed.safety,
        eventDetected: eventDetected,
        safetyAdvisoryDetected: safetyAdvisoryDetected,
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
          safetyScore: safetyScore,
          timeAdjustmentReasons: timeAdjustmentReasons,
        ),
        accessibilityInsight: buildFallbackAccessibilityInsight(
          adjustedScore: accessibilityScore,
          mobilityProfile: mobilityProfile,
          timeAdjustmentReasons: timeAdjustmentReasons,
        ),
        safetyTip: buildFallbackSafetyTip(safetyScore, mobilityProfile),
        eventDetected: false,
        safetyAdvisoryDetected: false,
        webSearchUsed: false,
      );
    }
  }

  String buildFallbackInsight({
    required int adjustedScore,
    required String mobilityProfile,
    required int safetyScore,
    required List<String> timeAdjustmentReasons,
  }) {
    return '${buildFallbackAccessibilityInsight(
      adjustedScore: adjustedScore,
      mobilityProfile: mobilityProfile,
      timeAdjustmentReasons: timeAdjustmentReasons,
    )} ${buildFallbackSafetyTip(safetyScore, mobilityProfile)}';
  }

  String buildFallbackAccessibilityInsight({
    required int adjustedScore,
    required String mobilityProfile,
    required List<String> timeAdjustmentReasons,
  }) {
    final reasonText = timeAdjustmentReasons.isEmpty
        ? ''
        : '${timeAdjustmentReasons.join('. ')}.';
    return 'Accessibility score: $adjustedScore/100 for $mobilityProfile profile.'
        '${reasonText.isNotEmpty ? ' $reasonText' : ''} '
        'AI web search temporarily unavailable.';
  }

  String buildFallbackSafetyTip(int safetyScore, String mobilityProfile) {
    if (safetyScore >= 80) {
      return 'Route appears safe for $mobilityProfile users at this time.';
    }
    if (safetyScore >= 50) {
      return 'Exercise caution — stay aware of surroundings on this route.';
    }
    return 'Stay alert — consider traveling with a companion if possible.';
  }

  String _buildPrompt({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required int safetyScore,
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
Safety score: $safetyScore/100
Detected warnings: ${warnings.join(', ')}
Current date and time: $dayOfWeek, $date at $time

First, search the web for:
1. Any events, festivals, concerts, or gatherings
   happening in BGC today that may affect pedestrian
   accessibility or crowd levels
2. Any road closures or construction updates in BGC
3. Recent crime reports or safety incidents in BGC
4. Any unsafe areas or advisories in BGC today
5. Street lighting conditions along major BGC roads

Then respond in exactly this format:

ACCESSIBILITY: (max 2 sentences — mention the accessibility score,
what it means for this profile, and any events or crowd conditions)

SAFETY: (one practical safety tip based on web search results;
if nothing concerning is found, confirm the route appears safe
for $mobilityProfile users)

Based on what you find, add one safety tip to your insight.
If nothing concerning is found, confirm the route appears safe
for $mobilityProfile.
Keep it friendly and direct.
""";
  }

  ({String accessibility, String safety}) _parseInsightSections(String text) {
    final accessibilityMatch = RegExp(
      r'ACCESSIBILITY:\s*(.*?)(?=SAFETY:|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    final safetyMatch = RegExp(
      r'SAFETY:\s*(.*)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);

    if (accessibilityMatch != null && safetyMatch != null) {
      return (
        accessibility: accessibilityMatch.group(1)!.trim(),
        safety: safetyMatch.group(1)!.trim(),
      );
    }

    return (
      accessibility: text.trim(),
      safety: 'Stay aware of your surroundings while traveling.',
    );
  }

  String _buildCacheKey({
    required String mobilityProfile,
    required String routeType,
    required int accessibilityScore,
    required int safetyScore,
    required List<String> warnings,
    required String origin,
    required String destination,
    required String dayKey,
  }) {
    return [
      mobilityProfile,
      routeType,
      accessibilityScore,
      safetyScore,
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
