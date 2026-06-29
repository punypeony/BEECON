import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/widgets/responsive_layout.dart';
import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationSearchPanel extends ConsumerStatefulWidget {
  const LocationSearchPanel({
    super.key,
    required this.onGetRoutes,
    required this.onOriginChanged,
    required this.onDestinationChanged,
  });

  final VoidCallback onGetRoutes;
  final VoidCallback onOriginChanged;
  final VoidCallback onDestinationChanged;

  @override
  ConsumerState<LocationSearchPanel> createState() =>
      _LocationSearchPanelState();
}

class _LocationSearchPanelState extends ConsumerState<LocationSearchPanel> {
  final TextEditingController _originController = TextEditingController(
    text: RouteLocation.currentLocationLabel,
  );
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onOriginTextChanged);
    _destinationController.addListener(_onDestinationTextChanged);
    _originFocusNode.addListener(_onOriginFocusChanged);
    _destinationFocusNode.addListener(_onDestinationFocusChanged);
  }

  @override
  void dispose() {
    _originController.removeListener(_onOriginTextChanged);
    _destinationController.removeListener(_onDestinationTextChanged);
    _originFocusNode.removeListener(_onOriginFocusChanged);
    _destinationFocusNode.removeListener(_onDestinationFocusChanged);
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  void _onOriginFocusChanged() {
    if (_originFocusNode.hasFocus) {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.origin;
    }
  }

  void _onDestinationFocusChanged() {
    if (_destinationFocusNode.hasFocus) {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.destination;
    }
  }

  void _onOriginTextChanged() {
    ref.read(originSearchQueryProvider.notifier).state =
        _originController.text;
    setState(() {});
    if (_originFocusNode.hasFocus) {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.origin;
    }
  }

  void _onDestinationTextChanged() {
    ref.read(destinationSearchQueryProvider.notifier).state =
        _destinationController.text;
    setState(() {});
    if (_destinationFocusNode.hasFocus) {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.destination;
    }
  }

  void _closeDropdown() {
    ref.read(activeSearchFieldProvider.notifier).state = null;
    _originFocusNode.unfocus();
    _destinationFocusNode.unfocus();
  }

  void _selectCurrentLocation() {
    final gps = ref.read(currentGpsLocationProvider);
    if (gps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Current location not available yet.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    _originController.text = RouteLocation.currentLocationLabel;
    ref.read(originSearchQueryProvider.notifier).state =
        RouteLocation.currentLocationLabel;
    ref.read(selectedOriginProvider.notifier).state =
        RouteLocation.currentLocation(gps.latitude, gps.longitude);
    _closeDropdown();
    widget.onOriginChanged();
  }

  void _selectOrigin(BgcDestination destination) {
    _originController.text = destination.name;
    ref.read(originSearchQueryProvider.notifier).state = destination.name;
    ref.read(selectedOriginProvider.notifier).state =
        RouteLocation.fromDestination(destination);
    _closeDropdown();
    widget.onOriginChanged();
  }

  void _selectDestination(BgcDestination destination) {
    _destinationController.text = destination.name;
    ref.read(destinationSearchQueryProvider.notifier).state = destination.name;
    ref.read(selectedDestinationProvider.notifier).state =
        RouteLocation.fromDestination(destination);
    _closeDropdown();
    widget.onDestinationChanged();
  }

  void _clearOrigin() {
    _selectCurrentLocation();
  }

  void _clearDestination() {
    _destinationController.clear();
    ref.read(destinationSearchQueryProvider.notifier).state = '';
    ref.read(selectedDestinationProvider.notifier).state = null;
    ref.read(routePolylinesProvider.notifier).state = null;
    ref.read(orsRouteBundleProvider.notifier).state = null;
    ref.read(recommendedRouteTypeProvider.notifier).state = null;
    ref.read(routeAgentPipelineProvider.notifier).state = null;
    widget.onDestinationChanged();
  }

  void _swapLocations() {
    final origin = ref.read(selectedOriginProvider);
    final destination = ref.read(selectedDestinationProvider);

    ref.read(selectedOriginProvider.notifier).state = destination;
    ref.read(selectedDestinationProvider.notifier).state = origin;

    final originText = _originController.text;
    final destText = _destinationController.text;
    _originController.text = destText.isNotEmpty
        ? destText
        : RouteLocation.currentLocationLabel;
    _destinationController.text = originText;

    ref.read(originSearchQueryProvider.notifier).state = _originController.text;
    ref.read(destinationSearchQueryProvider.notifier).state =
        _destinationController.text;
    ref.read(routePolylinesProvider.notifier).state = null;
    ref.read(orsRouteBundleProvider.notifier).state = null;
    ref.read(recommendedRouteTypeProvider.notifier).state = null;
    ref.read(routeAgentPipelineProvider.notifier).state = null;

    widget.onOriginChanged();
    widget.onDestinationChanged();
  }

  void _onOriginSubmitted(String query) {
    if (query.trim().toLowerCase() ==
        RouteLocation.currentLocationLabel.toLowerCase()) {
      _selectCurrentLocation();
      return;
    }
    final match = BgcDestinations.matchSubmitted(query);
    if (match != null) {
      _selectOrigin(match);
    } else {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.origin;
    }
  }

  void _onDestinationSubmitted(String query) {
    final match = BgcDestinations.matchSubmitted(query);
    if (match != null) {
      _selectDestination(match);
    } else {
      ref.read(activeSearchFieldProvider.notifier).state =
          ActiveSearchField.destination;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeField = ref.watch(activeSearchFieldProvider);
    final canGetRoutes = ref.watch(canGetRoutesProvider);
    final originQuery = ref.watch(originSearchQueryProvider);
    final destinationQuery = ref.watch(destinationSearchQueryProvider);

    final originSuggestions = ref.watch(originSearchSuggestionsProvider);
    final destinationSuggestions = ref.watch(destinationSearchSuggestionsProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _originController,
                      focusNode: _originFocusNode,
                      hintText: RouteLocation.currentLocationLabel,
                      icon: Icons.my_location,
                      showClear: _originController.text.isNotEmpty,
                      onClear: _clearOrigin,
                      onTap: () {
                        ref.read(activeSearchFieldProvider.notifier).state =
                            ActiveSearchField.origin;
                      },
                      onSubmitted: _onOriginSubmitted,
                    ),
                    if (activeField == ActiveSearchField.origin) ...[
                      const SizedBox(height: 4),
                      _SuggestionsDropdown(
                        showCurrentLocationOption: true,
                        suggestions: originSuggestions,
                        query: originQuery,
                        onSelectCurrentLocation: _selectCurrentLocation,
                        onSelect: _selectOrigin,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                child: Material(
                  color: AppColors.accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _swapLocations,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.swap_horiz,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _destinationController,
                      focusNode: _destinationFocusNode,
                      hintText: 'Where do you want to go?',
                      icon: Icons.search,
                      showClear: _destinationController.text.isNotEmpty,
                      onClear: _clearDestination,
                      onTap: () {
                        ref.read(activeSearchFieldProvider.notifier).state =
                            ActiveSearchField.destination;
                      },
                      onSubmitted: _onDestinationSubmitted,
                    ),
                    if (activeField == ActiveSearchField.destination) ...[
                      const SizedBox(height: 4),
                      _SuggestionsDropdown(
                        showCurrentLocationOption: false,
                        suggestions: destinationSuggestions,
                        query: destinationQuery,
                        onSelectCurrentLocation: _selectCurrentLocation,
                        onSelect: _selectDestination,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (canGetRoutes) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onGetRoutes,
                icon: const Icon(Icons.directions),
                label: Text(
                  'Get Routes',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchBar(
          controller: _originController,
          focusNode: _originFocusNode,
          hintText: RouteLocation.currentLocationLabel,
          icon: Icons.my_location,
          showClear: _originController.text.isNotEmpty,
          onClear: _clearOrigin,
          onTap: () {
            ref.read(activeSearchFieldProvider.notifier).state =
                ActiveSearchField.origin;
          },
          onSubmitted: _onOriginSubmitted,
        ),
        if (activeField == ActiveSearchField.origin) ...[
          const SizedBox(height: 4),
          _SuggestionsDropdown(
            showCurrentLocationOption: true,
            suggestions: originSuggestions,
            query: originQuery,
            onSelectCurrentLocation: _selectCurrentLocation,
            onSelect: _selectOrigin,
          ),
        ],
        const SizedBox(height: 8),
        Center(
          child: Material(
            color: AppColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _swapLocations,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.swap_vert,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SearchBar(
          controller: _destinationController,
          focusNode: _destinationFocusNode,
          hintText: 'Where do you want to go?',
          icon: Icons.search,
          showClear: _destinationController.text.isNotEmpty,
          onClear: _clearDestination,
          onTap: () {
            ref.read(activeSearchFieldProvider.notifier).state =
                ActiveSearchField.destination;
          },
          onSubmitted: _onDestinationSubmitted,
        ),
        if (activeField == ActiveSearchField.destination) ...[
          const SizedBox(height: 4),
          _SuggestionsDropdown(
            showCurrentLocationOption: false,
            suggestions: destinationSuggestions,
            query: destinationQuery,
            onSelectCurrentLocation: _selectCurrentLocation,
            onSelect: _selectDestination,
          ),
        ],
        if (canGetRoutes) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onGetRoutes,
              icon: const Icon(Icons.directions),
              label: Text(
                'Get Routes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.icon,
    required this.showClear,
    required this.onClear,
    required this.onTap,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData icon;
  final bool showClear;
  final VoidCallback onClear;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onTap: onTap,
              onSubmitted: onSubmitted,
            ),
          ),
          if (showClear)
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
              onPressed: onClear,
              tooltip: 'Clear',
            ),
        ],
      ),
    );
  }
}

class _SuggestionsDropdown extends StatelessWidget {
  const _SuggestionsDropdown({
    required this.showCurrentLocationOption,
    required this.suggestions,
    required this.query,
    required this.onSelectCurrentLocation,
    required this.onSelect,
  });

  final bool showCurrentLocationOption;
  final List<BgcDestination> suggestions;
  final String query;
  final VoidCallback onSelectCurrentLocation;
  final ValueChanged<BgcDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    if (!showCurrentLocationOption && !hasQuery) {
      return const SizedBox.shrink();
    }

    final showEmpty = hasQuery && suggestions.isEmpty;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: showEmpty && !showCurrentLocationOption
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No BGC destinations found',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (showCurrentLocationOption)
                    _SuggestionTile(
                      icon: Icons.gps_fixed,
                      title: RouteLocation.currentLocationLabel,
                      subtitle: 'Use device GPS coordinates',
                      onTap: onSelectCurrentLocation,
                      isFirst: true,
                    ),
                  if (showCurrentLocationOption && suggestions.isNotEmpty)
                    Divider(height: 1, color: Colors.grey[200]),
                  if (showEmpty && showCurrentLocationOption)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No BGC destinations found',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ...suggestions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final destination = entry.value;
                    return Column(
                      children: [
                        if (index > 0 || showCurrentLocationOption)
                          Divider(height: 1, color: Colors.grey[200]),
                        _SuggestionTile(
                          icon: Icons.location_on_outlined,
                          title: destination.name,
                          subtitle: destination.address,
                          onTap: () => onSelect(destination),
                          isFirst: index == 0 && !showCurrentLocationOption,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFirst = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Closes the search dropdown from outside the panel.
void closeLocationSearchDropdown(WidgetRef ref) {
  ref.read(activeSearchFieldProvider.notifier).state = null;
}
