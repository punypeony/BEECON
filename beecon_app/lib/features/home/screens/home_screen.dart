import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/services/ors_service.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/utils/time_utils.dart';
import 'package:beecon_app/features/home/data/bgc_accessibility_data.dart';
import 'package:beecon_app/features/home/screens/widgets/ai_insight_banner.dart';
import 'package:beecon_app/features/home/screens/widgets/location_search_panel.dart';
import 'package:beecon_app/features/reports/models/report_model.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
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

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
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

  void _refreshMapMarkers() {
    final origin = ref.read(selectedOriginProvider);
    final destination = ref.read(selectedDestinationProvider);

    if (origin != null && destination != null) {
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

    final polyline = await _orsService.getRoute(
      originLat: origin.lat,
      originLng: origin.lng,
      destLat: destination.lat,
      destLng: destination.lng,
    );

    ref.read(routePolylineProvider.notifier).state = polyline;
    _fitMapToPoints([origin.position, destination.position, ...polyline]);

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

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(48),
      ),
    );
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                          const Icon(Icons.verified,
                              size: 14, color: Colors.green),
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
              const Icon(Icons.warning, color: Colors.red, size: 28),
            ],
          ),
        ),
      );
    }).toList();
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

  List<Marker> _buildOverlayMarkers(
    List<ReportModel> reports,
    RouteLocation? origin,
    RouteLocation? destination,
  ) {
    return [
      ..._buildAccessibilityMarkers(),
      ..._buildReportMarkers(reports),
      ..._buildRouteMarkers(origin, destination),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(selectedOriginProvider);
    final destination = ref.watch(selectedDestinationProvider);
    final routePolyline = ref.watch(routePolylineProvider);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationSearchPanel(
                onGetRoutes: _getRoutes,
                onOriginChanged: _refreshMapMarkers,
                onDestinationChanged: _refreshMapMarkers,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => closeLocationSearchDropdown(ref),
                behavior: HitTestBehavior.translucent,
                child: const AiInsightBanner(),
              ),
              const SizedBox(height: 4),
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
                              options: MapOptions(
                                initialCenter: BgcMapData.center,
                                initialZoom: BgcMapData.defaultZoom,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
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
                                          .withValues(alpha: 0.3),
                                      borderColor: BgcMapData.boundaryColor,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                                if (routePolyline.length >= 2)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: routePolyline,
                                        color: AppColors.primary,
                                        strokeWidth: 4,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: _buildOverlayMarkers(
                                    reports,
                                    origin,
                                    destination,
                                  ),
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
