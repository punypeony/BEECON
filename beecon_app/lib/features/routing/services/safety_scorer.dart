import 'package:beecon_app/features/routing/models/safety_score_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:latlong2/latlong.dart';

class SecurityPost {
  const SecurityPost({
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String name;
  final double lat;
  final double lng;

  LatLng get position => LatLng(lat, lng);
}

class NearestSecurityResult {
  const NearestSecurityResult({
    required this.post,
    required this.distanceM,
  });

  final SecurityPost post;
  final int distanceM;
}

class SafetyScorer {
  SafetyScorer._();

  static const int baseScore = 100;

  static const _mainRoadKeywords = [
    'high street',
    '5th ave',
    '5th avenue',
    'bonifacio drive',
    'market market',
    'market! market!',
  ];

  static const _securityPosts = [
    SecurityPost(
      name: 'BGC Police Community Precinct',
      lat: 14.5503,
      lng: 121.0495,
    ),
    SecurityPost(
      name: 'BGC Security HQ (High Street)',
      lat: 14.5547,
      lng: 121.0507,
    ),
    SecurityPost(
      name: 'Market Market Security Post',
      lat: 14.5514,
      lng: 121.0500,
    ),
    SecurityPost(
      name: 'Uptown BGC Security',
      lat: 14.5600,
      lng: 121.0514,
    ),
  ];

  static const _safetyKeywords = [
    'crime',
    'unsafe',
    'incident',
    'robbery',
    'snatch',
    'dark',
    'avoid',
    'warning',
    'alert',
  ];

  static List<SecurityPost> get securityPosts => _securityPosts;

  static bool detectSafetyAdvisory(String text) {
    final lower = text.toLowerCase();
    return _safetyKeywords.any(lower.contains);
  }

  static NearestSecurityResult nearestSecurityPost(double lat, double lng) {
    const distance = Distance();
    SecurityPost nearest = _securityPosts.first;
    var minM = distance.as(
      LengthUnit.Meter,
      LatLng(lat, lng),
      _securityPosts.first.position,
    );

    for (final post in _securityPosts.skip(1)) {
      final d = distance.as(
        LengthUnit.Meter,
        LatLng(lat, lng),
        post.position,
      );
      if (d < minM) {
        minM = d;
        nearest = post;
      }
    }

    return NearestSecurityResult(
      post: nearest,
      distanceM: minM.round(),
    );
  }

  static SafetyScoreModel buildSafetyScore({
    required double midLat,
    required double midLng,
    required String originLabel,
    required String destinationLabel,
    DateTime? now,
    int eventAdjustment = 0,
    int geminiAdjustment = 0,
  }) {
    now ??= DateTime.now();
    final reasons = <String>[];

    final timeParts = _timeAdjustments(now, reasons);
    final crowdParts = _crowdAdjustments(now, reasons);
    final securityParts = _securityDistanceAdjustment(midLat, midLng, reasons);
    final lightingParts = _lightingAdjustment(
      originLabel,
      destinationLabel,
      now,
      reasons,
    );

    final timeAdjustment =
        timeParts + securityParts + lightingParts;
    final crowdAdjustment = crowdParts;

    var eventAdj = eventAdjustment;
    if (eventAdj != 0 && !reasons.contains('Event/festival detected nearby')) {
      reasons.add('Event/festival detected nearby');
    }
    var geminiAdj = geminiAdjustment;
    if (geminiAdj != 0 && !reasons.contains('Safety advisory detected')) {
      reasons.add('Safety advisory detected');
    }

    final finalScore = (baseScore +
            timeAdjustment +
            crowdAdjustment +
            eventAdj +
            geminiAdj)
        .clamp(0, 100);

    return SafetyScoreModel(
      baseScore: baseScore,
      timeAdjustment: timeAdjustment,
      crowdAdjustment: crowdAdjustment,
      eventAdjustment: eventAdj,
      geminiAdjustment: geminiAdj,
      finalScore: finalScore,
      reasons: reasons,
      riskLevel: SafetyScoreModel.riskLevelForScore(finalScore),
    );
  }

  static int _timeAdjustments(DateTime now, List<String> reasons) {
    var adj = 0;
    final hour = now.hour;
    final weekday = now.weekday;

    if (hour >= 6 && hour < 18) {
      reasons.add('Daytime hours');
    } else if (hour >= 18 && hour < 21) {
      adj -= 10;
      reasons.add('Evening, reduced visibility');
    } else if (hour >= 21 && hour < 24) {
      adj -= 20;
      reasons.add('Night hours, low foot traffic');
    } else if (hour >= 0 && hour < 5) {
      adj -= 35;
      reasons.add('Late night, high risk');
    } else if (hour >= 5 && hour < 6) {
      adj -= 15;
      reasons.add('Pre-dawn hours');
    }

    if (weekday == DateTime.friday && hour >= 21) {
      adj -= 10;
      reasons.add('Friday night');
    } else if (weekday == DateTime.saturday && hour >= 21) {
      adj -= 15;
      reasons.add('Saturday night');
    } else if (weekday == DateTime.sunday && hour >= 21) {
      adj -= 10;
      reasons.add('Sunday night');
    }

    return adj;
  }

  static int _crowdAdjustments(DateTime now, List<String> reasons) {
    var adj = 0;
    final hour = now.hour;
    final contextual = AccessibilityScorer.getContextualScoreAdjustment(now);

    if (contextual.adjustment < 0 &&
        (hour >= 7 && hour < 9 ||
            hour >= 12 && hour < 13 ||
            hour >= 17 && hour < 19 ||
            (now.weekday == DateTime.saturday &&
                hour >= 12 &&
                hour < 20) ||
            (now.weekday == DateTime.sunday &&
                hour >= 10 &&
                hour < 18))) {
      adj -= 5;
      reasons.add('Crowded, watch belongings');
    }

    if ((hour >= 21 || hour < 5) && contextual.adjustment >= 0) {
      adj -= 15;
      reasons.add('Empty streets, stay alert');
    }

    return adj;
  }

  static int _securityDistanceAdjustment(
    double lat,
    double lng,
    List<String> reasons,
  ) {
    final nearest = nearestSecurityPost(lat, lng);
    final d = nearest.distanceM;

    if (d <= 200) {
      reasons.add('Near security post');
      return 10;
    }
    if (d <= 500) {
      reasons.add('Security post nearby');
      return 0;
    }
    if (d <= 1000) {
      reasons.add('Far from security post');
      return -5;
    }
    reasons.add('No security post nearby');
    return -15;
  }

  static int _lightingAdjustment(
    String originLabel,
    String destinationLabel,
    DateTime now,
    List<String> reasons,
  ) {
    final hour = now.hour;
    final isNight = hour >= 18 || hour < 6;
    final onMainRoad = _isMainRoad(originLabel) || _isMainRoad(destinationLabel);

    if (onMainRoad) {
      if (isNight) {
        reasons.add('Well-lit main road');
      }
      return 0;
    }

    if (isNight) {
      reasons.add('Potentially dim lighting');
      return -10;
    }

    return 0;
  }

  static bool _isMainRoad(String label) {
    final lower = label.toLowerCase();
    return _mainRoadKeywords.any(lower.contains);
  }

  static const Map<String, int> _reasonDeltas = {
    'Daytime hours': 0,
    'Evening, reduced visibility': -10,
    'Night hours, low foot traffic': -20,
    'Late night, high risk': -35,
    'Pre-dawn hours': -15,
    'Friday night': -10,
    'Saturday night': -15,
    'Sunday night': -10,
    'Crowded, watch belongings': -5,
    'Empty streets, stay alert': -15,
    'Near security post': 10,
    'Security post nearby': 0,
    'Far from security post': -5,
    'No security post nearby': -15,
    'Well-lit main road': 0,
    'Potentially dim lighting': -10,
    'Event/festival detected nearby': -10,
    'Safety advisory detected': -15,
  };

  static int adjustmentDeltaForReason(String reason) {
    return _reasonDeltas[reason] ?? 0;
  }
}
