import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:latlong2/latlong.dart';

class RouteGenerator {
  RouteGenerator._();

  static const double _originLat = 14.5547;
  static const double _originLng = 121.0507;
  static const String defaultOriginName = 'High Street BGC';

  static List<RouteModel> generateBgcRoutes(BgcDestination destination) {
    final baseDistanceM = _estimateDistanceM(
      _originLat,
      _originLng,
      destination.lat,
      destination.lng,
    );

    return [
      _buildFastestRoute(destination, baseDistanceM),
      _buildAccessibleRoute(destination, baseDistanceM),
      _buildBalancedRoute(destination, baseDistanceM),
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
    BgcDestination destination,
    int baseDistanceM,
  ) {
    final segments = [
      _segment(
        1,
        _originLat,
        _originLng,
        [RouteSegmentFeature.stairs, RouteSegmentFeature.steepIncline],
      ),
      _segment(
        2,
        _midpoint(_originLat, destination.lat),
        _midpoint(_originLng, destination.lng),
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
      id: 'route-fastest-${destination.name.hashCode}',
      type: RouteType.fastest,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Includes stair-only shortcuts near $defaultOriginName.',
        'Construction zone along the direct path may block wheelchair access.',
        'Broken elevator reported on the direct path.',
        'Steep incline and narrow pathways along this route.',
        'Final approach to ${destination.name} may include stairs.',
      ],
    );
  }

  static RouteModel _buildAccessibleRoute(
    BgcDestination destination,
    int baseDistanceM,
  ) {
    final segments = [
      _segment(
        1,
        _originLat,
        _originLng,
        [
          RouteSegmentFeature.ramp,
          RouteSegmentFeature.smoothPavement,
          RouteSegmentFeature.accessibleEntrance,
        ],
      ),
      _segment(
        2,
        _midpoint(_originLat, destination.lat, factor: 0.35),
        _midpoint(_originLng, destination.lng, factor: 0.35),
        [
          RouteSegmentFeature.tactilePaving,
          RouteSegmentFeature.coveredWalkway,
          RouteSegmentFeature.smoothPavement,
        ],
      ),
      _segment(
        3,
        _midpoint(_originLat, destination.lat, factor: 0.65),
        _midpoint(_originLng, destination.lng, factor: 0.65),
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
      id: 'route-accessible-${destination.name.hashCode}',
      type: RouteType.accessible,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Longer walking distance than the fastest option.',
        'Some covered walkways may be crowded during peak hours.',
        'Accessible entrance available at ${destination.name}.',
      ],
    );
  }

  static RouteModel _buildBalancedRoute(
    BgcDestination destination,
    int baseDistanceM,
  ) {
    final segments = [
      _segment(
        1,
        _originLat,
        _originLng,
        [RouteSegmentFeature.steepIncline, RouteSegmentFeature.narrowPathway],
      ),
      _segment(
        2,
        _midpoint(_originLat, destination.lat, factor: 0.45),
        _midpoint(_originLng, destination.lng, factor: 0.45),
        [RouteSegmentFeature.ramp, RouteSegmentFeature.tactilePaving],
      ),
      _segment(
        3,
        _midpoint(_originLat, destination.lat, factor: 0.75),
        _midpoint(_originLng, destination.lng, factor: 0.75),
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
      id: 'route-balanced-${destination.name.hashCode}',
      type: RouteType.balanced,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: [
        'Moderate incline near the $defaultOriginName starting point.',
        'Temporary construction detour along part of the route.',
        'Final segment near ${destination.name} may include stairs.',
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
