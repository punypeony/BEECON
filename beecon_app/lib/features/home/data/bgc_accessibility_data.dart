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
    AccessibilityFeature(
      id: 'high-street-ramp',
      name: 'High Street Ramp',
      lat: 14.5512,
      lng: 121.0489,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Wheelchair-accessible ramp at the main High Street crossing. '
          'Use the north-side curb cut near the pedestrian lane.',
    ),
    AccessibilityFeature(
      id: 'high-street-elevator',
      name: 'High Street Elevator',
      lat: 14.5505,
      lng: 121.0495,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Elevator access between street level and the retail podium. '
          'Look for the lift lobby beside the central escalators.',
    ),
    AccessibilityFeature(
      id: 'sm-aura-elevator',
      name: 'SM Aura Elevator',
      lat: 14.5467,
      lng: 121.0534,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Accessible elevators are available at the main mall entrance '
          'and parking deck connections.',
    ),
    AccessibilityFeature(
      id: 'uptown-bgc-stairs',
      name: 'Uptown BGC Stairs',
      lat: 14.5568,
      lng: 121.0544,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'This plaza connection uses stairs only. Wheelchair users should '
          'route via the nearby ramp on 9th Avenue.',
    ),
    AccessibilityFeature(
      id: 'market-market-construction',
      name: 'Market! Market! Construction',
      lat: 14.5494,
      lng: 121.0555,
      type: AccessibilityFeatureType.construction,
      accessibilityTip:
          'Temporary construction zone near the carpark entrance. Expect '
          'narrow paths and possible detours.',
    ),
    AccessibilityFeature(
      id: 'burgos-circle-tactile',
      name: 'Burgos Circle Tactile Paving',
      lat: 14.5517,
      lng: 121.0446,
      type: AccessibilityFeatureType.tactile,
      accessibilityTip:
          'Tactile paving marks safe crossing points around Burgos Circle. '
          'Follow the raised strips toward pedestrian crossings.',
    ),
    AccessibilityFeature(
      id: 'bonifacio-stopover-ramp',
      name: 'Bonifacio Stopover Ramp',
      lat: 14.5586,
      lng: 121.0478,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Ramp access from the bus stop area to the sidewalk along 32nd Street.',
    ),
    AccessibilityFeature(
      id: 'uptown-parade-ramp',
      name: 'Uptown Parade Ramp',
      lat: 14.5575,
      lng: 121.0530,
      type: AccessibilityFeatureType.ramp,
      accessibilityTip:
          'Gentle slope ramp at the parade ground entrance suitable for '
          'wheelchairs and strollers.',
    ),
    AccessibilityFeature(
      id: 'sm-aura-stairs',
      name: 'SM Aura Sky Garden Stairs',
      lat: 14.5475,
      lng: 121.0528,
      type: AccessibilityFeatureType.stairs,
      accessibilityTip:
          'Sky Garden access requires stairs. Use the ground-floor elevator '
          'bank for step-free mall navigation instead.',
    ),
    AccessibilityFeature(
      id: 'market-market-elevator',
      name: 'Market! Market! Elevator',
      lat: 14.5488,
      lng: 121.0548,
      type: AccessibilityFeatureType.elevator,
      accessibilityTip:
          'Elevator available near the food hall entrance connecting '
          'parking levels to the main market floor.',
    ),
  ];

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
