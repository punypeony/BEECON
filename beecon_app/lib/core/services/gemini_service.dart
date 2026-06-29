import 'dart:convert';

import 'package:beecon_app/core/data/bgc_context_data.dart';
import 'package:beecon_app/core/services/route_ai_models.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:beecon_app/features/routing/services/safety_scorer.dart';
import 'package:flutter/foundation.dart';
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
  static const Duration _rateLimitRetryDelay = Duration(seconds: 3);
  static const Duration _interAgentDelay = Duration(seconds: 2);
  static const Duration _agentDebounce = Duration(milliseconds: 500);
  static const Duration _agentCacheTtl = Duration(minutes: 5);
  static const Duration _rateLimitCooldown = Duration(minutes: 10);

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

  String? _agentCacheKey;
  RouteAgentPipelineResult? _cachedAgentResult;
  DateTime? _agentCacheTime;
  String? _agentCacheProfile;

  final Map<String, Agent2Result> _selectedRouteCache = {};
  DateTime? _selectedRouteCacheTime;
  String? _selectedRouteCacheProfile;
  Future<Agent2Result>? _validateInFlight;
  String? _validateInFlightKey;
  DateTime? _rateLimitedUntil;

  /// True when a recent 429 forced local-only insights (no API calls).
  bool get isRateLimited =>
      _rateLimitedUntil != null &&
      DateTime.now().isBefore(_rateLimitedUntil!);

  void _markRateLimited() {
    _rateLimitedUntil = DateTime.now().add(_rateLimitCooldown);
    if (kDebugMode) {
      debugPrint(
        'GeminiService: rate limited — using local BGC insight for '
        '${_rateLimitCooldown.inMinutes} minutes',
      );
    }
  }

  bool _shouldCallGeminiApi() {
    if (dotenv.env['GEMINI_ENABLED']?.toLowerCase() == 'false') {
      return false;
    }
    if (isRateLimited) return false;
    final key = dotenv.env['GEMINI_API_KEY']?.trim();
    return key != null && key.isNotEmpty;
  }

  /// Offline insight from BGC context + scores — no API call.
  Agent2Result buildLocalSelectedRouteInsight({
    required RouteModel route,
    required String mobilityProfile,
    required String destination,
    required BgcLocalContext localContext,
  }) {
    final accessibilityScore = route.contextScore.adjustedScore;
    final safetyScore = route.safetyScore.finalScore;
    final eventDetected = localContext.matchedEvents.isNotEmpty;
    final penalty = eventDetected ? localContext.totalEventPenalty : 0;

    final conditions = localContext.localContextSummary ==
            'Typical BGC pedestrian conditions'
        ? 'Pedestrian conditions in BGC look typical for this time.'
        : localContext.localContextSummary;

    final profileTip = _profileTip(mobilityProfile, route.typeLabel);

    final userInsight =
        'Accessibility score: $accessibilityScore/100 and safety score: '
        '$safetyScore/100 on the ${route.typeLabel}. $conditions $profileTip';

    return Agent2Result(
      finalRoute: agentRouteLabelForType(route.type),
      overridden: false,
      overrideReason: null,
      userInsight: userInsight,
      safetyIndicator: _safetyIndicatorForScore(safetyScore),
      eventDetected: eventDetected,
      eventPenalty: penalty,
      usedLocalFallback: true,
    );
  }

  String _profileTip(String profile, String routeLabel) {
    switch (profile) {
      case 'Wheelchair':
        return 'Prefer ramps and elevator access; avoid stair shortcuts on $routeLabel.';
      case 'Senior Citizen':
        return 'Pace yourself and use shaded covered walkways where available.';
      case 'Stroller':
        return 'Watch for crowded sidewalks and keep to smoother pavement sections.';
      case 'Luggage':
        return 'Use elevator-equipped paths and avoid steep or narrow segments.';
      case 'Temporary Injury':
        return 'Minimize distance and rest at covered areas if needed.';
      default:
        return 'Stay aware of foot traffic and follow marked pedestrian lanes.';
    }
  }

  String _safetyIndicatorForScore(int safetyScore) {
    if (safetyScore >= 80) return 'Route appears safe';
    if (safetyScore >= 50) return 'Exercise caution';
    return 'Stay alert on this route';
  }

  void clearAgentCache() {
    _agentCacheKey = null;
    _cachedAgentResult = null;
    _agentCacheTime = null;
    _agentCacheProfile = null;
    _selectedRouteCache.clear();
    _selectedRouteCacheTime = null;
    _selectedRouteCacheProfile = null;
    _validateInFlight = null;
    _validateInFlightKey = null;
  }

  /// Validates a single user-selected route. One Gemini call, local BGC context
  /// only (no web search) to avoid rate limits. Cached per route for 5 minutes.
  Future<Agent2Result> validateSelectedRoute({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required RouteModel route,
  }) async {
    final cacheKey =
        '$origin::$destination::$mobilityProfile::${route.type.name}';
    final now = DateTime.now();

    if (_selectedRouteCacheProfile != null &&
        _selectedRouteCacheProfile != mobilityProfile) {
      _selectedRouteCache.clear();
    }

    final cached = _selectedRouteCache[cacheKey];
    if (cached != null &&
        _selectedRouteCacheTime != null &&
        now.difference(_selectedRouteCacheTime!) < _agentCacheTtl) {
      return cached;
    }

    if (_validateInFlightKey == cacheKey && _validateInFlight != null) {
      return _validateInFlight!;
    }

    _validateInFlightKey = cacheKey;
    _validateInFlight = _validateSelectedRouteOnce(
      cacheKey: cacheKey,
      mobilityProfile: mobilityProfile,
      origin: origin,
      destination: destination,
      route: route,
      now: now,
    );

    try {
      return await _validateInFlight!;
    } finally {
      if (_validateInFlightKey == cacheKey) {
        _validateInFlight = null;
        _validateInFlightKey = null;
      }
    }
  }

  Future<Agent2Result> _validateSelectedRouteOnce({
    required String cacheKey,
    required String mobilityProfile,
    required String origin,
    required String destination,
    required RouteModel route,
    required DateTime now,
  }) async {
    await Future.delayed(_agentDebounce);

    final localContext = BgcContextMatcher.match(
      now: now,
      destinationLabel: destination,
    );

    if (!_shouldCallGeminiApi()) {
      final local = buildLocalSelectedRouteInsight(
        route: route,
        mobilityProfile: mobilityProfile,
        destination: destination,
        localContext: localContext,
      );
      _selectedRouteCache[cacheKey] = local;
      _selectedRouteCacheTime = now;
      _selectedRouteCacheProfile = mobilityProfile;
      return local;
    }

    final result = await _fetchSelectedRouteFromApi(
      mobilityProfile: mobilityProfile,
      origin: origin,
      destination: destination,
      route: route,
      localContext: localContext,
      now: now,
    );

    _selectedRouteCache[cacheKey] = result;
    _selectedRouteCacheTime = now;
    _selectedRouteCacheProfile = mobilityProfile;

    return result;
  }

  Future<Agent2Result> _fetchSelectedRouteFromApi({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required RouteModel route,
    required BgcLocalContext localContext,
    required DateTime now,
  }) async {
    final day = _weekdays[now.weekday - 1];
    final time = _formatTime(now);
    final recommendedRoute = agentRouteLabelForType(route.type);

    try {
      final apiKey = _requireApiKey();
      final prompt = _localContextPrompt(
        mobilityProfile: mobilityProfile,
        origin: origin,
        destination: destination,
        recommendedRoute: recommendedRoute,
        reasoning: 'User selected ${route.typeLabel} for $mobilityProfile travel.',
        warnings: route.warnings,
        accessibilityScore: route.contextScore.adjustedScore,
        safetyScore: route.safetyScore.finalScore,
        localContext: localContext,
        day: day,
        time: time,
      );

      final response = await _postGenerateContent(
        apiKey,
        prompt,
        useWebSearch: false,
        maxOutputTokens: 512,
      );

      if (response.statusCode == 429) {
        _markRateLimited();
        return buildLocalSelectedRouteInsight(
          route: route,
          mobilityProfile: mobilityProfile,
          destination: destination,
          localContext: localContext,
        );
      }

      if (response.statusCode != 200) {
        _logGeminiFailure('Selected route', response);
        if (response.statusCode == 400 || response.statusCode == 403) {
          _markRateLimited();
        }
        return buildLocalSelectedRouteInsight(
          route: route,
          mobilityProfile: mobilityProfile,
          destination: destination,
          localContext: localContext,
        );
      }

      final text = _parseMultiBlockResponse(response);
      final json = _parseJsonFromText(text);
      if (json == null) {
        return buildLocalSelectedRouteInsight(
          route: route,
          mobilityProfile: mobilityProfile,
          destination: destination,
          localContext: localContext,
        );
      }

      final penalty = (json['eventPenalty'] as num?)?.toInt() ?? 0;
      final normalizedPenalty =
          penalty == 10 || penalty == 15 ? penalty : 0;

      return Agent2Result(
        finalRoute: json['finalRoute'] as String? ?? recommendedRoute,
        overridden: json['overridden'] as bool? ?? false,
        overrideReason: json['overrideReason'] as String?,
        userInsight: json['userInsight'] as String? ??
            buildLocalSelectedRouteInsight(
              route: route,
              mobilityProfile: mobilityProfile,
              destination: destination,
              localContext: localContext,
            ).userInsight,
        safetyIndicator: _normalizeSafetyIndicator(
          json['safetyIndicator'] as String?,
        ),
        eventDetected: json['eventDetected'] as bool? ?? false,
        eventPenalty: normalizedPenalty,
      );
    } catch (_) {
      return buildLocalSelectedRouteInsight(
        route: route,
        mobilityProfile: mobilityProfile,
        destination: destination,
        localContext: localContext,
      );
    }
  }

  Future<RouteAgentPipelineResult> runRouteAgentPipeline({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required List<RouteModel> routes,
    void Function(RouteAiLoadingPhase phase)? onPhase,
  }) async {
    final cacheKey = '$origin::$destination::$mobilityProfile';
    final now = DateTime.now();

    if (_agentCacheProfile != null &&
        _agentCacheProfile != mobilityProfile) {
      clearAgentCache();
    }

    if (_agentCacheKey == cacheKey &&
        _cachedAgentResult != null &&
        _agentCacheTime != null &&
        now.difference(_agentCacheTime!) < _agentCacheTtl) {
      return _cachedAgentResult!;
    }

    await Future.delayed(_agentDebounce);

    final localContext = BgcContextMatcher.match(
      now: now,
      destinationLabel: destination,
    );

    onPhase?.call(RouteAiLoadingPhase.analyzingOptions);

    final agent1 = await analyzeAndSelectRoute(
      mobilityProfile: mobilityProfile,
      origin: origin,
      destination: destination,
      routes: routes,
      localContext: localContext,
      now: now,
    );

    final recommendedType = routeTypeFromLabel(agent1.recommendedRoute);
    final recommendedRoute = routes.firstWhere(
      (r) => r.type == recommendedType,
      orElse: () => routes.firstWhere((r) => r.type == RouteType.accessible),
    );

    onPhase?.call(RouteAiLoadingPhase.validatingLive);

    await Future.delayed(_interAgentDelay);

    final agent2 = await validateAndEnrichRoute(
      mobilityProfile: mobilityProfile,
      origin: origin,
      destination: destination,
      recommendedRoute: agentRouteLabelForType(recommendedRoute.type),
      reasoning: agent1.reasoning,
      warnings: agent1.warnings,
      accessibilityScore: recommendedRoute.contextScore.adjustedScore,
      safetyScore: recommendedRoute.safetyScore.finalScore,
      localContext: localContext,
      now: now,
    );

    final finalType = agent2.overridden
        ? routeTypeFromLabel(agent2.finalRoute)
        : recommendedType;

    final result = RouteAgentPipelineResult(
      agent1: agent1,
      agent2: agent2,
      localContext: localContext,
      recommendedRouteType: finalType,
    );

    _agentCacheKey = cacheKey;
    _cachedAgentResult = result;
    _agentCacheTime = now;
    _agentCacheProfile = mobilityProfile;

    return result;
  }

  Future<Agent1Result> analyzeAndSelectRoute({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required List<RouteModel> routes,
    required BgcLocalContext localContext,
    required DateTime now,
  }) async {
    final day = _weekdays[now.weekday - 1];
    final time = _formatTime(now);
    final adjustments = localContext.adjustments.join('; ');

    RouteModel routeFor(RouteType type) =>
        routes.firstWhere((r) => r.type == type);

    final fastest = routeFor(RouteType.fastest);
    final accessible = routeFor(RouteType.accessible);
    final balanced = routeFor(RouteType.balanced);

    final prompt = """
You are Beecon's Route Decision Agent for
Bonifacio Global City, Philippines.

Analyze 3 route options and select the BEST 
one for this specific user. Do NOT always pick 
the most accessible. Reason based on all factors 
including the user's specific mobility needs,
current time conditions, and route trade-offs.

User mobility profile: $mobilityProfile
Origin: $origin  
Destination: $destination
Current day: $day
Current time: $time
Context adjustments: $adjustments
Local conditions: ${localContext.localContextSummary}

Route options:
1. Fastest Route
   Distance: ${fastest.distanceM}m
   Duration: ${fastest.durationMin} min
   Accessibility score: ${fastest.contextScore.adjustedScore}/100
   Safety score: ${fastest.safetyScore.finalScore}/100

2. Most Accessible Route
   Distance: ${accessible.distanceM}m
   Duration: ${accessible.durationMin} min
   Accessibility score: ${accessible.contextScore.adjustedScore}/100
   Safety score: ${accessible.safetyScore.finalScore}/100

3. Balanced Route
   Distance: ${balanced.distanceM}m
   Duration: ${balanced.durationMin} min
   Accessibility score: ${balanced.contextScore.adjustedScore}/100
   Safety score: ${balanced.safetyScore.finalScore}/100

Mobility profile routing priorities:
- Wheelchair: prioritize accessibility score 
  above all else, avoid steps at all costs
- Senior Citizen: balance accessibility and 
  shorter distance, avoid long walks
- Stroller: prioritize smooth surfaces and 
  ramp availability
- Luggage: prioritize smooth surfaces and 
  elevator access, distance secondary
- Temporary Injury: minimize barriers, 
  prefer shorter distance
- General: balance all factors equally

Respond ONLY in this exact JSON format,
no other text before or after:
{
  "recommendedRoute": "Most Accessible",
  "confidence": 92,
  "reasoning": "One sentence max",
  "warnings": ["warning 1", "warning 2"]
}
""";

    try {
      final apiKey = _requireApiKey();
      final response = await _generateWithRetry(
        apiKey: apiKey,
        prompt: prompt,
        useWebSearch: false,
        maxOutputTokens: 500,
      );

      if (response.statusCode != 200) {
        _logGeminiFailure('Agent 1', response);
        throw Exception('Agent 1 error: ${response.statusCode}');
      }

      final text = _parseResponse(response);
      final json = _parseJsonFromText(text);
      if (json == null) throw Exception('Invalid Agent 1 JSON');

      return Agent1Result(
        recommendedRoute: json['recommendedRoute'] as String? ?? 'Most Accessible',
        confidence: (json['confidence'] as num?)?.toInt() ?? 0,
        reasoning: json['reasoning'] as String? ?? 'Default recommendation',
        warnings: (json['warnings'] as List<dynamic>?)
                ?.map((w) => w.toString())
                .toList() ??
            [],
      );
    } catch (_) {
      return Agent1Result.fallback();
    }
  }

  Future<Agent2Result> validateAndEnrichRoute({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required String recommendedRoute,
    required String reasoning,
    required List<String> warnings,
    required int accessibilityScore,
    required int safetyScore,
    required BgcLocalContext localContext,
    required DateTime now,
    bool skipWebSearch = false,
  }) async {
    final day = _weekdays[now.weekday - 1];
    final time = _formatTime(now);

    if (skipWebSearch) {
      return _validateWithLocalContextOnly(
        mobilityProfile: mobilityProfile,
        origin: origin,
        destination: destination,
        recommendedRoute: recommendedRoute,
        reasoning: reasoning,
        warnings: warnings,
        accessibilityScore: accessibilityScore,
        safetyScore: safetyScore,
        localContext: localContext,
        day: day,
        time: time,
      );
    }

    final prompt = """
You are Beecon's Route Validation Agent for
Bonifacio Global City, Philippines.

Another AI agent recommended the $recommendedRoute
for a $mobilityProfile user going from $origin 
to $destination at $time on $day.

Agent 1 reasoning: $reasoning
Accessibility score: $accessibilityScore/100
Safety score: $safetyScore/100
Agent 1 warnings: ${warnings.join(', ')}

Known local context (use if web search finds nothing):
- Known events today: ${localContext.matchedEventsText}
- Rush hour: ${localContext.matchedRushHourText}
- Safety notes for destination: ${localContext.matchedSafetyText}

Search the web for:
1. Any BGC events or gatherings today that may
   affect pedestrian accessibility
2. Any safety advisories near BGC today  
3. Crowd conditions for $day at $time in BGC

Instructions:
- If web search finds real BGC events use those
- If web search finds nothing use the local 
  context data provided above
- Always have something specific to say about
  conditions — never say nothing was found

Then respond ONLY in this exact JSON format,
no other text before or after:
{
  "finalRoute": "Most Accessible",
  "overridden": false,
  "overrideReason": null,
  "userInsight": "3 sentence insight here. Mention the score, conditions, and one practical tip for this specific mobility profile.",
  "safetyIndicator": "Route appears safe",
  "eventDetected": false,
  "eventPenalty": 0
}

safetyIndicator must be one of:
"Route appears safe"
"Exercise caution"  
"Stay alert on this route"

eventPenalty must be 0, 10, or 15.
""";

    try {
      final apiKey = _requireApiKey();
      var webSearchUsed = false;

      var response = await _generateWithRetry(
        apiKey: apiKey,
        prompt: prompt,
        useWebSearch: true,
        maxOutputTokens: 1000,
      );

      if (response.statusCode == 400 || response.statusCode == 403) {
        _logGeminiFailure('Agent 2 web search', response);
        response = await _generateWithRetry(
          apiKey: apiKey,
          prompt: _localContextPrompt(
            mobilityProfile: mobilityProfile,
            origin: origin,
            destination: destination,
            recommendedRoute: recommendedRoute,
            reasoning: reasoning,
            warnings: warnings,
            accessibilityScore: accessibilityScore,
            safetyScore: safetyScore,
            localContext: localContext,
            day: day,
            time: time,
          ),
          useWebSearch: false,
          maxOutputTokens: 1000,
        );
      } else {
        webSearchUsed = response.statusCode == 200;
      }

      if (response.statusCode != 200) {
        _logGeminiFailure('Agent 2', response);
        throw Exception('Agent 2 error: ${response.statusCode}');
      }

      final text = _parseMultiBlockResponse(response);
      final json = _parseJsonFromText(text);
      if (json == null) throw Exception('Invalid Agent 2 JSON');

      final penalty = (json['eventPenalty'] as num?)?.toInt() ?? 0;
      final normalizedPenalty =
          penalty == 10 || penalty == 15 ? penalty : 0;

      return Agent2Result(
        finalRoute: json['finalRoute'] as String? ?? recommendedRoute,
        overridden: json['overridden'] as bool? ?? false,
        overrideReason: json['overrideReason'] as String?,
        userInsight: json['userInsight'] as String? ??
            _buildAgent2FallbackInsight(
              accessibilityScore: accessibilityScore,
              safetyScore: safetyScore,
              localContext: localContext,
            ),
        safetyIndicator: _normalizeSafetyIndicator(
          json['safetyIndicator'] as String?,
        ),
        eventDetected: json['eventDetected'] as bool? ?? false,
        eventPenalty: normalizedPenalty,
        webSearchUsed: webSearchUsed,
        usedLocalFallback: !webSearchUsed,
      );
    } catch (_) {
      return Agent2Result(
        finalRoute: recommendedRoute,
        overridden: false,
        overrideReason: null,
        userInsight: _buildAgent2FallbackInsight(
          accessibilityScore: accessibilityScore,
          safetyScore: safetyScore,
          localContext: localContext,
        ),
        safetyIndicator: safetyScore >= 80
            ? 'Route appears safe'
            : safetyScore >= 50
                ? 'Exercise caution'
                : 'Stay alert on this route',
        eventDetected: false,
        eventPenalty: 0,
        failed: true,
        usedLocalFallback: true,
      );
    }
  }

  Future<Agent2Result> _validateWithLocalContextOnly({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required String recommendedRoute,
    required String reasoning,
    required List<String> warnings,
    required int accessibilityScore,
    required int safetyScore,
    required BgcLocalContext localContext,
    required String day,
    required String time,
  }) async {
    try {
      final apiKey = _requireApiKey();
      final prompt = _localContextPrompt(
        mobilityProfile: mobilityProfile,
        origin: origin,
        destination: destination,
        recommendedRoute: recommendedRoute,
        reasoning: reasoning,
        warnings: warnings,
        accessibilityScore: accessibilityScore,
        safetyScore: safetyScore,
        localContext: localContext,
        day: day,
        time: time,
      );

      final response = await _generateWithRetry(
        apiKey: apiKey,
        prompt: prompt,
        useWebSearch: false,
        maxOutputTokens: 1000,
        maxRetries: 1,
      );

      if (response.statusCode != 200) {
        _logGeminiFailure('Agent 2 local', response);
        throw Exception('Agent 2 error: ${response.statusCode}');
      }

      final text = _parseMultiBlockResponse(response);
      final json = _parseJsonFromText(text);
      if (json == null) throw Exception('Invalid Agent 2 JSON');

      final penalty = (json['eventPenalty'] as num?)?.toInt() ?? 0;
      final normalizedPenalty =
          penalty == 10 || penalty == 15 ? penalty : 0;

      return Agent2Result(
        finalRoute: json['finalRoute'] as String? ?? recommendedRoute,
        overridden: json['overridden'] as bool? ?? false,
        overrideReason: json['overrideReason'] as String?,
        userInsight: json['userInsight'] as String? ??
            _buildAgent2FallbackInsight(
              accessibilityScore: accessibilityScore,
              safetyScore: safetyScore,
              localContext: localContext,
            ),
        safetyIndicator: _normalizeSafetyIndicator(
          json['safetyIndicator'] as String?,
        ),
        eventDetected: json['eventDetected'] as bool? ?? false,
        eventPenalty: normalizedPenalty,
        usedLocalFallback: true,
      );
    } catch (_) {
      return Agent2Result(
        finalRoute: recommendedRoute,
        overridden: false,
        overrideReason: null,
        userInsight: _buildAgent2FallbackInsight(
          accessibilityScore: accessibilityScore,
          safetyScore: safetyScore,
          localContext: localContext,
        ),
        safetyIndicator: safetyScore >= 80
            ? 'Route appears safe'
            : safetyScore >= 50
                ? 'Exercise caution'
                : 'Stay alert on this route',
        eventDetected: false,
        eventPenalty: 0,
        failed: true,
        usedLocalFallback: true,
      );
    }
  }

  String _localContextPrompt({
    required String mobilityProfile,
    required String origin,
    required String destination,
    required String recommendedRoute,
    required String reasoning,
    required List<String> warnings,
    required int accessibilityScore,
    required int safetyScore,
    required BgcLocalContext localContext,
    required String day,
    required String time,
  }) {
    return """
You are Beecon's Route Validation Agent for Bonifacio Global City, Philippines.

Another AI agent recommended the $recommendedRoute for a $mobilityProfile user
going from $origin to $destination at $time on $day.

Agent 1 reasoning: $reasoning
Accessibility score: $accessibilityScore/100
Safety score: $safetyScore/100
Agent 1 warnings: ${warnings.join(', ')}

Use this local BGC context (web search unavailable):
- Known events today: ${localContext.matchedEventsText}
- Rush hour: ${localContext.matchedRushHourText}
- Safety notes for destination: ${localContext.matchedSafetyText}

Always mention specific local conditions in your insight.

Respond ONLY in this exact JSON format, no other text before or after:
{
  "finalRoute": "$recommendedRoute",
  "overridden": false,
  "overrideReason": null,
  "userInsight": "3 sentence insight here. Mention the score, conditions, and one practical tip for this specific mobility profile.",
  "safetyIndicator": "Route appears safe",
  "eventDetected": false,
  "eventPenalty": 0
}

safetyIndicator must be one of:
"Route appears safe"
"Exercise caution"
"Stay alert on this route"

eventPenalty must be 0, 10, or 15.
""";
  }

  Future<http.Response> _generateWithRetry({
    required String apiKey,
    required String prompt,
    required bool useWebSearch,
    required int maxOutputTokens,
    int maxRetries = 0,
  }) async {
    final response = await _postGenerateContent(
      apiKey,
      prompt,
      useWebSearch: useWebSearch,
      maxOutputTokens: maxOutputTokens,
    );

    if (response.statusCode == 429) {
      _markRateLimited();
    }

    return response;
  }

  void _logGeminiFailure(String label, http.Response response) {
    if (!kDebugMode) return;
    final body = response.body;
    final snippet = body.length > 200 ? '${body.substring(0, 200)}...' : body;
    debugPrint(
      'GeminiService: $label failed (HTTP ${response.statusCode}): $snippet',
    );
  }

  String buildAgent2FallbackInsightPublic({
    required int accessibilityScore,
    required int safetyScore,
    required BgcLocalContext localContext,
  }) {
    return _buildAgent2FallbackInsight(
      accessibilityScore: accessibilityScore,
      safetyScore: safetyScore,
      localContext: localContext,
    );
  }

  String _buildAgent2FallbackInsight({
    required int accessibilityScore,
    required int safetyScore,
    required BgcLocalContext localContext,
  }) {
    final contextPart = localContext.localContextSummary ==
            'Typical BGC pedestrian conditions'
        ? ''
        : ' ${localContext.localContextSummary}.';
    return 'Accessibility score: $accessibilityScore/100. '
        'Safety score: $safetyScore/100.$contextPart '
        'AI validation temporarily unavailable.';
  }

  String _normalizeSafetyIndicator(String? value) {
    const allowed = [
      'Route appears safe',
      'Exercise caution',
      'Stay alert on this route',
    ];
    if (value != null && allowed.contains(value)) return value;
    return 'Route appears safe';
  }

  String _requireApiKey() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing GEMINI_API_KEY');
    }
    return apiKey;
  }

  String _formatTime(DateTime now) {
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  Map<String, dynamic>? _parseJsonFromText(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
      cleaned = cleaned.replaceAll(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(cleaned.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _parseMultiBlockResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    if (content == null) throw Exception('No content from Gemini');

    final parts = content['parts'] as List<dynamic>?;
    if (parts != null && parts.isNotEmpty) {
      final fullResponse = parts
          .map((item) {
            final map = item as Map<String, dynamic>;
            if (map['type'] == 'text' || map.containsKey('text')) {
              return map['text'] as String? ?? '';
            }
            return '';
          })
          .where((t) => t.isNotEmpty)
          .join(' ')
          .trim();
      if (fullResponse.isNotEmpty) return fullResponse;
    }

    return _parseResponse(response);
  }

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
    int maxOutputTokens = 1024,
  }) {
    final body = <String, dynamic>{
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': maxOutputTokens,
      },
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
