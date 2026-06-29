import 'package:beecon_app/features/home/data/bgc_accessibility_data.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';
import 'package:beecon_app/features/routing/models/safety_score_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:beecon_app/features/routing/services/safety_scorer.dart';
import 'package:latlong2/latlong.dart';

/// Builds route cards from polylines + green/red accessibility circles on the map.
class PolylineRouteBuilder {
  PolylineRouteBuilder._();

  static const _distance = Distance();
  static const _featureRadiusM = 100.0;
  static const _segmentCount = 4;

  static RouteModel build({
    required RouteType type,
    required RouteLocation origin,
    required RouteLocation destination,
    required List<LatLng> polylinePoints,
    required int distanceM,
    required int durationMin,
  }) {
    final segments = _segmentsFromPolyline(polylinePoints);
    final baseScore = AccessibilityScorer.averageSegmentScore(segments);
    final contextScore = AccessibilityScorer.buildContextScore(baseScore);
    final safetyScore = _buildSafetyScore(origin, destination, polylinePoints);
    final warnings = _warningsFor(type, polylinePoints, origin, destination);

    return RouteModel(
      id: 'route-${type.name}-${origin.label.hashCode}-${destination.label.hashCode}',
      type: type,
      segments: segments,
      baseScore: baseScore,
      contextScore: contextScore,
      safetyScore: safetyScore,
      totalScore: contextScore.adjustedScore,
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: warnings,
    );
  }

  static List<RouteSegmentModel> _segmentsFromPolyline(List<LatLng> points) {
    if (points.length < 2) {
      final p = points.isEmpty ? const LatLng(0, 0) : points.first;
      return [_segment(1, p, const [])];
    }

    final chunkSize =
        (points.length / _segmentCount).ceil().clamp(1, points.length);
    final segments = <RouteSegmentModel>[];

    for (var i = 0; i < _segmentCount; i++) {
      final start = i * chunkSize;
      if (start >= points.length) break;
      final end = (start + chunkSize).clamp(0, points.length);
      final chunk = points.sublist(start, end);
      final mid = chunk[chunk.length ~/ 2];
      segments.add(_segment(segments.length + 1, mid, _featuresAt(mid)));
    }

    return segments;
  }

  static List<RouteSegmentFeature> _featuresAt(LatLng point) {
    final found = <RouteSegmentFeature>[];

    for (final feature in BgcMapData.accessibilityFeatures) {
      final d = _distance.as(LengthUnit.Meter, point, feature.position);
      if (d > _featureRadiusM) continue;

      final mapped = _mapType(feature.type);
      if (mapped != null && !found.contains(mapped)) {
        found.add(mapped);
      }
    }

    return found;
  }

  static RouteSegmentFeature? _mapType(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.ramp:
        return RouteSegmentFeature.ramp;
      case AccessibilityFeatureType.elevator:
        return RouteSegmentFeature.elevator;
      case AccessibilityFeatureType.stairs:
        return RouteSegmentFeature.stairs;
      case AccessibilityFeatureType.construction:
        return RouteSegmentFeature.construction;
      case AccessibilityFeatureType.tactile:
        return RouteSegmentFeature.tactilePaving;
    }
  }

  static List<String> _warningsFor(
    RouteType type,
    List<LatLng> polyline,
    RouteLocation origin,
    RouteLocation destination,
  ) {
    final warnings = <String>[];
    void addOnce(String text) {
      if (!warnings.contains(text)) warnings.add(text);
    }

    final nearGreens = <AccessibilityFeature>[];
    final nearReds = <AccessibilityFeature>[];

    for (final feature in BgcMapData.accessibilityFeatures) {
      for (final point in _samplePolyline(polyline, 12)) {
        final d = _distance.as(LengthUnit.Meter, point, feature.position);
        if (d > _featureRadiusM) continue;
        if (BgcMapData.isGreenFeature(feature.type)) {
          if (!nearGreens.contains(feature)) nearGreens.add(feature);
        } else if (BgcMapData.isRedFeature(feature.type)) {
          if (!nearReds.contains(feature)) nearReds.add(feature);
        }
      }
    }

    switch (type) {
      case RouteType.fastest:
        addOnce('Shortest path — ignores accessibility heatmap markers.');
        for (final red in nearReds.take(2)) {
          addOnce('Passes near ${red.name} (stairs/obstacle).');
        }
      case RouteType.accessible:
        addOnce('Longer alternate walking path from OSRM.');
        for (final green in nearGreens.take(2)) {
          addOnce('Passes near ${green.name}.');
        }
      case RouteType.balanced:
        addOnce('Fast route — may pass near red zones but clips a green marker when convenient.');
        for (final green in nearGreens.take(1)) {
          addOnce('Passes ${green.name}.');
        }
        for (final red in nearReds.take(1)) {
          addOnce('Near ${red.name} — acceptable trade-off for speed.');
        }
    }

    return warnings.take(4).toList();
  }

  static List<LatLng> _samplePolyline(List<LatLng> points, int samples) {
    if (points.length <= samples) return points;
    final result = <LatLng>[];
    for (var i = 0; i < samples; i++) {
      final idx = (i * (points.length - 1) / (samples - 1)).round();
      result.add(points[idx]);
    }
    return result;
  }

  static SafetyScoreModel _buildSafetyScore(
    RouteLocation origin,
    RouteLocation destination,
    List<LatLng> points,
  ) {
    final mid = points[points.length ~/ 2];
    return SafetyScorer.buildSafetyScore(
      midLat: mid.latitude,
      midLng: mid.longitude,
      originLabel: origin.label,
      destinationLabel: destination.label,
    );
  }

  static RouteSegmentModel _segment(
    int sequence,
    LatLng point,
    List<RouteSegmentFeature> features,
  ) {
    return RouteSegmentModel(
      sequence: sequence,
      lat: point.latitude,
      lng: point.longitude,
      features: features,
      segmentScore: AccessibilityScorer.scoreSegment(
        features.isEmpty
            ? [RouteSegmentFeature.smoothPavement]
            : features,
      ),
    );
  }
}
