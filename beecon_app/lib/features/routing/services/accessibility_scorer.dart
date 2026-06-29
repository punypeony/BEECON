import 'package:beecon_app/features/routing/models/context_score_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';

class AccessibilityScorer {
  AccessibilityScorer._();

  static const int baseScore = 100;

  static const _eventKeywords = [
    'event',
    'festival',
    'concert',
    'gathering',
    'closure',
    'blocked',
    'crowd',
    'busy',
  ];

  static int scoreSegment(List<RouteSegmentFeature> features) {
    var score = baseScore;
    for (final feature in features) {
      score += _adjustmentFor(feature);
    }
    return score.clamp(0, 100);
  }

  static int averageSegmentScore(List<RouteSegmentModel> segments) {
    if (segments.isEmpty) return 0;
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.segmentScore);
    return (total / segments.length).round();
  }

  /// Returns time-based score modifier and human-readable reason(s).
  static ({int adjustment, List<String> reasons}) getContextualScoreAdjustment([
    DateTime? now,
  ]) {
    now ??= DateTime.now();
    final weekday = now.weekday;
    final hour = now.hour;

    final isWeekday = weekday >= DateTime.monday && weekday <= DateTime.friday;
    final isFriday = weekday == DateTime.friday;
    final isSaturday = weekday == DateTime.saturday;
    final isSunday = weekday == DateTime.sunday;

    if (isFriday && hour >= 17 && hour < 19) {
      return (adjustment: -15, reasons: ['Friday evening rush']);
    }
    if (isWeekday && hour >= 17 && hour < 19) {
      return (adjustment: -10, reasons: ['Evening rush hour']);
    }
    if (isWeekday && hour >= 7 && hour < 9) {
      return (adjustment: -8, reasons: ['Morning rush hour']);
    }
    if (isWeekday && hour >= 12 && hour < 13) {
      return (adjustment: -5, reasons: ['Lunch crowd']);
    }
    if (isSaturday && hour >= 12 && hour < 20) {
      return (adjustment: -8, reasons: ['Weekend crowd']);
    }
    if (isSunday && hour >= 10 && hour < 18) {
      return (adjustment: -5, reasons: ['Weekend leisure crowd']);
    }
    if (isWeekday && hour >= 6 && hour < 7) {
      return (adjustment: 5, reasons: ['Early morning, low crowd']);
    }
    if (isWeekday && (hour >= 21 || hour < 6)) {
      return (adjustment: 3, reasons: ['Low pedestrian traffic']);
    }

    return (adjustment: 0, reasons: <String>[]);
  }

  static ContextScoreModel buildContextScore(int baseRouteScore, [DateTime? now]) {
    now ??= DateTime.now();
    final contextual = getContextualScoreAdjustment(now);
    final adjusted = (baseRouteScore + contextual.adjustment).clamp(0, 100);

    return ContextScoreModel(
      baseScore: baseRouteScore,
      adjustment: contextual.adjustment,
      reasons: contextual.reasons,
      adjustedScore: adjusted,
      timestamp: now,
    );
  }

  static bool detectEventActivity(String text) {
    final lower = text.toLowerCase();
    return _eventKeywords.any(lower.contains);
  }

  static String formatTimeContextLabel([DateTime? now]) {
    now ??= DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final day = days[now.weekday - 1];
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return 'Scores adjusted for $day $displayHour:$minute $period';
  }

  static String formatLiveContextLabel([DateTime? now]) {
    now ??= DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final day = days[now.weekday - 1];
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$day $displayHour:$minute $period — Live context enabled';
  }

  static int _adjustmentFor(RouteSegmentFeature feature) {
    switch (feature) {
      case RouteSegmentFeature.ramp:
        return 15;
      case RouteSegmentFeature.elevator:
        return 20;
      case RouteSegmentFeature.smoothPavement:
        return 10;
      case RouteSegmentFeature.coveredWalkway:
        return 10;
      case RouteSegmentFeature.accessibleEntrance:
        return 15;
      case RouteSegmentFeature.tactilePaving:
        return 10;
      case RouteSegmentFeature.stairs:
        return -50;
      case RouteSegmentFeature.brokenElevator:
        return -30;
      case RouteSegmentFeature.construction:
        return -30;
      case RouteSegmentFeature.steepIncline:
        return -20;
      case RouteSegmentFeature.narrowPathway:
        return -15;
    }
  }
}
