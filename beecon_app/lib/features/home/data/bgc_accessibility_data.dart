import 'package:beecon_app/features/home/data/bgc_landmarks.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AccessibilityFeatureType {
  ramp,
  elevator,
  stairs,
  construction,
  tactile,
}

enum SafetyZoneLevel { safe, moderate, alert }

class SafetyZone {
  const SafetyZone({
    required this.name,
    required this.lat,
    required this.lng,
    required this.level,
    required this.radiusM,
  });

  final String name;
  final double lat;
  final double lng;
  final SafetyZoneLevel level;
  final double radiusM;

  LatLng get position => LatLng(lat, lng);
}

class AccessibilityFeature {
  const AccessibilityFeature({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.accessibilityTip,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final AccessibilityFeatureType type;
  final String accessibilityTip;

  LatLng get position => LatLng(lat, lng);
}

class BgcMapData {
  BgcMapData._();

  static const LatLng center = LatLng(14.5547, 121.0507);
  static const double defaultZoom = 15;
  static const double minZoom = 14;
  static const double maxZoom = 19;

  /// Locked map bounds for BGC coverage area.
  static const double boundsSouthWestLat = 14.5280;
  static const double boundsSouthWestLng = 121.0380;
  static const double boundsNorthEastLat = 14.5750;
  static const double boundsNorthEastLng = 121.0650;

  static bool isWithinBounds(LatLng point) {
    return point.latitude >= boundsSouthWestLat &&
        point.latitude <= boundsNorthEastLat &&
        point.longitude >= boundsSouthWestLng &&
        point.longitude <= boundsNorthEastLng;
  }

  static const Color boundaryColor = Color(0xFFFF8A00);

  /// Approximate Bonifacio Global City boundary.
  static const List<LatLng> boundaryPolygon = [
    LatLng(14.5612, 121.0415),
    LatLng(14.5618, 121.0470),
    LatLng(14.5615, 121.0535),
    LatLng(14.5600, 121.0585),
    LatLng(14.5550, 121.0595),
    LatLng(14.5490, 121.0588),
    LatLng(14.5465, 121.0555),
    LatLng(14.5468, 121.0485),
    LatLng(14.5495, 121.0425),
    LatLng(14.5540, 121.0408),
  ];

  static const List<AccessibilityFeature> accessibilityFeatures = [
    // Coordinates snapped to OSRM foot-walk network (sidewalks / streets).
    AccessibilityFeature(
      id: 'high-street-ramp',
      name: 'High Street Ramp',
      lat: 14.550832,
      lng: 121.048409,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Curb-cut ramp on 26th Street sidewalk at the 7th Avenue crossing.',
    ),
    AccessibilityFeature(
      id: 'high-street-elevator',
      name: 'High Street Elevator',
      lat: 14.551137,
      lng: 121.049592,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Street-level lift on 7th Avenue sidewalk along 26th Street.',
    ),
    AccessibilityFeature(
      id: 'sm-aura-elevator',
      name: 'SM Aura Elevator',
      lat: 14.546872,
      lng: 121.052094,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Step-free entrance on 11th Avenue sidewalk near McKinley Parkway.',
    ),
    AccessibilityFeature(
      id: 'uptown-bgc-stairs',
      name: 'Uptown BGC Stairs',
      lat: 14.557332,
      lng: 121.053445,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Stair-only link on 36th Street sidewalk — use 9th Avenue parade ramp.',
    ),
    AccessibilityFeature(
      id: 'market-market-construction',
      name: 'Market! Market! Construction',
      lat: 14.549403,
      lng: 121.055313,
      type: AccessibilityFeatureType.construction,
      accessibilityTip:
          'Sidewalk narrowing on McKinley Parkway near Market carpark.',
    ),
    AccessibilityFeature(
      id: 'burgos-circle-tactile',
      name: 'Burgos Circle Tactile Paving',
      lat: 14.551514,
      lng: 121.045172,
      type: AccessibilityFeatureType.tactile,
      accessibilityTip:
          'Tactile crossing on 28th Street at the Forbes Town loop.',
    ),
    AccessibilityFeature(
      id: 'bonifacio-stopover-ramp',
      name: 'Bonifacio Stopover Ramp',
      lat: 14.558351,
      lng: 121.048257,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Bus-stop ramp on General Gregorio del Pilar Street sidewalk.',
    ),
    AccessibilityFeature(
      id: 'uptown-parade-ramp',
      name: 'Uptown Parade Ramp',
      lat: 14.557448,
      lng: 121.053085,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Parade ground ramp on 36th Street at 9th Avenue.',
    ),
    AccessibilityFeature(
      id: 'sm-aura-stairs',
      name: 'SM Aura Sky Garden Stairs',
      lat: 14.547256,
      lng: 121.052619,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Stairs on 26th Street sidewalk — use 11th Avenue mall entrance.',
    ),
    AccessibilityFeature(
      id: 'market-market-elevator',
      name: 'Market! Market! Entrance',
      lat: 14.549612,
      lng: 121.055218,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Street elevator lobby on McKinley Parkway sidewalk at mall entrance.',
    ),
    AccessibilityFeature(
      id: '5th-ave-ramp',
      name: '5th Avenue Ramp',
      lat: 14.552934,
      lng: 121.049591,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Step-free ramp on 5th Avenue sidewalk at 28th Street.',
    ),
    AccessibilityFeature(
      id: 'mckinley-walkway-ramp',
      name: 'McKinley Parkway Walkway Ramp',
      lat: 14.550188,
      lng: 121.055137,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Walkway ramp on McKinley Parkway at the 26th Street corner.',
    ),
    AccessibilityFeature(
      id: 'corridor-green-8th-high',
      name: '8th Ave / Bonifacio High Street',
      lat: 14.551106,
      lng: 121.049581,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Curb-cut ramp on 8th Avenue sidewalk at Bonifacio High Street.',
    ),
    AccessibilityFeature(
      id: 'corridor-green-8th-30th',
      name: '8th Ave / 30th Street',
      lat: 14.551924,
      lng: 121.050576,
      type: AccessibilityFeatureType.tactile,
      accessibilityTip:
          'Tactile crossing on 8th Avenue at the 30th Street intersection.',
    ),
    AccessibilityFeature(
      id: 'corridor-green-9th-ave',
      name: '9th Avenue',
      lat: 14.550536,
      lng: 121.051347,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Step-free ramp on 9th Avenue sidewalk — balanced-route clip point.',
    ),
    AccessibilityFeature(
      id: 'corridor-green-bonifacio-south',
      name: 'Bonifacio South Street',
      lat: 14.549693,
      lng: 121.052444,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Level sidewalk ramp on Bonifacio South Street eastbound.',
    ),
    AccessibilityFeature(
      id: 'corridor-green-11th-ave',
      name: '11th Avenue',
      lat: 14.549614,
      lng: 121.052956,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Street elevator on 11th Avenue sidewalk near McKinley Parkway.',
    ),
    AccessibilityFeature(
      id: 'serendra-accessible-entrance',
      name: 'Serendra Accessible Entrance',
      lat: 14.552159,
      lng: 121.047928,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Level entrance on 5th Avenue sidewalk at Serendra frontage.',
    ),
    AccessibilityFeature(
      id: 'track-30th-tactile',
      name: 'Track 30th Tactile Crossing',
      lat: 14.553578,
      lng: 121.050792,
      type: AccessibilityFeatureType.tactile,
      accessibilityTip:
          'Tactile paving on 32nd Street at the Track 30th crossing.',
    ),
    AccessibilityFeature(
      id: 'corridor-red-9th-high',
      name: '9th Ave / Bonifacio High Street',
      lat: 14.551032,
      lng: 121.05144,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Stair-only link at 9th Ave / Bonifacio High Street — use 8th Avenue instead.',
    ),
    AccessibilityFeature(
      id: 'corridor-red-9th-30th',
      name: '9th Ave / 30th Street',
      lat: 14.551645,
      lng: 121.05145,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Steep stairs on 9th Avenue at 30th Street — avoid for wheelchairs.',
    ),
    AccessibilityFeature(
      id: 'corridor-red-30th-st',
      name: '30th Street',
      lat: 14.551674,
      lng: 121.05136,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Stair-only segment on 30th Street sidewalk — highest-risk obstacle.',
    ),
    AccessibilityFeature(
      id: 'sm-aura-parking-stairs',
      name: 'SM Aura Parking Stairs',
      lat: 14.547267,
      lng: 121.052434,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Parking stairs on 26th Street sidewalk near McKinley Parkway.',
    ),
    AccessibilityFeature(
      id: 'mckinley-construction',
      name: 'McKinley Parkway Construction',
      lat: 14.549645,
      lng: 121.054655,
      type: AccessibilityFeatureType.construction,
      accessibilityTip:
          'Road works narrowing the McKinley Parkway sidewalk.',
    ),
  ];

  /// Green circles — ramps, elevators, tactile paving (route toward these).
  static List<AccessibilityFeature> get greenFeatures => accessibilityFeatures
      .where((f) => isGreenFeature(f.type))
      .toList(growable: false);

  /// Red circles — stairs and construction (route away from these).
  static List<AccessibilityFeature> get redFeatures => accessibilityFeatures
      .where((f) => isRedFeature(f.type))
      .toList(growable: false);

  static bool isGreenFeature(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.ramp:
      case AccessibilityFeatureType.elevator:
      case AccessibilityFeatureType.tactile:
        return true;
      case AccessibilityFeatureType.stairs:
      case AccessibilityFeatureType.construction:
        return false;
    }
  }

  static bool isRedFeature(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.stairs:
      case AccessibilityFeatureType.construction:
        return true;
      case AccessibilityFeatureType.ramp:
      case AccessibilityFeatureType.elevator:
      case AccessibilityFeatureType.tactile:
        return false;
    }
  }

