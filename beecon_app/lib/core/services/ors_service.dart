import 'dart:convert';

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

  /// Builds ORS request URL. Web uses corsproxy.io with api_key in the query
  /// string because proxies often strip Authorization headers.
  String _orsRequestUrl(String apiKey) {
    final orsUrl = '$_orsApiPath?api_key=${Uri.encodeQueryComponent(apiKey)}';
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(orsUrl)}';
    }
    return orsUrl;
  }

  Map<String, String> _orsHeaders(String apiKey) {
    if (kIsWeb) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Authorization': apiKey,
      'Content-Type': 'application/json',
    };
  }

  String? _readApiKey() {
    final apiKey = dotenv.env['ORS_API_KEY']?.trim();
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey == 'your_openrouteservice_key_here') {
      return null;
    }
    return apiKey;
  }

  /// Fetches a walking route polyline.
  /// Web uses OSRM directly (CORS-friendly). Mobile tries ORS then OSRM.
  Future<List<LatLng>> getRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng>? waypoints,
  }) async {
    final route = await _resolveRoute(
      originLat,
      originLng,
      destLat,
      destLng,
      waypoints: waypoints,
    );
    return route ??
        _fallbackPolyline(originLat, originLng, destLat, destLng);
  }

  /// Fetches three route polylines (fastest, accessible, balanced).
  Future<RoutePolylines> getAllRoutes(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final fastest = await _resolveRoute(
      originLat,
      originLng,
      destLat,
      destLng,
    );
    if (fastest == null) {
      return _fallbackPolylines(originLat, originLng, destLat, destLng);
    }

    final midLat = (originLat + destLat) / 2;
    final midLng = (originLng + destLng) / 2;

    final accessible = await _resolveRoute(
          originLat,
          originLng,
          destLat,
          destLng,
          waypoints: [LatLng(midLat + 0.0018, midLng + 0.0012)],
        ) ??
        _offsetPolyline(fastest, 0.0008);

    final balanced = await _resolveRoute(
          originLat,
          originLng,
          destLat,
          destLng,
          waypoints: [LatLng(midLat - 0.0012, midLng - 0.0008)],
        ) ??
        _offsetPolyline(fastest, -0.0008);

    return RoutePolylines(
      fastest: fastest,
      accessible: accessible,
      balanced: balanced,
    );
  }

  Future<List<LatLng>?> _resolveRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng>? waypoints,
  }) async {
    if (kIsWeb) {
      return _fetchOsrmRoute(
        originLat,
        originLng,
        destLat,
        destLng,
        waypoints: waypoints,
      );
    }

    final apiKey = _readApiKey();
    if (apiKey != null) {
      final ors = await _fetchOrsRoute(
        originLat,
        originLng,
        destLat,
        destLng,
        apiKey: apiKey,
        waypoints: waypoints,
      );
      if (ors != null) return ors;
    }

    return _fetchOsrmRoute(
      originLat,
      originLng,
      destLat,
      destLng,
      waypoints: waypoints,
    );
  }

  Future<List<LatLng>?> _fetchOsrmRoute(
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

      final geometry = routes.first['geometry'] as Map<String, dynamic>;
      final coords = _coordsFromGeometry(geometry);
      return coords.length >= 2 ? coords : null;
    } catch (e) {
      _logFailure('OSRM', null, e.toString());
      return null;
    }
  }

  Future<List<LatLng>?> _fetchOrsRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    required String apiKey,
    List<LatLng>? waypoints,
  }) async {
    try {
      final coordinates = <List<double>>[
        [originLng, originLat],
        ...?waypoints?.map((p) => [p.longitude, p.latitude]),
        [destLng, destLat],
      ];

      final response = await http.post(
        Uri.parse(_orsRequestUrl(apiKey)),
        headers: _orsHeaders(apiKey),
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode != 200) {
        _logFailure('ORS', response.statusCode, response.body);
        return null;
      }

      final coords = _decodeOrsCoordinates(response.body);
      return coords.length >= 2 ? coords : null;
    } catch (e) {
      _logFailure('ORS', null, e.toString());
      return null;
    }
  }

  void _logFailure(String provider, int? status, String? detail) {
    if (!kDebugMode) return;
    debugPrint(
      'OrsService: $provider routing failed'
      '${status != null ? ' (HTTP $status)' : ''}'
      '${detail != null ? ': ${detail.length > 120 ? '${detail.substring(0, 120)}...' : detail}' : ''}',
    );
  }

  RoutePolylines _fallbackPolylines(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final direct = _fallbackPolyline(originLat, originLng, destLat, destLng);
    return RoutePolylines(
      fastest: direct,
      accessible: _offsetPolyline(direct, 0.0008),
      balanced: _offsetPolyline(direct, -0.0008),
    );
  }

  List<LatLng> _decodeOrsCoordinates(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data.containsKey('error')) {
      return [];
    }

    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return [];

    final geometry = features.first['geometry'] as Map<String, dynamic>;
    return _coordsFromGeometry(geometry);
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

  List<LatLng> _offsetPolyline(List<LatLng> base, double latOffset) {
    return base
        .map((p) => LatLng(p.latitude + latOffset, p.longitude))
        .toList();
  }
}
