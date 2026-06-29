import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:beecon_app/core/widgets/responsive_layout.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/services/gemini_service.dart';
import 'package:beecon_app/core/storage/ai_insight_storage.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/features/routing/models/context_score_model.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/safety_score_model.dart';
import 'package:beecon_app/features/routing/services/accessibility_scorer.dart';
import 'package:beecon_app/features/routing/services/route_generator.dart';
import 'package:beecon_app/features/routing/services/safety_scorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class RouteResultsScreen extends ConsumerStatefulWidget {
  const RouteResultsScreen({super.key});

  @override
  ConsumerState<RouteResultsScreen> createState() =>
      _RouteResultsScreenState();
}

class _RouteResultsScreenState extends ConsumerState<RouteResultsScreen> {
  final GeminiService _geminiService = GeminiService();

  String? _selectedRouteId;
  bool _insightLoading = false;
  String? _insightText;
  String? _accessibilityInsight;
  String? _safetyTip;
  ContextScoreModel? _selectedContextScore;
  SafetyScoreModel? _selectedSafetyScore;
  bool _eventPenaltyApplied = false;
  bool _safetyAdvisoryApplied = false;
  bool _webSearchUsed = false;

  Color _scoreBadgeColor(int score) => scoreBadgeColor(score);

  void _resetRouteSelection() {
    _selectedRouteId = null;
    _insightLoading = false;
    _insightText = null;
    _accessibilityInsight = null;
    _safetyTip = null;
    _selectedContextScore = null;
    _selectedSafetyScore = null;
    _eventPenaltyApplied = false;
    _safetyAdvisoryApplied = false;
    _webSearchUsed = false;
  }

  ContextScoreModel _displayContextFor(RouteModel route) {
    if (_selectedRouteId == route.id && _selectedContextScore != null) {
      return _selectedContextScore!;
    }
    return route.contextScore;
  }

  SafetyScoreModel _displaySafetyFor(RouteModel route) {
    if (_selectedRouteId == route.id && _selectedSafetyScore != null) {
      return _selectedSafetyScore!;
    }
    return route.safetyScore;
  }

