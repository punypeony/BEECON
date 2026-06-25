import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Device GPS coordinates, updated when location is available.
final currentGpsLocationProvider = StateProvider<LatLng?>((ref) => null);

/// Selected route origin (defaults to current GPS location).
final selectedOriginProvider = StateProvider<RouteLocation?>((ref) => null);

/// Selected route destination.
final selectedDestinationProvider = StateProvider<RouteLocation?>((ref) => null);

/// Polyline points for the active route preview on the home map.
final routePolylineProvider = StateProvider<List<LatLng>>((ref) => []);

enum ActiveSearchField { origin, destination }

/// Which search bar currently owns the suggestions dropdown.
final activeSearchFieldProvider =
    StateProvider<ActiveSearchField?>((ref) => null);

final originSearchQueryProvider = StateProvider<String>((ref) => '');

final destinationSearchQueryProvider = StateProvider<String>((ref) => '');

final originSearchSuggestionsProvider = Provider<List<BgcDestination>>((ref) {
  final query = ref.watch(originSearchQueryProvider);
  return BgcDestinations.search(query);
});

final destinationSearchSuggestionsProvider =
    Provider<List<BgcDestination>>((ref) {
  final query = ref.watch(destinationSearchQueryProvider);
  return BgcDestinations.search(query);
});

final isDropdownVisibleProvider = Provider<bool>((ref) {
  return ref.watch(activeSearchFieldProvider) != null;
});

/// True when both origin and destination are set for routing.
final canGetRoutesProvider = Provider<bool>((ref) {
  final origin = ref.watch(selectedOriginProvider);
  final destination = ref.watch(selectedDestinationProvider);
  return origin != null && destination != null;
});
