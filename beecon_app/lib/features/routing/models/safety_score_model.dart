class SafetyScoreModel {
  const SafetyScoreModel({
    required this.baseScore,
    required this.timeAdjustment,
    required this.crowdAdjustment,
    required this.eventAdjustment,
    required this.geminiAdjustment,
    required this.finalScore,
    required this.reasons,
    required this.riskLevel,
  });

  final int baseScore;
  final int timeAdjustment;
  final int crowdAdjustment;
  final int eventAdjustment;
  final int geminiAdjustment;
  final int finalScore;
  final List<String> reasons;
  final String riskLevel;

  int get totalAdjustment =>
      timeAdjustment + crowdAdjustment + eventAdjustment + geminiAdjustment;

  SafetyScoreModel withEventPenalty({int penalty = -10}) {
    if (reasons.contains('Event/festival detected nearby')) return this;
    return _copyWith(
      eventAdjustment: eventAdjustment + penalty,
      extraReasons: ['Event/festival detected nearby'],
    );
  }

  SafetyScoreModel withGeminiAdvisory({int penalty = -15}) {
    if (reasons.contains('Safety advisory detected')) return this;
    return _copyWith(
      geminiAdjustment: geminiAdjustment + penalty,
      extraReasons: ['Safety advisory detected'],
    );
  }

  SafetyScoreModel _copyWith({
    int? eventAdjustment,
    int? geminiAdjustment,
    List<String>? extraReasons,
  }) {
    final newEvent = eventAdjustment ?? this.eventAdjustment;
    final newGemini = geminiAdjustment ?? this.geminiAdjustment;
    final newReasons = [...reasons, ...?extraReasons];
    final newFinal = (baseScore +
            timeAdjustment +
            crowdAdjustment +
            newEvent +
            newGemini)
        .clamp(0, 100);

    return SafetyScoreModel(
      baseScore: baseScore,
      timeAdjustment: timeAdjustment,
      crowdAdjustment: crowdAdjustment,
      eventAdjustment: newEvent,
      geminiAdjustment: newGemini,
      finalScore: newFinal,
      reasons: newReasons,
      riskLevel: SafetyScoreModel.riskLevelForScore(newFinal),
    );
  }

  static String riskLevelForScore(int score) {
    if (score >= 80) return 'Low Risk';
    if (score >= 50) return 'Moderate Risk';
    return 'High Risk';
  }
}
