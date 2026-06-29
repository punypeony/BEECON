import 'package:beecon_app/core/services/ors_route_result.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';
import 'package:beecon_app/features/routing/models/safety_score_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:beecon_app/features/routing/services/safety_scorer.dart';
import 'package:latlong2/latlong.dart';

class RouteGenerator {
  RouteGenerator._();

  static List<RouteModel> generateBgcRoutes({
    required RouteLocation origin,
    required RouteLocation destination,
    OrsRouteBundle? orsBundle,
  }) {
    final baseDistanceM = _estimateDistanceM(
      origin.lat,
      origin.lng,
      destination.lat,
      destination.lng,
    );

    return [
      _buildFastestRoute(
        origin,
        destination,
        _distanceM(orsBundle?.fastest, baseDistanceM, factor: 0.85),
        _durationMin(orsBundle?.fastest, baseDistanceM, factor: 0.85, speed: 75),
      ),
      _buildAccessibleRoute(
        origin,
        destination,
        _distanceM(orsBundle?.accessible, baseDistanceM, factor: 1.25),
        _durationMin(orsBundle?.accessible, baseDistanceM, factor: 1.25, speed: 65),
      ),
      _buildBalancedRoute(
        origin,
        destination,
        _distanceM(orsBundle?.balanced, baseDistanceM, factor: 1.0),
        _durationMin(orsBundle?.balanced, baseDistanceM, factor: 1.0, speed: 70),
      ),
    ];
  }

  static int _distanceM(
    OrsRouteResult? ors,
    int baseDistanceM, {
    required double factor,
  }) {
    if (ors != null && ors.distanceM > 0) {
      return ors.distanceM.round().clamp(200, 8000);
    }
    return (baseDistanceM * factor).round();
  }

  static int _durationMin(
    OrsRouteResult? ors,
    int baseDistanceM, {
    required double factor,
    required int speed,
  }) {
    if (ors != null && ors.durationMin > 0) {
      return ors.durationMin.round().clamp(5, 90);
    }
    return ((baseDistanceM * factor) / speed).ceil().clamp(5, 90);
  }

  static int _estimateDistanceM(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    const distance = Distance();
    return distance
        .as(
          LengthUnit.Meter,
          LatLng(originLat, originLng),
          LatLng(destLat, destLng),
        )
        .round()
        .clamp(200, 5000);
  }

