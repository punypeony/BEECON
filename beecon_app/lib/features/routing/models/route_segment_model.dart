enum RouteSegmentFeature {
  ramp,
  elevator,
  smoothPavement,
  coveredWalkway,
  accessibleEntrance,
  tactilePaving,
  stairs,
  brokenElevator,
  construction,
  steepIncline,
  narrowPathway,
}

class RouteSegmentModel {
  const RouteSegmentModel({
    required this.sequence,
    required this.lat,
    required this.lng,
    required this.features,
    required this.segmentScore,
  });

  final int sequence;
  final double lat;
  final double lng;
  final List<RouteSegmentFeature> features;
  final int segmentScore;
}
