import 'dart:convert';

import 'package:beecon_app/core/services/ors_route_result.dart';
import 'package:beecon_app/features/routing/models/route_polylines.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrsService {
  static const String _orsApiPath =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';
  static const String _osrmBase =
      'https://router.project-osrm.org/route/v1/foot';

  String? _readApiKey() {
    final apiKey = dotenv.env['ORS_API_KEY']?.trim();
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey == 'your_openrouteservice_key_here') {
      return null;
    }
    return apiKey;
  }

  /// Fetches three walking routes. Web uses OSRM (CORS-friendly). Mobile uses ORS
  /// directly, then OSRM, then straight-line fallback per route.
  Future<OrsRouteBundle> getAllRoutes(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    if (kIsWeb) {
      final osrm = await _fetchOsrmBundle(
        originLat,
        originLng,
        destLat,
        destLng,
      );
      if (osrm != null) return osrm;
      return _fallbackBundle(originLat, originLng, destLat, destLng);
    }

    final apiKey = _readApiKey();
    if (apiKey != null) {
      final ors = await _fetchOrsBundle(
        apiKey: apiKey,
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );
      if (ors != null && !ors.anyFallback) return ors;
    }

    final osrm = await _fetchOsrmBundle(
      originLat,
      originLng,
      destLat,
      destLng,
    );
    if (osrm != null) return osrm;

    return _fallbackBundle(originLat, originLng, destLat, destLng);
  }

  RoutePolylines polylinesFromBundle(
    OrsRouteBundle bundle, {
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final origin = LatLng(originLat, originLng);
    final destination = LatLng(destLat, destLng);

    return RoutePolylines(
      fastest: _snapPolylineToPins(bundle.fastest.polylinePoints, origin, destination),
      accessible: _snapPolylineToPins(bundle.accessible.polylinePoints, origin, destination),
      balanced: _snapPolylineToPins(bundle.balanced.polylinePoints, origin, destination),
    );
  }

  OrsRouteBundle snapBundleToPins(
    OrsRouteBundle bundle, {
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final origin = LatLng(originLat, originLng);
    final destination = LatLng(destLat, destLng);

    OrsRouteResult snap(OrsRouteResult route) {
      return OrsRouteResult(
        routeType: route.routeType,
        polylinePoints: _snapPolylineToPins(route.polylinePoints, origin, destination),
        distanceM: route.distanceM,
        durationMin: route.durationMin,
        isFallback: route.isFallback,
      );
    }

    return OrsRouteBundle(
      fastest: snap(bundle.fastest),
      accessible: snap(bundle.accessible),
      balanced: snap(bundle.balanced),
    );
  }

  List<LatLng> _snapPolylineToPins(
    List<LatLng> points,
    LatLng origin,
    LatLng destination,
  ) {
    if (points.length < 2) {
      return [origin, destination];
    }

    final snapped = List<LatLng>.from(points);
    snapped[0] = origin;
    snapped[snapped.length - 1] = destination;
    return snapped;
  }

  Future<OrsRouteBundle?> _fetchOsrmBundle(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final alternatives = await _fetchOsrmAlternatives(
      originLat,
      originLng,
      destLat,
      destLng,
    );
    if (alternatives != null && alternatives.length >= 2) {
      return _bundleFromOsrmRoutes(alternatives);
    }

    final fastest = await _fetchOsrmRoute(
      originLat,
      originLng,
      destLat,
      destLng,
    );
    if (fastest == null) return null;

    final midLat = (originLat + destLat) / 2;
    final midLng = (originLng + destLng) / 2;

    final accessible = await _fetchOsrmRoute(
          originLat,
          originLng,
          destLat,
          destLng,
          waypoints: [LatLng(midLat + 0.0018, midLng + 0.0012)],
        ) ??
        _offsetPolylineResult(fastest, 0.0008, 'Most Accessible');

    final balanced = await _fetchOsrmRoute(
          originLat,
          originLng,
          destLat,
          destLng,
          waypoints: [LatLng(midLat - 0.0012, midLng - 0.0008)],
        ) ??
        _offsetPolylineResult(fastest, -0.0008, 'Balanced');

    return OrsRouteBundle(
      fastest: fastest,
      accessible: accessible,
      balanced: balanced,
    );
  }

  Future<List<OrsRouteResult>?> _fetchOsrmAlternatives(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    try {
      final coords = '$originLng,$originLat;$destLng,$destLat';
      final url =
          '$_osrmBase/$coords?overview=full&geometries=geojson&alternatives=2';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _logFailure('OSRM', response.statusCode, response.body);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        _logFailure('OSRM', response.statusCode, data['message']?.toString());
        return null;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      return routes
          .map((route) => _parseOsrmRoute(route as Map<String, dynamic>))
          .whereType<OrsRouteResult>()
          .toList();
    } catch (e) {
      _logFailure('OSRM', null, e.toString());
      return null;
    }
  }

  OrsRouteBundle _bundleFromOsrmRoutes(List<OrsRouteResult> routes) {
    final byDuration = [...routes]
      ..sort((a, b) => a.durationMin.compareTo(b.durationMin));

    final fastest = byDuration.first.copyWith(routeType: 'Fastest');
    final balanced = byDuration.length > 2
        ? byDuration[1].copyWith(routeType: 'Balanced')
        : byDuration.last.copyWith(routeType: 'Balanced');
    final accessible = byDuration.last.copyWith(routeType: 'Most Accessible');

    return OrsRouteBundle(
      fastest: fastest,
      accessible: accessible,
      balanced: balanced,
    );
  }

  Future<OrsRouteResult?> _fetchOsrmRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng>? waypoints,
  }) async {
    try {
      final parts = <String>[
        '$originLng,$originLat',
        ...?waypoints?.map((p) => '${p.longitude},${p.latitude}'),
        '$destLng,$destLat',
      ];
      final url =
          '$_osrmBase/${parts.join(';')}?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _logFailure('OSRM', response.statusCode, response.body);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        _logFailure('OSRM', response.statusCode, data['message']?.toString());
        return null;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      return _parseOsrmRoute(routes.first as Map<String, dynamic>);
    } catch (e) {
      _logFailure('OSRM', null, e.toString());
      return null;
    }
  }

  OrsRouteResult? _parseOsrmRoute(Map<String, dynamic> route) {
    final geometry = route['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return null;

    final points = _coordsFromGeometry(geometry);
    if (points.length < 2) return null;

    return OrsRouteResult(
      routeType: 'Route',
      polylinePoints: points,
      distanceM: (route['distance'] as num?)?.toDouble() ?? 0,
      durationMin: ((route['duration'] as num?)?.toDouble() ?? 0) / 60,
      isFallback: false,
    );
  }

  OrsRouteResult _offsetPolylineResult(
    OrsRouteResult base,
    double latOffset,
    String routeType,
  ) {
    final points = base.polylinePoints
        .map((p) => LatLng(p.latitude + latOffset, p.longitude))
        .toList();

    return OrsRouteResult(
      routeType: routeType,
      polylinePoints: points,
      distanceM: base.distanceM * 1.08,
      durationMin: base.durationMin * 1.08,
      isFallback: false,
    );
  }

  Future<OrsRouteBundle?> _fetchOrsBundle({
    required String apiKey,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final results = await Future.wait([
      _fetchOrsVariant(
        apiKey: apiKey,
        routeType: 'Fastest',
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        body: {
          'coordinates': [
            [originLng, originLat],
            [destLng, destLat],
          ],
          'preference': 'fastest',
          'units': 'm',
        },
      ),
      _fetchOrsVariant(
        apiKey: apiKey,
        routeType: 'Most Accessible',
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        body: {
          'coordinates': [
            [originLng, originLat],
            [destLng, destLat],
          ],
          'avoid_features': ['steps', 'steep_slopes'],
          'extra_info': ['waytype', 'surface', 'steepness'],
          'preference': 'recommended',
          'units': 'm',
        },
      ),
      _fetchOrsVariant(
        apiKey: apiKey,
        routeType: 'Balanced',
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
        body: {
          'coordinates': [
            [originLng, originLat],
            [destLng, destLat],
          ],
          'avoid_features': ['steps'],
          'preference': 'shortest',
          'units': 'm',
        },
      ),
    ]);

    if (results.every((r) => r.isFallback)) return null;

    return OrsRouteBundle(
      fastest: results[0],
      accessible: results[1],
      balanced: results[2],
    );
  }

  Future<OrsRouteResult> _fetchOrsVariant({
    required String apiKey,
    required String routeType,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_orsApiPath),
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        _logFailure('ORS', response.statusCode, response.body);
        return _fallbackResult(
          routeType,
          originLat,
          originLng,
          destLat,
          destLng,
        );
      }

      final parsed = _parseOrsResponse(response.body, routeType);
      if (parsed != null) return parsed;

      return _fallbackResult(
        routeType,
        originLat,
        originLng,
        destLat,
        destLng,
      );
    } catch (e) {
      _logFailure('ORS', null, e.toString());
      return _fallbackResult(
        routeType,
        originLat,
        originLng,
        destLat,
        destLng,
      );
    }
  }

  OrsRouteResult? _parseOrsResponse(String body, String routeType) {
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data.containsKey('error')) return null;

    final features = data['features'] as List<dynamic>?;
    if (features != null && features.isNotEmpty) {
      final feature = features.first as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final summary = props['summary'] as Map<String, dynamic>? ?? {};
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      if (geometry == null) return null;

      final points = _coordsFromGeometry(geometry);
      if (points.length < 2) return null;

      return OrsRouteResult(
        routeType: routeType,
        polylinePoints: points,
        distanceM: (summary['distance'] as num?)?.toDouble() ?? 0,
        durationMin: ((summary['duration'] as num?)?.toDouble() ?? 0) / 60,
        isFallback: false,
      );
    }

    return null;
  }

  OrsRouteBundle _fallbackBundle(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    return OrsRouteBundle(
      fastest: _fallbackResult(
        'Fastest',
        originLat,
        originLng,
        destLat,
        destLng,
      ),
      accessible: _fallbackResult(
        'Most Accessible',
        originLat,
        originLng,
        destLat,
        destLng,
        latOffset: 0.0008,
      ),
      balanced: _fallbackResult(
        'Balanced',
        originLat,
        originLng,
        destLat,
        destLng,
        latOffset: -0.0008,
      ),
    );
  }

  OrsRouteResult _fallbackResult(
    String routeType,
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    double latOffset = 0,
  }) {
    var points = _fallbackPolyline(originLat, originLng, destLat, destLng);
    if (latOffset != 0) {
      points = points
          .map((p) => LatLng(p.latitude + latOffset, p.longitude))
          .toList();
    }

    const distance = Distance();
    final distanceM = distance.as(
      LengthUnit.Meter,
      LatLng(originLat, originLng),
      LatLng(destLat, destLng),
    );

    return OrsRouteResult(
      routeType: routeType,
      polylinePoints: points,
      distanceM: distanceM,
      durationMin: distanceM / 75,
      isFallback: true,
    );
  }

  List<LatLng> _coordsFromGeometry(Map<String, dynamic> geometry) {
    final type = geometry['type'] as String? ?? 'LineString';
    final coords = geometry['coordinates'] as List<dynamic>;

    List<dynamic> lineCoords;
    if (type == 'MultiLineString') {
      if (coords.isEmpty) return [];
      lineCoords = coords.first as List<dynamic>;
    } else {
      lineCoords = coords;
    }

    return lineCoords
        .map(
          (c) => LatLng(
            (c[1] as num).toDouble(),
            (c[0] as num).toDouble(),
          ),
        )
        .toList();
  }

  List<LatLng> _fallbackPolyline(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    return List.generate(12, (index) {
      final t = index / 11;
      return LatLng(
        originLat + (destLat - originLat) * t,
        originLng + (destLng - originLng) * t,
      );
    });
  }

  void _logFailure(String provider, int? status, String? detail) {
    if (!kDebugMode) return;
    debugPrint(
      'OrsService: $provider routing failed'
      '${status != null ? ' (HTTP $status)' : ''}'
      '${detail != null ? ': ${detail.length > 120 ? '${detail.substring(0, 120)}...' : detail}' : ''}',
    );
  }
}

extension on OrsRouteResult {
  OrsRouteResult copyWith({String? routeType}) {
    return OrsRouteResult(
      routeType: routeType ?? this.routeType,
      polylinePoints: polylinePoints,
      distanceM: distanceM,
      durationMin: durationMin,
      isFallback: isFallback,
    );
  }
}
