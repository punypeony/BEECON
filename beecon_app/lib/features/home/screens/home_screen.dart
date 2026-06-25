import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/utils/time_utils.dart';
import 'package:beecon_app/features/home/data/bgc_accessibility_data.dart';
import 'package:beecon_app/features/home/data/bgc_destinations.dart';
import 'package:beecon_app/features/home/screens/widgets/ai_insight_banner.dart';
import 'package:beecon_app/features/reports/models/report_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LatLng? _currentLocation;
  LatLng? _destination;
  bool _locationLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
    ref.read(isDropdownVisibleProvider.notifier).state =
        query.trim().isNotEmpty;
  }

  void _closeSuggestions() {
    ref.read(isDropdownVisibleProvider.notifier).state = false;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(isDropdownVisibleProvider.notifier).state = false;
    ref.read(selectedDestinationProvider.notifier).state = null;
    setState(() => _destination = null);
  }

  void _selectDestination(BgcDestination destination) {
    _searchController.text = destination.name;
    ref.read(searchQueryProvider.notifier).state = destination.name;
    ref.read(selectedDestinationProvider.notifier).state = destination;
    ref.read(isDropdownVisibleProvider.notifier).state = false;
    _searchFocusNode.unfocus();
    setState(() => _destination = destination.position);
    _mapController.move(destination.position, BgcMapData.defaultZoom);
  }

  Future<void> _initCurrentLocation() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          if (mounted) setState(() => _locationLoading = false);
          return;
        }
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _closeSuggestions();
    _searchFocusNode.unfocus();
    ref.read(selectedDestinationProvider.notifier).state = null;
    setState(() => _destination = point);
  }

  void _onSearchSubmitted(String query) {
    final match = BgcDestinations.matchSubmitted(query);
    if (match == null) {
      ref.read(searchQueryProvider.notifier).state = query;
      ref.read(isDropdownVisibleProvider.notifier).state = true;
      final suggestions = ref.read(searchSuggestionsProvider);
      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No BGC destinations found for "$query".',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }

    _selectDestination(match);
  }

  void _showFeatureSheet(AccessibilityFeature feature) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                feature.name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BgcMapData.markerColorForType(feature.type)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  BgcMapData.typeLabel(feature.type),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: BgcMapData.markerColorForType(feature.type),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Accessibility tip',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                feature.accessibilityTip,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportSheet(ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.reportType,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (report.upvotes >= 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            'Community Verified',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatTimeAgo(report.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                report.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await HiveService.upvoteReport(report);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.thumb_up_outlined),
                  label: Text(
                    'Upvote (${report.upvotes})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildAccessibilityMarkers() {
    return BgcMapData.accessibilityFeatures.map((feature) {
      final color = BgcMapData.markerColorForType(feature.type);
      return Marker(
        point: feature.position,
        width: 28,
        height: 28,
        child: GestureDetector(
          onTap: () => _showFeatureSheet(feature),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildReportMarkers(List<ReportModel> reports) {
    return reports.map((report) {
      return Marker(
        point: LatLng(report.lat, report.lng),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _showReportSheet(report),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(
                Icons.warning,
                color: Colors.red,
                size: 28,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildOverlayMarkers(List<ReportModel> reports) {
    final markers = <Marker>[
      ..._buildAccessibilityMarkers(),
      ..._buildReportMarkers(reports),
    ];

    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_destination != null) {
      markers.add(
        Marker(
          point: _destination!,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.location_on,
            color: AppColors.primary,
            size: 44,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final isDropdownVisible = ref.watch(isDropdownVisibleProvider);
    final suggestions = ref.watch(searchSuggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          AppConstants.logoPath,
          height: 48,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(query),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _closeSuggestions,
                    behavior: HitTestBehavior.translucent,
                    child: const AiInsightBanner(),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _closeSuggestions();
                        _searchFocusNode.unfocus();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ValueListenableBuilder<Box<ReportModel>>(
                          valueListenable: HiveService.reportsBox.listenable(),
                          builder: (context, box, _) {
                            final reports = HiveService.getAllReports();
                            return Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: BgcMapData.center,
                                    initialZoom: BgcMapData.defaultZoom,
                                    onTap: _onMapTap,
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.all,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.beecon.beecon_app',
                                    ),
                                    PolygonLayer(
                                      polygons: [
                                        Polygon(
                                          points: BgcMapData.boundaryPolygon,
                                          color: BgcMapData.boundaryColor
                                              .withValues(alpha: 0.3),
                                          borderColor: BgcMapData.boundaryColor,
                                          borderStrokeWidth: 2,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: _buildOverlayMarkers(reports),
                                    ),
                                  ],
                                ),
                                if (_locationLoading)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Locating…',
                                            style:
                                                GoogleFonts.poppins(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isDropdownVisible && query.trim().isNotEmpty)
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: _DestinationSuggestionsDropdown(
                    suggestions: suggestions,
                    onSelect: _selectDestination,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(String query) {
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
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search destination…',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              onTap: () {
                if (_searchController.text.trim().isNotEmpty) {
                  ref.read(isDropdownVisibleProvider.notifier).state = true;
                }
              },
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: Colors.grey[600]),
              onPressed: _clearSearch,
              tooltip: 'Clear',
            ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
            onPressed: () => _onSearchSubmitted(_searchController.text),
          ),
        ],
      ),
    );
  }
}

class _DestinationSuggestionsDropdown extends StatelessWidget {
  const _DestinationSuggestionsDropdown({
    required this.suggestions,
    required this.onSelect,
  });

  final List<BgcDestination> suggestions;
  final ValueChanged<BgcDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: suggestions.isEmpty
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
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final destination = suggestions[index];
                  return InkWell(
                    onTap: () => onSelect(destination),
                    borderRadius: BorderRadius.vertical(
                      top: index == 0
                          ? const Radius.circular(12)
                          : Radius.zero,
                      bottom: index == suggestions.length - 1
                          ? const Radius.circular(12)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destination.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  destination.address,
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
                },
              ),
            ),
    );
  }
}
