import 'dart:convert';

import 'package:beecon_app/features/routing/models/route_polylines.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrsService {
  static const String _orsApiPath =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  /// Builds request URL. Web uses corsproxy.io (API key in query string because
  /// proxies often strip Authorization headers).
  String _requestUrl(String apiKey) {
    final orsUrl = '$_orsApiPath?api_key=${Uri.encodeQueryComponent(apiKey)}';
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(orsUrl)}';
    }
    return orsUrl;
  }

  Map<String, String> _headers(String apiKey) {
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

  /// Fetches a walking route polyline from OpenRouteService.
  /// Falls back to a straight line when the API is unavailable.
  Future<List<LatLng>> getRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng>? waypoints,
  }) async {
    final apiKey = _readApiKey();
    if (apiKey == null) {
      return _fallbackPolyline(originLat, originLng, destLat, destLng);
    }

    try {
      final coordinates = <List<double>>[
        [originLng, originLat],
        ...?waypoints?.map((p) => [p.longitude, p.latitude]),
        [destLng, destLat],
      ];

      final response = await http.post(
        Uri.parse(_requestUrl(apiKey)),
        headers: _headers(apiKey),
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeCoordinates(response.body);
        if (decoded.length >= 2) return decoded;
      }
    } catch (_) {
      // Fall through to fallback.
    }

    return _fallbackPolyline(originLat, originLng, destLat, destLng);
  }

  /// Fetches three route polylines (fastest, accessible, balanced).
  Future<RoutePolylines> getAllRoutes(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final apiKey = _readApiKey();
    if (apiKey == null) {
      return _fallbackPolylines(originLat, originLng, destLat, destLng);
    }

    try {
      // Primary direct route (avoid alternative_routes — often fails on free tier).
      final fastest = await getRoute(originLat, originLng, destLat, destLng);
      final usedFallback = fastest.length == 12 &&
          _isStraightFallback(fastest, originLat, originLng, destLat, destLng);

      if (usedFallback) {
        return _fallbackPolylines(originLat, originLng, destLat, destLng);
      }

      final midLat = (originLat + destLat) / 2;
      final midLng = (originLng + destLng) / 2;

      final accessible = await getRoute(
        originLat,
        originLng,
        destLat,
        destLng,
        waypoints: [LatLng(midLat + 0.0018, midLng + 0.0012)],
      );

      final balanced = await getRoute(
        originLat,
        originLng,
        destLat,
        destLng,
        waypoints: [LatLng(midLat - 0.0012, midLng - 0.0008)],
      );

      return RoutePolylines(
        fastest: fastest,
        accessible: accessible,
        balanced: balanced,
      );
    } catch (_) {
      return _fallbackPolylines(originLat, originLng, destLat, destLng);
    }
  }

  bool _isStraightFallback(
    List<LatLng> points,
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    if (points.length != 12) return false;
    final first = points.first;
    final last = points.last;
    return (first.latitude - originLat).abs() < 0.0001 &&
        (first.longitude - originLng).abs() < 0.0001 &&
        (last.latitude - destLat).abs() < 0.0001 &&
        (last.longitude - destLng).abs() < 0.0001;
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

  List<LatLng> _decodeCoordinates(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data.containsKey('error')) {
      return [];
    }

    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return [];

    return _coordsFromFeature(features.first);
  }

  List<LatLng> _coordsFromFeature(dynamic feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
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
