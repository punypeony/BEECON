import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:latlong2/latlong.dart';

/// A named point used as an origin or destination for routing.
class RouteLocation {
  const RouteLocation({
    required this.label,
    required this.lat,
    required this.lng,
    this.isCurrentLocation = false,
  });

  final String label;
  final double lat;
  final double lng;
  final bool isCurrentLocation;

  LatLng get position => LatLng(lat, lng);

  static const String currentLocationLabel = 'My Current Location';

  factory RouteLocation.currentLocation(double lat, double lng) {
    return RouteLocation(
      label: currentLocationLabel,
      lat: lat,
      lng: lng,
      isCurrentLocation: true,
    );
  }

  factory RouteLocation.fromDestination(BgcDestination destination) {
    return RouteLocation(
      label: destination.name,
      lat: destination.lat,
      lng: destination.lng,
    );
  }
}
