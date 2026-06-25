import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';

class RouteGenerator {
  RouteGenerator._();

  static List<RouteModel> generateBgcRoutes() {
    return [
      _buildFastestRoute(),
      _buildAccessibleRoute(),
      _buildBalancedRoute(),
    ];
  }

  static RouteModel _buildFastestRoute() {
    final segments = [
      _segment(
        1,
        14.5512,
        121.0489,
        [RouteSegmentFeature.stairs, RouteSegmentFeature.steepIncline],
      ),
      _segment(
        2,
        14.5494,
        121.0555,
        [
          RouteSegmentFeature.construction,
          RouteSegmentFeature.narrowPathway,
          RouteSegmentFeature.brokenElevator,
        ],
      ),
      _segment(
        3,
        14.5467,
        121.0534,
        [RouteSegmentFeature.stairs],
      ),
    ];

    return RouteModel(
      id: 'route-fastest',
      type: RouteType.fastest,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: 850,
      durationMin: 11,
      warnings: [
        'Includes stair-only shortcuts near High Street.',
        'Construction zone at Market! Market! may block wheelchair access.',
        'Broken elevator reported on the direct path.',
        'Steep incline and narrow pathways along this route.',
      ],
    );
  }

  static RouteModel _buildAccessibleRoute() {
    final segments = [
      _segment(
        1,
        14.5512,
        121.0489,
        [
          RouteSegmentFeature.ramp,
          RouteSegmentFeature.smoothPavement,
          RouteSegmentFeature.accessibleEntrance,
        ],
      ),
      _segment(
        2,
        14.5517,
        121.0446,
        [
          RouteSegmentFeature.tactilePaving,
          RouteSegmentFeature.coveredWalkway,
          RouteSegmentFeature.smoothPavement,
        ],
      ),
      _segment(
        3,
        14.5586,
        121.0478,
        [RouteSegmentFeature.ramp, RouteSegmentFeature.elevator],
      ),
      _segment(
        4,
        14.5488,
        121.0548,
        [RouteSegmentFeature.elevator, RouteSegmentFeature.coveredWalkway],
      ),
      _segment(
        5,
        14.5467,
        121.0534,
        [
          RouteSegmentFeature.elevator,
          RouteSegmentFeature.accessibleEntrance,
          RouteSegmentFeature.tactilePaving,
        ],
      ),
    ];

    return RouteModel(
      id: 'route-accessible',
      type: RouteType.accessible,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: 1200,
      durationMin: 18,
      warnings: [
        'Longer walking distance than the fastest option.',
        'Some covered walkways may be crowded during peak hours.',
      ],
    );
  }

  static RouteModel _buildBalancedRoute() {
    final segments = [
      _segment(
        1,
        14.5512,
        121.0489,
        [RouteSegmentFeature.steepIncline, RouteSegmentFeature.narrowPathway],
      ),
      _segment(
        2,
        14.5505,
        121.0495,
        [RouteSegmentFeature.ramp, RouteSegmentFeature.tactilePaving],
      ),
      _segment(
        3,
        14.5494,
        121.0555,
        [RouteSegmentFeature.brokenElevator, RouteSegmentFeature.construction],
      ),
      _segment(
        4,
        14.5467,
        121.0534,
        [RouteSegmentFeature.smoothPavement, RouteSegmentFeature.stairs],
      ),
    ];

    return RouteModel(
      id: 'route-balanced',
      type: RouteType.balanced,
      segments: segments,
      totalScore: AccessibilityScorer.averageSegmentScore(segments),
      distanceM: 1000,
      durationMin: 14,
      warnings: [
        'Moderate incline near the High Street starting point.',
        'Temporary construction detour near Market! Market!.',
        'Final segment includes stairs at SM Aura Sky Garden entrance.',
      ],
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
