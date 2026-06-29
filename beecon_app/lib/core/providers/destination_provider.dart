import 'package:beecon_app/core/services/gemini_service.dart';
import 'package:beecon_app/core/services/ors_route_result.dart';
import 'package:beecon_app/core/services/route_ai_models.dart';
import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_polylines.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Device GPS coordinates, updated when location is available.
final currentGpsLocationProvider = StateProvider<LatLng?>((ref) => null);

/// Selected route origin (defaults to current GPS location).
final selectedOriginProvider = StateProvider<RouteLocation?>((ref) => null);

/// Selected route destination.
final selectedDestinationProvider = StateProvider<RouteLocation?>((ref) => null);

/// All three ORS route polylines for the home map.
final routePolylinesProvider = StateProvider<RoutePolylines?>((ref) => null);

/// Raw ORS route bundle with distance/duration per variant.
final orsRouteBundleProvider = StateProvider<OrsRouteBundle?>((ref) => null);

/// AI-recommended route type after both agents complete.
final recommendedRouteTypeProvider = StateProvider<RouteType?>((ref) => null);

/// Latest two-agent pipeline result for the current route query.
final routeAgentPipelineProvider =
    StateProvider<RouteAgentPipelineResult?>((ref) => null);

/// Sequential AI loading phase on the route results screen.
final routeAiLoadingPhaseProvider =
    StateProvider<RouteAiLoadingPhase>((ref) => RouteAiLoadingPhase.idle);

/// Shared Gemini service instance (agent cache lives here).
final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());

/// Which route line is highlighted on the map (width 7 vs 3).
final highlightedRouteTypeProvider = StateProvider<RouteType?>((ref) => null);

/// Which heatmap overlay is active on the home map.
enum HeatmapOverlay { accessibility, safety }

/// Active heatmap overlay, or null when heatmap is hidden.
final heatmapOverlayProvider = StateProvider<HeatmapOverlay?>((ref) => null);

/// True while ORS routes are being fetched.
final routesLoadingProvider = StateProvider<bool>((ref) => false);

/// Map tap mode for placing a community report pin.
final reportTapModeProvider = StateProvider<bool>((ref) => false);

/// Pending report pin while user confirms location on the home map.
final pendingReportPinProvider = StateProvider<LatLng?>((ref) => null);

/// After submitting a report, home map moves to this point.
final highlightReportLocationProvider = StateProvider<LatLng?>((ref) => null);

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