  static RouteModel _buildFastestRoute(
    RouteLocation origin,
    RouteLocation destination,
    int distanceM,
    int durationMin,
  ) {
    final segments = [
      _segment(
        1,
        origin.lat,
        origin.lng,
        [RouteSegmentFeature.stairs, RouteSegmentFeature.steepIncline],
      ),
      _segment(
        2,
        _midpoint(origin.lat, destination.lat),
        _midpoint(origin.lng, destination.lng),
        [
          RouteSegmentFeature.construction,
          RouteSegmentFeature.narrowPathway,
          RouteSegmentFeature.brokenElevator,
        ],
      ),
      _segment(
        3,
        destination.lat,
        destination.lng,
        [RouteSegmentFeature.stairs],
      ),
    ];

    final baseScore = AccessibilityScorer.averageSegmentScore(segments);
    final contextScore = AccessibilityScorer.buildContextScore(baseScore);
    final safetyScore = _buildSafetyScore(origin, destination);

    return RouteModel(
      id: 'route-fastest-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.fastest,
      segments: segments,
      baseScore: baseScore,
      contextScore: contextScore,
      safetyScore: safetyScore,
      totalScore: contextScore.adjustedScore,
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Includes stair-only shortcuts near ${origin.label}.',
        'Construction zone along the direct path may block wheelchair access.',
        'Broken elevator reported on the direct path.',
        'Steep incline and narrow pathways along this route.',
        'Final approach to ${destination.label} may include stairs.',
      ],
    );
  }

  static RouteModel _buildAccessibleRoute(
    RouteLocation origin,
    RouteLocation destination,
    int distanceM,
    int durationMin,
  ) {
    final segments = [
      _segment(
        1,
        origin.lat,
        origin.lng,
        [
          RouteSegmentFeature.ramp,
          RouteSegmentFeature.smoothPavement,
          RouteSegmentFeature.accessibleEntrance,
        ],
      ),
      _segment(
        2,
        _midpoint(origin.lat, destination.lat, factor: 0.35),
        _midpoint(origin.lng, destination.lng, factor: 0.35),
        [
          RouteSegmentFeature.tactilePaving,
          RouteSegmentFeature.coveredWalkway,
          RouteSegmentFeature.smoothPavement,
        ],
      ),
      _segment(
        3,
        _midpoint(origin.lat, destination.lat, factor: 0.65),
        _midpoint(origin.lng, destination.lng, factor: 0.65),
        [RouteSegmentFeature.ramp, RouteSegmentFeature.elevator],
      ),
      _segment(
        4,
        destination.lat,
        destination.lng,
        [
          RouteSegmentFeature.elevator,
          RouteSegmentFeature.accessibleEntrance,
          RouteSegmentFeature.tactilePaving,
        ],
      ),
    ];

    final baseScore = AccessibilityScorer.averageSegmentScore(segments);
    final contextScore = AccessibilityScorer.buildContextScore(baseScore);
    final safetyScore = _buildSafetyScore(origin, destination);

    return RouteModel(
      id: 'route-accessible-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.accessible,
      segments: segments,
      baseScore: baseScore,
      contextScore: contextScore,
      safetyScore: safetyScore,
      totalScore: contextScore.adjustedScore,
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Longer walking distance than the fastest option.',
        'Some covered walkways may be crowded during peak hours.',
        'Accessible entrance available at ${destination.label}.',
      ],
    );
  }

  static RouteModel _buildBalancedRoute(
    RouteLocation origin,
    RouteLocation destination,
    int distanceM,
    int durationMin,
  ) {
    final segments = [
      _segment(
        1,
        origin.lat,
        origin.lng,
        [RouteSegmentFeature.steepIncline, RouteSegmentFeature.narrowPathway],
      ),
      _segment(
        2,
        _midpoint(origin.lat, destination.lat, factor: 0.45),
        _midpoint(origin.lng, destination.lng, factor: 0.45),
        [RouteSegmentFeature.ramp, RouteSegmentFeature.tactilePaving],
      ),
      _segment(
        3,
        _midpoint(origin.lat, destination.lat, factor: 0.75),
        _midpoint(origin.lng, destination.lng, factor: 0.75),
        [RouteSegmentFeature.brokenElevator, RouteSegmentFeature.construction],
      ),
      _segment(
        4,
        destination.lat,
        destination.lng,
        [RouteSegmentFeature.smoothPavement, RouteSegmentFeature.stairs],
      ),
    ];

    final baseScore = AccessibilityScorer.averageSegmentScore(segments);
    final contextScore = AccessibilityScorer.buildContextScore(baseScore);
    final safetyScore = _buildSafetyScore(origin, destination);

    return RouteModel(
      id: 'route-balanced-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.balanced,
      segments: segments,
      baseScore: baseScore,
      contextScore: contextScore,
      safetyScore: safetyScore,
      totalScore: contextScore.adjustedScore,
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Moderate incline near the ${origin.label} starting point.',
        'Temporary construction detour along part of the route.',
        'Final segment near ${destination.label} may include stairs.',
      ],
    );
  }

  static double _midpoint(double start, double end, {double factor = 0.5}) {
    return start + (end - start) * factor;
  }

  static SafetyScoreModel _buildSafetyScore(
    RouteLocation origin,
    RouteLocation destination,
  ) {
    final midLat = _midpoint(origin.lat, destination.lat);
    final midLng = _midpoint(origin.lng, destination.lng);

    return SafetyScorer.buildSafetyScore(
      midLat: midLat,
      midLng: midLng,
      originLabel: origin.label,
      destinationLabel: destination.label,
    );
  }

  static RouteSegmentModel _segment(
    int sequence,
    double lat,
    double lng,
    List<RouteSegmentFeature> features,
  ) {
    return RouteSegmentModel(
      sequence: sequence,
      lat: lat,
      lng: lng,
      features: features,
      segmentScore: AccessibilityScorer.scoreSegment(features),
    );
  }
}
