import 'dart:convert';

import 'package:beecon_app/features/routing/models/route_polylines.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrsService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  /// Fetches a walking route polyline from OpenRouteService.
  /// Falls back to a straight line when the API is unavailable.
  Future<List<LatLng>> getRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    List<LatLng>? waypoints,
  }) async {
    try {
      final apiKey = dotenv.env['ORS_API_KEY'];
      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openrouteservice_key_here') {
        return _fallbackPolyline(originLat, originLng, destLat, destLng);
      }

      final coordinates = <List<double>>[
        [originLng, originLat],
        ...?waypoints?.map((p) => [p.longitude, p.latitude]),
        [destLng, destLat],
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coordinates': coordinates}),
      );

      if (response.statusCode == 200) {
        final decoded = _decodeCoordinates(response.body);
        if (decoded.isNotEmpty) return decoded;
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
    try {
      final apiKey = dotenv.env['ORS_API_KEY'];
      if (apiKey != null &&
          apiKey.isNotEmpty &&
          apiKey != 'your_openrouteservice_key_here') {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Authorization': apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'coordinates': [
              [originLng, originLat],
              [destLng, destLat],
            ],
            'alternative_routes': {
              'target_count': 2,
              'share_factor': 0.5,
            },
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.length >= 3) {
            return RoutePolylines(
              fastest: _coordsFromFeature(features[0]),
              balanced: _coordsFromFeature(features[1]),
              accessible: _coordsFromFeature(features[2]),
            );
          }
          if (features != null && features.isNotEmpty) {
            final primary = _coordsFromFeature(features[0]);
            return RoutePolylines(
              fastest: primary,
              accessible: await getRoute(
                originLat,
                originLng,
                destLat,
                destLng,
                waypoints: [
                  LatLng(
                    (originLat + destLat) / 2 + 0.0015,
                    (originLng + destLng) / 2,
                  ),
                ],
              ),
              balanced: features.length > 1
                  ? _coordsFromFeature(features[1])
                  : await getRoute(
                      originLat,
                      originLng,
                      destLat,
                      destLng,
                      waypoints: [
                        LatLng(
                          (originLat + destLat) / 2 - 0.0015,
                          (originLng + destLng) / 2,
                        ),
                      ],
                    ),
            );
          }
        }
      }
    } catch (_) {
      // Fall through.
    }

    final direct = _fallbackPolyline(originLat, originLng, destLat, destLng);
    return RoutePolylines(
      fastest: direct,
      accessible: _offsetPolyline(direct, 0.0008),
      balanced: _offsetPolyline(direct, -0.0008),
    );
  }

  List<LatLng> _decodeCoordinates(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return [];
    return _coordsFromFeature(features.first);
  }

  List<LatLng> _coordsFromFeature(dynamic feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coords = geometry['coordinates'] as List<dynamic>;
    return coords
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
