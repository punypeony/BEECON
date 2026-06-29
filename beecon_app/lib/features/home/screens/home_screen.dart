import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/services/ors_service.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/utils/time_utils.dart';
import 'package:beecon_app/features/home/data/bgc_accessibility_data.dart';
import 'package:beecon_app/features/home/screens/widgets/ai_insight_banner.dart';
import 'package:beecon_app/features/home/screens/widgets/emergency_sheet.dart';
import 'package:beecon_app/features/home/screens/widgets/heatmap_legend.dart';
import 'package:beecon_app/features/home/screens/widgets/how_it_works_sheet.dart';
import 'package:beecon_app/features/home/screens/widgets/location_search_panel.dart';
import 'package:beecon_app/features/home/screens/widgets/report_location_sheet.dart';
import 'package:beecon_app/features/reports/models/report_model.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/route_polylines.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
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
  final OrsService _orsService = OrsService();
  bool _locationLoading = true;
  MapOptions? _mapOptions;

  MapOptions get _stableMapOptions {
    return _mapOptions ??= MapOptions(
      initialCenter: BgcMapData.center,
      initialZoom: BgcMapData.defaultZoom,
      minZoom: BgcMapData.minZoom,
      maxZoom: BgcMapData.maxZoom,
      cameraConstraint: CameraConstraint.contain(
        bounds: LatLngBounds(
          LatLng(
            BgcMapData.boundsSouthWestLat,
            BgcMapData.boundsSouthWestLng,
          ),
          LatLng(
            BgcMapData.boundsNorthEastLat,
            BgcMapData.boundsNorthEastLng,
          ),
        ),
      ),
      onMapEvent: _onMapEvent,
      onTap: _handleMapTap,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all,
      ),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (ref.read(reportTapModeProvider)) {
      _onReportMapTap(point);
    }
  }

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(BgcMapData.center, BgcMapData.defaultZoom);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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

      if (!mounted) return;

      final gps = LatLng(position.latitude, position.longitude);
      ref.read(currentGpsLocationProvider.notifier).state = gps;

      final origin = ref.read(selectedOriginProvider);
      if (origin == null || origin.isCurrentLocation) {
        ref.read(selectedOriginProvider.notifier).state =
            RouteLocation.currentLocation(gps.latitude, gps.longitude);
      }

      setState(() => _locationLoading = false);
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _startReportTapMode() {
    closeLocationSearchDropdown(ref);
    ref.read(pendingReportPinProvider.notifier).state = null;
    ref.read(reportTapModeProvider.notifier).state = true;
  }

  void _cancelReportTapMode() {
    ref.read(reportTapModeProvider.notifier).state = false;
    ref.read(pendingReportPinProvider.notifier).state = null;
  }

  void _onReportMapTap(LatLng point) {
    if (!ref.read(reportTapModeProvider)) return;

    if (!BgcMapData.isWithinBounds(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please tap within the BGC map area.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    ref.read(pendingReportPinProvider.notifier).state = point;

    showReportLocationSheet(
      context,
      location: point,
      onContinue: () {
        ref.read(reportTapModeProvider.notifier).state = false;
        ref.read(pendingReportPinProvider.notifier).state = null;
        navigateToReportForm(context, point);
      },
      onCancel: _cancelReportTapMode,
    );
  }

  void _showReportTapModeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tap anywhere on the map to place your report',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _focusSubmittedReport(LatLng location) {
    _mapController.move(
      location,
      (_mapController.camera.zoom).clamp(
        BgcMapData.minZoom,
        BgcMapData.maxZoom,
      ),
    );
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      final center = _mapController.camera.center;
      if (!BgcMapData.isWithinBounds(center)) {
        _mapController.move(
          BgcMapData.center,
          _mapController.camera.zoom.clamp(
            BgcMapData.minZoom,
            BgcMapData.maxZoom,
          ),
        );
      }
    }
  }

  void _refreshMapMarkers() {
    final origin = ref.read(selectedOriginProvider);
    final destination = ref.read(selectedDestinationProvider);
    final polylines = ref.read(routePolylinesProvider);

    if (polylines != null) {
      _fitMapToPoints([
        if (origin != null) origin.position,
        if (destination != null) destination.position,
        ...polylines.fastest,
      ]);
    } else if (origin != null && destination != null) {
      _fitMapToPoints([origin.position, destination.position]);
    } else if (destination != null) {
      _mapController.move(destination.position, BgcMapData.defaultZoom);
    } else if (origin != null) {
      _mapController.move(origin.position, BgcMapData.defaultZoom);
    }

    if (mounted) setState(() {});
  }

  Future<void> _getRoutes() async {
    final origin = ref.read(selectedOriginProvider);
    final destination = ref.read(selectedDestinationProvider);
    if (origin == null || destination == null) return;

    ref.read(routesLoadingProvider.notifier).state = true;

    final polylines = await _orsService.getAllRoutes(
      origin.lat,
      origin.lng,
      destination.lat,
      destination.lng,
    );

    ref.read(routePolylinesProvider.notifier).state = polylines;
    ref.read(highlightedRouteTypeProvider.notifier).state = null;
    ref.read(routesLoadingProvider.notifier).state = false;

    _fitMapToPoints([
      origin.position,
      destination.position,
      ...polylines.fastest,
      ...polylines.accessible,
      ...polylines.balanced,
    ]);

    if (!mounted) return;
    context.go(AppConstants.routes);
  }

  void _fitMapToPoints(List<LatLng> points) {
    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final constrained = LatLngBounds(
      LatLng(
        minLat.clamp(BgcMapData.boundsSouthWestLat, BgcMapData.boundsNorthEastLat),
        minLng.clamp(BgcMapData.boundsSouthWestLng, BgcMapData.boundsNorthEastLng),
      ),
      LatLng(
        maxLat.clamp(BgcMapData.boundsSouthWestLat, BgcMapData.boundsNorthEastLat),
        maxLng.clamp(BgcMapData.boundsSouthWestLng, BgcMapData.boundsNorthEastLng),
      ),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: constrained, padding: const EdgeInsets.all(48)),
    );
  }

  List<Polyline> _buildRoutePolylines(
    RoutePolylines? polylines,
    RouteType? highlighted,
  ) {
    if (polylines == null) return [];

    return RouteType.values.map((type) {
      final points = polylines.forType(type);
      if (points.length < 2) return null;

      final isHighlighted = highlighted == null || highlighted == type;
      return Polyline(
        points: points,
        color: RoutePolylines.colorForType(type).withValues(
          alpha: isHighlighted ? 1.0 : 0.4,
        ),
        strokeWidth: highlighted == type ? 7.0 : 5.0,
      );
    }).whereType<Polyline>().toList();
  }

  List<CircleMarker> _buildAccessibilityHeatmapCircles() {
    return BgcMapData.accessibilityFeatures.map((feature) {
      return CircleMarker(
        point: feature.position,
        radius: 80,
        useRadiusInMeter: true,
        color: BgcMapData.heatmapColorForType(feature.type)
            .withValues(alpha: 0.3),
        borderColor: Colors.transparent,
      );
    }).toList();
  }

  List<CircleMarker> _buildSafetyHeatmapCircles() {
    return BgcMapData.safetyZones.map((zone) {
      return CircleMarker(
        point: zone.position,
        radius: zone.radiusM,
        useRadiusInMeter: true,
        color: BgcMapData.heatmapColorForSafetyLevel(zone.level)
            .withValues(alpha: 0.3),
        borderColor: Colors.transparent,
      );
    }).toList();
  }

  void _showFeatureSheet(AccessibilityFeature feature) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
            Text(
              feature.accessibilityTip,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSheet(ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                const Icon(Icons.report_problem, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.reportType,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatTimeAgo(report.timestamp),
              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${report.lat.toStringAsFixed(4)}, '
              'Lng: ${report.lng.toStringAsFixed(4)}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              report.description,
              style: GoogleFonts.poppins(height: 1.5, fontSize: 14),
            ),
          ],
        ),
      ),
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
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildReportMarkers(List<ReportModel> reports) {
    return reports
        .map(
          (report) => Marker(
            point: LatLng(report.lat, report.lng),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _showReportSheet(report),
              child: const Icon(
                Icons.report_problem,
                color: Colors.red,
                size: 32,
              ),
            ),
          ),
        )
        .toList();
  }

  Marker? _buildPendingReportPin(LatLng? point) {
    if (point == null) return null;
    return Marker(
      point: point,
      width: 44,
      height: 44,
      alignment: Alignment.bottomCenter,
      child: const Icon(Icons.location_on, color: Colors.red, size: 44),
    );
  }

  List<Marker> _buildRouteMarkers(
    RouteLocation? origin,
    RouteLocation? destination,
  ) {
    final markers = <Marker>[];
    if (origin != null) {
      markers.add(
        Marker(
          point: origin.position,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          point: destination.position,
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
    final origin = ref.watch(selectedOriginProvider);
    final destination = ref.watch(selectedDestinationProvider);
    final polylines = ref.watch(routePolylinesProvider);
    final highlighted = ref.watch(highlightedRouteTypeProvider);
    final heatmapOverlay = ref.watch(heatmapOverlayProvider);
    final heatmapOn = heatmapOverlay != null;
    final routesLoading = ref.watch(routesLoadingProvider);
    final reportTapMode = ref.watch(reportTapModeProvider);
    final pendingReportPin = ref.watch(pendingReportPinProvider);

    ref.listen<bool>(reportTapModeProvider, (previous, next) {
      if (next && previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showReportTapModeSnackBar();
        });
      }
    });

    ref.listen<LatLng?>(highlightReportLocationProvider, (previous, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusSubmittedReport(next);
          ref.read(highlightReportLocationProvider.notifier).state = null;
        });
      }
    });

    return Scaffold(
      appBar: BeeconBrandedAppBar(
        title: const BeeconAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.primary),
            tooltip: 'How it works',
            onPressed: () => showHowItWorksSheet(context),
          ),
          IconButton(
            icon: Icon(
              heatmapOn ? Icons.layers : Icons.layers_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Heatmap',
            onPressed: () {
              if (heatmapOn) {
                ref.read(heatmapOverlayProvider.notifier).state = null;
              } else {
                ref.read(heatmapOverlayProvider.notifier).state =
                    HeatmapOverlay.accessibility;
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'emergency',
        backgroundColor: Colors.red,
        onPressed: () => showEmergencySheet(context, ref),
        child: const Icon(Icons.shield, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationSearchPanel(
                onGetRoutes: routesLoading ? () {} : _getRoutes,
                onOriginChanged: _refreshMapMarkers,
                onDestinationChanged: _refreshMapMarkers,
              ),
              if (routesLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: AppColors.accent,
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => closeLocationSearchDropdown(ref),
                behavior: HitTestBehavior.translucent,
                child: const AiInsightBanner(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      reportTapMode ? _cancelReportTapMode : _startReportTapMode,
                  icon: Icon(
                    reportTapMode
                        ? Icons.close
                        : Icons.report_problem_outlined,
                    color: reportTapMode ? Colors.red : AppColors.primary,
                  ),
                  label: Text(
                    reportTapMode ? 'Cancel' : 'Report an issue',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: reportTapMode ? Colors.red : AppColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: reportTapMode ? Colors.red : AppColors.primary,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => closeLocationSearchDropdown(ref),
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
                              options: _stableMapOptions,
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.beecon.beecon_app',
                                ),
                                PolygonLayer(
                                  polygons: [
                                    Polygon(
                                      points: BgcMapData.boundaryPolygon,
                                      color: BgcMapData.boundaryColor
                                          .withValues(alpha: 0.2),
                                      borderColor: BgcMapData.boundaryColor,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                                if (heatmapOn)
                                  CircleLayer(
                                    circles: heatmapOverlay ==
                                            HeatmapOverlay.safety
                                        ? _buildSafetyHeatmapCircles()
                                        : _buildAccessibilityHeatmapCircles(),
                                  ),
                                if (polylines != null)
                                  PolylineLayer(
                                    polylines: _buildRoutePolylines(
                                      polylines,
                                      highlighted,
                                    ),
                                  ),
                                if (!heatmapOn)
                                  MarkerLayer(
                                    markers: _buildAccessibilityMarkers(),
                                  ),
                                MarkerLayer(
                                  markers: [
                                    ..._buildReportMarkers(reports),
                                    if (pendingReportPin != null)
                                      _buildPendingReportPin(
                                        pendingReportPin,
                                      )!,
                                    ..._buildRouteMarkers(
                                      origin,
                                      destination,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (reportTapMode)
                              Positioned(
                                top: 12,
                                left: 12,
                                right: 12,
                                child: Material(
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.selectedBackground,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.touch_app,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Tap the map to place your report',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _cancelReportTapMode,
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (destination == null && !reportTapMode)
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.all(24),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Search a destination to get started',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                            if (heatmapOn)
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: HeatmapLegend(overlay: heatmapOverlay),
                              ),
                            Positioned(
                              left: 12,
                              bottom: heatmapOn ? 72 : 12,
                              child: _HeatmapModeToggle(
                                activeOverlay: heatmapOverlay,
                                onSelect: (overlay) {
                                  ref
                                      .read(heatmapOverlayProvider.notifier)
                                      .state = overlay;
                                },
                              ),
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
                                    color: Colors.white.withValues(alpha: 0.9),
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
                                        style: GoogleFonts.poppins(fontSize: 12),
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
        ),
      ),
    );
  }
}

class _HeatmapModeToggle extends StatelessWidget {
  const _HeatmapModeToggle({
    required this.activeOverlay,
    required this.onSelect,
  });

  final HeatmapOverlay? activeOverlay;
  final ValueChanged<HeatmapOverlay> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeatmapChip(
            label: 'Accessibility',
            selected: activeOverlay == HeatmapOverlay.accessibility,
            onTap: () => onSelect(HeatmapOverlay.accessibility),
          ),
          _HeatmapChip(
            label: 'Safety',
            selected: activeOverlay == HeatmapOverlay.safety,
            onTap: () => onSelect(HeatmapOverlay.safety),
          ),
        ],
      ),
    );
  }
}

class _HeatmapChip extends StatelessWidget {
  const _HeatmapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