  /// Features within [corridorM] of the straight line between [origin] and [destination].
  static List<AccessibilityFeature> featuresAlongCorridor(
    LatLng origin,
    LatLng destination, {
    bool greenOnly = false,
    bool redOnly = false,
    double corridorM = 480,
  }) {
    const distance = Distance();
    final list = greenOnly
        ? greenFeatures
        : redOnly
            ? redFeatures
            : accessibilityFeatures;

    return list.where((feature) {
      final d = _pointToSegmentDistanceM(
        distance,
        origin,
        destination,
        feature.position,
      );
      return d <= corridorM;
    }).toList(growable: false);
  }

  static double _pointToSegmentDistanceM(
    Distance distance,
    LatLng a,
    LatLng b,
    LatLng p,
  ) {
    final ax = b.longitude - a.longitude;
    final ay = b.latitude - a.latitude;
    final bx = p.longitude - a.longitude;
    final by = p.latitude - a.latitude;
    final lenSq = ax * ax + ay * ay;
    var t = lenSq == 0 ? 0.0 : (bx * ax + by * ay) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = LatLng(
      a.latitude + t * ay,
      a.longitude + t * ax,
    );
    return distance.as(LengthUnit.Meter, proj, p);
  }

  /// Search keyword → pin coordinates (shared with routing destinations).
  static Map<String, LatLng> get searchDestinations =>
      BgcLandmarks.searchAliases;

