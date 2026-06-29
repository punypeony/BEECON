import 'package:beecon_app/features/routing/models/context_score_model.dart';
import 'package:beecon_app/features/routing/models/route_segment_model.dart';

enum RouteType {
  fastest,
  accessible,
  balanced,
}

class RouteModel {
  const RouteModel({
    required this.id,
    required this.type,
    required this.segments,
    required this.baseScore,
    required this.contextScore,
    required this.totalScore,
    required this.distanceM,
    required this.durationMin,
    required this.warnings,
  });

  final String id;
  final RouteType type;
  final List<RouteSegmentModel> segments;
  final int baseScore;
  final ContextScoreModel contextScore;
  final int totalScore;
  final int distanceM;
  final int durationMin;
  final List<String> warnings;

  String get typeLabel {
    switch (type) {
      case RouteType.fastest:
        return 'Fastest Route';
      case RouteType.accessible:
        return 'Most Accessible Route';
      case RouteType.balanced:
        return 'Balanced Route';
    }
  }
}
