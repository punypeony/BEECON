import 'package:beecon_app/features/routing/models/route_segment_model.dart';

class AccessibilityScorer {
  AccessibilityScorer._();

  static const int baseScore = 100;

  static int scoreSegment(List<RouteSegmentFeature> features) {
    var score = baseScore;
    for (final feature in features) {
      score += _adjustmentFor(feature);
    }
    return score.clamp(0, 100);
  }

  static int averageSegmentScore(List<RouteSegmentModel> segments) {
    if (segments.isEmpty) return 0;
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.segmentScore);
    return (total / segments.length).round();
  }

  static int _adjustmentFor(RouteSegmentFeature feature) {
    switch (feature) {
      case RouteSegmentFeature.ramp:
        return 15;
      case RouteSegmentFeature.elevator:
        return 20;
      case RouteSegmentFeature.smoothPavement:
        return 10;
      case RouteSegmentFeature.coveredWalkway:
        return 10;
      case RouteSegmentFeature.accessibleEntrance:
        return 15;
      case RouteSegmentFeature.tactilePaving:
        return 10;
      case RouteSegmentFeature.stairs:
        return -50;
      case RouteSegmentFeature.brokenElevator:
        return -30;
      case RouteSegmentFeature.construction:
        return -30;
      case RouteSegmentFeature.steepIncline:
        return -20;
      case RouteSegmentFeature.narrowPathway:
        return -15;
    }
  }
}
