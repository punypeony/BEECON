class ContextScoreModel {
  const ContextScoreModel({
    required this.baseScore,
    required this.adjustment,
    required this.reasons,
    required this.adjustedScore,
    required this.timestamp,
  });

  final int baseScore;
  final int adjustment;
  final List<String> reasons;
  final int adjustedScore;
  final DateTime timestamp;

  ContextScoreModel withEventPenalty({int penalty = -10}) {
    if (reasons.contains('Event/festival detected nearby')) return this;

    return ContextScoreModel(
      baseScore: baseScore,
      adjustment: adjustment + penalty,
      reasons: [...reasons, 'Event/festival detected nearby'],
      adjustedScore: (adjustedScore + penalty).clamp(0, 100),
      timestamp: timestamp,
    );
  }

  bool get hasNegativeAdjustment => adjustment < 0;
  bool get hasPositiveAdjustment => adjustment > 0;
}