  Future<void> _selectRoute(
    RouteModel route,
    RouteLocation origin,
    RouteLocation destination,
  ) async {
    setState(() {
      _selectedRouteId = route.id;
      _insightLoading = true;
      _insightText = null;
      _accessibilityInsight = null;
      _safetyTip = null;
      _selectedContextScore = route.contextScore;
      _selectedSafetyScore = route.safetyScore;
      _eventPenaltyApplied = false;
      _safetyAdvisoryApplied = false;
      _webSearchUsed = false;
    });

    ref.read(highlightedRouteTypeProvider.notifier).state = route.type;

    final displayContext = _displayContextFor(route);
    final displaySafety = _displaySafetyFor(route);

    await HiveService.saveRoute(
      route.copyWithScores(
        context: displayContext,
        safety: displaySafety,
      ),
      originLabel: origin.label,
      destinationLabel: destination.label,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${route.typeLabel} selected',
          style: GoogleFonts.poppins(),
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final mobilityProfile =
        prefs.getString(AppConstants.selectedProfileKey) ?? 'General';

    final contextScore = route.contextScore;
    var safetyScore = route.safetyScore;

    try {
      final hasConnection = await HiveService.hasConnectivity();
      if (!hasConnection) {
        throw Exception('No internet connection');
      }

      final result = await _geminiService.getAccessibilityInsight(
        mobilityProfile: mobilityProfile,
        routeType: route.typeLabel,
        accessibilityScore: contextScore.adjustedScore,
        safetyScore: safetyScore.finalScore,
        warnings: route.warnings,
        origin: origin.label,
        destination: destination.label,
        timeAdjustmentReasons: contextScore.reasons,
      );

      var updatedContext = contextScore;
      var updatedSafety = safetyScore;
      var eventApplied = false;
      var safetyAdvisoryApplied = false;

      if (result.eventDetected) {
        updatedContext = contextScore.withEventPenalty();
        updatedSafety = safetyScore.withEventPenalty();
        eventApplied = true;
      }

      if (result.safetyAdvisoryDetected) {
        updatedSafety = updatedSafety.withGeminiAdvisory();
        safetyAdvisoryApplied = true;
      }

      await AiInsightStorage.saveInsight(
        routeId: route.id,
        insight: result.text,
      );

      if (!mounted) return;
      setState(() {
        _insightText = result.text;
        _accessibilityInsight = result.accessibilityInsight;
        _safetyTip = result.safetyTip;
        _insightLoading = false;
        _selectedContextScore = updatedContext;
        _selectedSafetyScore = updatedSafety;
        _eventPenaltyApplied = eventApplied;
        _safetyAdvisoryApplied = safetyAdvisoryApplied;
        _webSearchUsed = result.webSearchUsed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightText = _geminiService.buildFallbackInsight(
          adjustedScore: contextScore.adjustedScore,
          mobilityProfile: mobilityProfile,
          safetyScore: safetyScore.finalScore,
          timeAdjustmentReasons: contextScore.reasons,
        );
        _accessibilityInsight = _geminiService.buildFallbackAccessibilityInsight(
          adjustedScore: contextScore.adjustedScore,
          mobilityProfile: mobilityProfile,
          timeAdjustmentReasons: contextScore.reasons,
        );
        _safetyTip = _geminiService.buildFallbackSafetyTip(
          safetyScore.finalScore,
          mobilityProfile,
        );
        _insightLoading = false;
        _selectedContextScore = contextScore;
        _selectedSafetyScore = safetyScore;
        _eventPenaltyApplied = false;
        _safetyAdvisoryApplied = false;
        _webSearchUsed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(selectedOriginProvider);
    final destination = ref.watch(selectedDestinationProvider);

    ref.listen<RouteLocation?>(selectedDestinationProvider, (previous, next) {
      if (previous != next) {
        setState(_resetRouteSelection);
      }
    });

    ref.listen<RouteLocation?>(selectedOriginProvider, (previous, next) {
      if (previous != next) {
        setState(_resetRouteSelection);
      }
    });

    return Scaffold(
      appBar: BeeconBrandedAppBar(
        logoHeader: BeeconLogoHeader(
          title: destination == null
              ? 'Routes'
              : 'Routes to ${destination.label}',
        ),
      ),
      body: destination == null || origin == null
          ? const _EmptyDestinationState()
          : _RouteResultsBody(
              origin: origin,
              destination: destination,
              selectedRouteId: _selectedRouteId,
              insightLoading: _insightLoading,
              insightText: _insightText,
              accessibilityInsight: _accessibilityInsight,
              safetyTip: _safetyTip,
              eventPenaltyApplied: _eventPenaltyApplied,
              safetyAdvisoryApplied: _safetyAdvisoryApplied,
              webSearchUsed: _webSearchUsed,
              displayContextFor: _displayContextFor,
              displaySafetyFor: _displaySafetyFor,
              scoreBadgeColor: _scoreBadgeColor,
              onSelectRoute: (route) => _selectRoute(route, origin, destination),
              onViewOnMap: (route) {
                ref.read(highlightedRouteTypeProvider.notifier).state =
                    route.type;
                context.go(AppConstants.home);
              },
            ),
    );
  }
}

extension on RouteModel {
  RouteModel copyWithScores({
    required ContextScoreModel context,
    required SafetyScoreModel safety,
  }) {
    return RouteModel(
      id: id,
      type: type,
      segments: segments,
      baseScore: baseScore,
      contextScore: context,
      safetyScore: safety,
      totalScore: context.adjustedScore,
      distanceM: distanceM,
      durationMin: durationMin,
      warnings: warnings,
    );
  }
}

class _EmptyDestinationState extends StatelessWidget {
  const _EmptyDestinationState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Search for a destination to see routes',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Home, search for a BGC location, then return here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteResultsBody extends StatelessWidget {
  const _RouteResultsBody({
    required this.origin,
    required this.destination,
    required this.selectedRouteId,
    required this.insightLoading,
    required this.insightText,
    required this.accessibilityInsight,
    required this.safetyTip,
    required this.eventPenaltyApplied,
    required this.safetyAdvisoryApplied,
    required this.webSearchUsed,
    required this.displayContextFor,
    required this.displaySafetyFor,
    required this.scoreBadgeColor,
    required this.onSelectRoute,
    required this.onViewOnMap,
  });

  final RouteLocation origin;
  final RouteLocation destination;
  final String? selectedRouteId;
  final bool insightLoading;
  final String? insightText;
  final String? accessibilityInsight;
  final String? safetyTip;
  final bool eventPenaltyApplied;
  final bool safetyAdvisoryApplied;
  final bool webSearchUsed;
  final ContextScoreModel Function(RouteModel route) displayContextFor;
  final SafetyScoreModel Function(RouteModel route) displaySafetyFor;
  final Color Function(int score) scoreBadgeColor;
  final ValueChanged<RouteModel> onSelectRoute;
  final ValueChanged<RouteModel> onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final routes = RouteGenerator.generateBgcRoutes(
      origin: origin,
      destination: destination,
    );

    final routeCards = routes.map((route) {
      final contextScore = displayContextFor(route);
      final safetyScore = displaySafetyFor(route);
      final accessibilityDisplay = contextScore.adjustedScore;
      final safetyDisplay = safetyScore.finalScore;
      final overallScore =
          ((accessibilityDisplay + safetyDisplay) / 2).round();

      return _RouteCard(
        route: route,
        contextScore: contextScore,
        safetyScore: safetyScore,
        accessibilityDisplay: accessibilityDisplay,
        safetyDisplay: safetyDisplay,
        overallScore: overallScore,
        isSelected: selectedRouteId == route.id,
        accessibilityBadgeColor: scoreBadgeColor(accessibilityDisplay),
        safetyBadgeColor: scoreBadgeColor(safetyDisplay),
        insightLoading: selectedRouteId == route.id && insightLoading,
        insightText: selectedRouteId == route.id ? insightText : null,
        accessibilityInsight:
            selectedRouteId == route.id ? accessibilityInsight : null,
        safetyTip: selectedRouteId == route.id ? safetyTip : null,
        eventPenaltyApplied:
            selectedRouteId == route.id && eventPenaltyApplied,
        safetyAdvisoryApplied:
            selectedRouteId == route.id && safetyAdvisoryApplied,
        webSearchUsed: selectedRouteId == route.id && webSearchUsed,
        onSelect: () => onSelectRoute(route),
        onViewOnMap: () => onViewOnMap(route),
      );
    }).toList();

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${origin.label} → ${destination.label}',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a route based on accessibility and safety',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          AccessibilityScorer.formatTimeContextLabel(),
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
      ],
    );

    if (ResponsiveLayout.isDesktop(context)) {
      return ResponsivePageContent(
        child: ListView(
          children: [
            header,
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < routeCards.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < routeCards.length - 1 ? 16 : 0,
                        ),
                        child: routeCards[i],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [header, ...routeCards],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.contextScore,
    required this.safetyScore,
    required this.accessibilityDisplay,
    required this.safetyDisplay,
    required this.overallScore,
    required this.isSelected,
    required this.accessibilityBadgeColor,
    required this.safetyBadgeColor,
    required this.onSelect,
    required this.onViewOnMap,
    this.insightLoading = false,
    this.insightText,
    this.accessibilityInsight,
    this.safetyTip,
    this.eventPenaltyApplied = false,
    this.safetyAdvisoryApplied = false,
    this.webSearchUsed = false,
  });

  final RouteModel route;
  final ContextScoreModel contextScore;
  final SafetyScoreModel safetyScore;
  final int accessibilityDisplay;
  final int safetyDisplay;
  final int overallScore;
  final bool isSelected;
  final Color accessibilityBadgeColor;
  final Color safetyBadgeColor;
  final VoidCallback onSelect;
  final VoidCallback onViewOnMap;
  final bool insightLoading;
  final String? insightText;
  final String? accessibilityInsight;
  final String? safetyTip;
  final bool eventPenaltyApplied;
  final bool safetyAdvisoryApplied;
  final bool webSearchUsed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
          width: isSelected ? 2 : 1,
        ),
      ),
      elevation: isSelected ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.typeLabel,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scoreBadgeColor(overallScore).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Overall: $overallScore/100',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scoreBadgeColor(overallScore),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _ScoreRow(
              label: 'Accessibility',
              score: accessibilityDisplay,
              color: accessibilityBadgeColor,
            ),
            const SizedBox(height: 6),
            _ScoreRow(
              label: 'Safety Score',
              score: safetyDisplay,
              color: safetyBadgeColor,
            ),
            if (contextScore.reasons.isNotEmpty || eventPenaltyApplied) ...[
              const SizedBox(height: 8),
              ...contextScore.reasons.map(
                (reason) {
                  final timeAdj = AccessibilityScorer.getContextualScoreAdjustment(
                    contextScore.timestamp,
                  ).adjustment;
                  final delta = reason == 'Event/festival detected nearby'
                      ? -10
                      : timeAdj;
                  return _ContextAdjustmentLine(
                    reason: reason,
                    adjustment: delta,
                  );
                },
              ),
            ],
            if (safetyScore.reasons.isNotEmpty ||
                safetyAdvisoryApplied) ...[
              const SizedBox(height: 4),
              ...safetyScore.reasons.map(
                (reason) => _SafetyAdjustmentLine(
                  reason: reason,
                  adjustment: SafetyScorer.adjustmentDeltaForReason(reason),
                ),
              ),
            ],
            if (safetyAdvisoryApplied) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange[800],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Safety advisory found',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.straighten,
                    label: '${route.distanceM} m',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.schedule,
                    label: '${route.durationMin} min',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.signpost_outlined,
                    label: '${route.segments.length} segments',
                  ),
                ),
              ],
            ),
            if (route.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Warnings',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...route.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warning,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (isSelected && insightLoading) ...[
              const SizedBox(height: 16),
              const _InsightShimmer(),
            ],
            if (isSelected && insightText != null) ...[
              const SizedBox(height: 16),
              _AiInsightCard(
                accessibilityInsight: accessibilityInsight ?? insightText!,
                safetyTip: safetyTip ?? '',
                safetyScore: safetyDisplay,
                eventPenaltyApplied: eventPenaltyApplied,
                safetyAdvisoryApplied: safetyAdvisoryApplied,
                webSearchUsed: webSearchUsed,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewOnMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  'View on Map',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                child: Text(
                  isSelected ? 'Selected' : 'Select Route',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScoreStatusDot(color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$score/100',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SafetyAdjustmentLine extends StatelessWidget {
  const _SafetyAdjustmentLine({
    required this.reason,
    required this.adjustment,
  });

  final String reason;
  final int adjustment;

  @override
  Widget build(BuildContext context) {
    final isNegative = adjustment < 0;
    final isNeutral = adjustment == 0;
    final color = isNegative ? Colors.orange[800] : Colors.green[700];

    final label = isNeutral
        ? reason
        : isNegative
            ? '$reason ($adjustment)'
            : '$reason (+$adjustment)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdjustmentStatusIcon(isNegative: isNegative),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextAdjustmentLine extends StatelessWidget {
  const _ContextAdjustmentLine({
    required this.reason,
    required this.adjustment,
  });

  final String reason;
  final int adjustment;

  @override
  Widget build(BuildContext context) {
    final isEvent = reason == 'Event/festival detected nearby';
    final isNegative = adjustment < 0;
    final color = isNegative ? Colors.orange[800] : Colors.green[700];

    final label = isEvent
        ? 'Event detected nearby ($adjustment)'
        : isNegative
            ? 'Score reduced: $reason ($adjustment)'
            : '$reason (+$adjustment)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdjustmentStatusIcon(isNegative: isNegative),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightShimmer extends StatelessWidget {
  const _InsightShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 14,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 12,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({
    required this.accessibilityInsight,
    required this.safetyTip,
    required this.safetyScore,
    required this.eventPenaltyApplied,
    required this.safetyAdvisoryApplied,
    required this.webSearchUsed,
  });

  final String accessibilityInsight;
  final String safetyTip;
  final int safetyScore;
  final bool eventPenaltyApplied;
  final bool safetyAdvisoryApplied;
  final bool webSearchUsed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      AppConstants.logoPath,
                      width: BeeconLogoSizes.insight,
                      height: BeeconLogoSizes.insight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Accessibility & Safety Insight',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AccessibilityScorer.formatLiveContextLabel(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Accessibility',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            accessibilityInsight,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (safetyTip.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Safety',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safetyTip,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          SafetyStatusLabel(safetyScore: safetyScore),
                          if (safetyAdvisoryApplied) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.orange[800],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Safety advisory found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (eventPenaltyApplied) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.travel_explore,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Web search detected nearby activity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (webSearchUsed) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.travel_explore,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Live web context included',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}
