import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:latlong2/latlong.dart';

class OrsRouteResult {
  const OrsRouteResult({
    required this.routeType,
    required this.polylinePoints,
    required this.distanceM,
    required this.durationMin,
    this.isFallback = false,
  });

  final String routeType;
  final List<LatLng> polylinePoints;
  final double distanceM;
  final double durationMin;
  final bool isFallback;
}

class OrsRouteBundle {
  const OrsRouteBundle({
    required this.fastest,
    required this.accessible,
    required this.balanced,
  });

  final OrsRouteResult fastest;
  final OrsRouteResult accessible;
  final OrsRouteResult balanced;

  bool get anyFallback =>
      fastest.isFallback || accessible.isFallback || balanced.isFallback;

  OrsRouteResult? forTypeLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('fastest')) return fastest;
    if (lower.contains('accessible')) return accessible;
    if (lower.contains('balanced')) return balanced;
    return null;
  }

  OrsRouteResult forType(RouteType type) {
    switch (type) {
      case RouteType.fastest:
        return fastest;
      case RouteType.accessible:
        return accessible;
      case RouteType.balanced:
        return balanced;
    }
  }
}