  static Color heatmapColorForType(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.ramp:
      case AccessibilityFeatureType.elevator:
      case AccessibilityFeatureType.tactile:
        return const Color(0xFF4CAF50);
      case AccessibilityFeatureType.construction:
        return const Color(0xFFFF8A00);
      case AccessibilityFeatureType.stairs:
        return const Color(0xFFF44336);
    }
  }

  static const List<SafetyZone> safetyZones = [
    SafetyZone(
      name: 'High Street',
      lat: 14.5512,
      lng: 121.0489,
      level: SafetyZoneLevel.safe,
      radiusM: 120,
    ),
    SafetyZone(
      name: '5th Avenue',
      lat: 14.5535,
      lng: 121.0498,
      level: SafetyZoneLevel.safe,
      radiusM: 100,
    ),
    SafetyZone(
      name: 'Bonifacio Drive',
      lat: 14.5545,
      lng: 121.0465,
      level: SafetyZoneLevel.safe,
      radiusM: 110,
    ),
    SafetyZone(
      name: 'Burgos Circle Park',
      lat: 14.5517,
      lng: 121.0446,
      level: SafetyZoneLevel.moderate,
      radiusM: 90,
    ),
    SafetyZone(
      name: 'BGC Side Streets',
      lat: 14.5525,
      lng: 121.0520,
      level: SafetyZoneLevel.moderate,
      radiusM: 80,
    ),
    SafetyZone(
      name: 'Track 30th Park',
      lat: 14.5538,
      lng: 121.0512,
      level: SafetyZoneLevel.moderate,
      radiusM: 75,
    ),
    SafetyZone(
      name: 'BGC Perimeter Road',
      lat: 14.5480,
      lng: 121.0420,
      level: SafetyZoneLevel.alert,
      radiusM: 100,
    ),
    SafetyZone(
      name: 'Parking Areas',
      lat: 14.5490,
      lng: 121.0565,
      level: SafetyZoneLevel.alert,
      radiusM: 85,
    ),
    SafetyZone(
      name: 'C5 Service Road',
      lat: 14.5465,
      lng: 121.0590,
      level: SafetyZoneLevel.alert,
      radiusM: 90,
    ),
  ];

  static Color heatmapColorForSafetyLevel(SafetyZoneLevel level) {
    switch (level) {
      case SafetyZoneLevel.safe:
        return const Color(0xFF4CAF50);
      case SafetyZoneLevel.moderate:
        return const Color(0xFFFF8A00);
      case SafetyZoneLevel.alert:
        return const Color(0xFFF44336);
    }
  }

  static Color markerColorForType(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.ramp:
      case AccessibilityFeatureType.elevator:
        return Colors.green;
      case AccessibilityFeatureType.stairs:
        return Colors.red;
      case AccessibilityFeatureType.construction:
        return Colors.orange;
      case AccessibilityFeatureType.tactile:
        return Colors.green;
    }
  }

  static String typeLabel(AccessibilityFeatureType type) {
    switch (type) {
      case AccessibilityFeatureType.ramp:
        return 'Ramp';
      case AccessibilityFeatureType.elevator:
        return 'Elevator';
      case AccessibilityFeatureType.stairs:
        return 'Stairs';
      case AccessibilityFeatureType.construction:
        return 'Construction';
      case AccessibilityFeatureType.tactile:
        return 'Tactile paving';
    }
  }

  static LatLng? matchSearchDestination(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (searchDestinations.containsKey(normalized)) {
      return searchDestinations[normalized];
    }

    for (final entry in searchDestinations.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    return null;
  }
}
