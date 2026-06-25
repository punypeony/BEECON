import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently selected BGC destination for routing.
final selectedDestinationProvider =
    StateProvider<BgcDestination?>((ref) => null);

/// Current search bar query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Whether the destination suggestions dropdown is visible.
final isDropdownVisibleProvider = StateProvider<bool>((ref) => false);

/// Filtered destination suggestions based on the current query (max 5).
final searchSuggestionsProvider = Provider<List<BgcDestination>>((ref) {
  final query = ref.watch(searchQueryProvider);
  return BgcDestinations.search(query);
});
