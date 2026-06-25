import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrsService {
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  /// Fetches a walking route polyline from OpenRouteService.
  /// Falls back to a simple interpolated line when the API is unavailable.
  Future<List<LatLng>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final apiKey = dotenv.env['ORS_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
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
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>?;
          if (features != null && features.isNotEmpty) {
            final geometry =
                features.first['geometry'] as Map<String, dynamic>;
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
        }
      }
    } catch (_) {
      // Fall through to interpolated fallback.
    }

    return _fallbackPolyline(originLat, originLng, destLat, destLng);
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
}
