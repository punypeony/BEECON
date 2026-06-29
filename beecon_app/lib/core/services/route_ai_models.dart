import 'package:beecon_app/core/data/bgc_context_data.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';

class Agent1Result {
  const Agent1Result({
    required this.recommendedRoute,
    required this.confidence,
    required this.reasoning,
    required this.warnings,
    this.failed = false,
  });

  final String recommendedRoute;
  final int confidence;
  final String reasoning;
  final List<String> warnings;
  final bool failed;

  factory Agent1Result.fallback() {
    return const Agent1Result(
      recommendedRoute: 'Most Accessible',
      confidence: 0,
      reasoning: 'Default recommendation',
      warnings: [],
      failed: true,
    );
  }
}

class Agent2Result {
  const Agent2Result({
    required this.finalRoute,
    required this.overridden,
    required this.overrideReason,
    required this.userInsight,
    required this.safetyIndicator,
    required this.eventDetected,
    required this.eventPenalty,
    this.failed = false,
    this.webSearchUsed = false,
    this.usedLocalFallback = false,
  });

  final String finalRoute;
  final bool overridden;
  final String? overrideReason;
  final String userInsight;
  final String safetyIndicator;
  final bool eventDetected;
  final int eventPenalty;
  final bool failed;
  final bool webSearchUsed;
  final bool usedLocalFallback;

  factory Agent2Result.fromAgent1(Agent1Result agent1) {
    return Agent2Result(
      finalRoute: agent1.recommendedRoute,
      overridden: false,
      overrideReason: null,
      userInsight: agent1.reasoning,
      safetyIndicator: 'Route appears safe',
      eventDetected: false,
      eventPenalty: 0,
      failed: true,
      usedLocalFallback: true,
    );
  }
}

class RouteAgentPipelineResult {
  const RouteAgentPipelineResult({
    required this.agent1,
    required this.agent2,
    required this.localContext,
    required this.recommendedRouteType,
  });

  final Agent1Result agent1;
  final Agent2Result agent2;
  final BgcLocalContext localContext;
  final RouteType recommendedRouteType;

  String get displayRouteLabel => agent2.finalRoute;

  bool get agentsFullyFailed => agent1.failed && agent2.failed;
}

enum RouteAiLoadingPhase {
  idle,
  calculatingRoutes,
  analyzingOptions,
  validatingLive,
  complete,
  error,
}

RouteType routeTypeFromLabel(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('fastest')) return RouteType.fastest;
  if (lower.contains('balanced')) return RouteType.balanced;
  return RouteType.accessible;
}

String routeLabelForType(RouteType type) {
  switch (type) {
    case RouteType.fastest:
      return 'Fastest Route';
    case RouteType.accessible:
      return 'Most Accessible Route';
    case RouteType.balanced:
      return 'Balanced Route';
  }
}

String agentRouteLabelForType(RouteType type) {
  switch (type) {
    case RouteType.fastest:
      return 'Fastest';
    case RouteType.accessible:
      return 'Most Accessible';
    case RouteType.balanced:
      return 'Balanced';
  }
}

/// Local recommendation without calling Gemini (avoids rate limits on page load).
RouteType heuristicRecommendedRoute(List<RouteModel> routes, String profile) {
  switch (profile) {
    case 'Wheelchair':
      return RouteType.accessible;
    case 'Senior Citizen':
    case 'Temporary Injury':
      return _bestBalancedShortRoute(routes);
    case 'Stroller':
    case 'Luggage':
      return RouteType.accessible;
    default:
      return _highestOverallRoute(routes);
  }
}

RouteType _highestOverallRoute(List<RouteModel> routes) {
  var best = routes.first;
  for (final route in routes.skip(1)) {
    if (route.overallScore > best.overallScore) best = route;
  }
  return best.type;
}

RouteType _bestBalancedShortRoute(List<RouteModel> routes) {
  final balanced = routes.firstWhere(
    (r) => r.type == RouteType.balanced,
    orElse: () => routes.first,
  );
  final accessible = routes.firstWhere(
    (r) => r.type == RouteType.accessible,
    orElse: () => routes.first,
  );
  return balanced.overallScore >= accessible.overallScore - 5
      ? RouteType.balanced
      : RouteType.accessible;
}

String heuristicRecommendationReason(RouteType type, String profile) {
  switch (profile) {
    case 'Wheelchair':
      return 'Highest accessibility priority for wheelchair users.';
    case 'Senior Citizen':
      return 'Balanced distance and accessibility for senior citizens.';
    case 'Stroller':
      return 'Smoothest surfaces and ramp-friendly path.';
    case 'Luggage':
      return 'Elevator access and smooth surfaces prioritized.';
    case 'Temporary Injury':
      return 'Shorter distance with fewer barriers.';
    default:
      return 'Best combined accessibility and safety score.';
  }
}
