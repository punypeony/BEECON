import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:latlong2/latlong.dart';

class RouteGenerator {
  RouteGenerator._();

  static List<RouteModel> generateBgcRoutes({
    required RouteLocation origin,
    required RouteLocation destination,
  }) {
    final baseDistanceM = _estimateDistanceM(
      origin.lat,
      origin.lng,
      destination.lat,
      destination.lng,
    );

    return [
      _buildFastestRoute(origin, destination, baseDistanceM),
      _buildAccessibleRoute(origin, destination, baseDistanceM),
      _buildBalancedRoute(origin, destination, baseDistanceM),
    ];
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
    int baseDistanceM,
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

    final distanceM = (baseDistanceM * 0.85).round();
    final durationMin = (distanceM / 75).ceil().clamp(5, 45);

    return RouteModel(
      id: 'route-fastest-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.fastest,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
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
    int baseDistanceM,
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

    final distanceM = (baseDistanceM * 1.25).round();
    final durationMin = (distanceM / 65).ceil().clamp(8, 50);

    return RouteModel(
      id: 'route-accessible-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.accessible,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
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
    int baseDistanceM,
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

    final distanceM = baseDistanceM;
    final durationMin = (distanceM / 70).ceil().clamp(6, 45);

    return RouteModel(
      id: 'route-balanced-${origin.label.hashCode}-${destination.label.hashCode}',
      type: RouteType.balanced,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
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
