import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// ORS polylines for all three route options displayed on the map.
class RoutePolylines {
  const RoutePolylines({
    required this.fastest,
    required this.accessible,
    required this.balanced,
  });

  final List<LatLng> fastest;
  final List<LatLng> accessible;
  final List<LatLng> balanced;

  List<LatLng> forType(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return fastest;
      case RouteType.accessible:
        return accessible;
      case RouteType.balanced:
        return balanced;
    }
  }

  static const Color fastestColor = Color(0xFFFF8A00);
  static const Color accessibleColor = Color(0xFF4CAF50);
  static const Color balancedColor = Color(0xFF2196F3);

  static Color colorForType(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return fastestColor;
      case RouteType.accessible:
        return accessibleColor;
      case RouteType.balanced:
        return balancedColor;
    }
  }
}
