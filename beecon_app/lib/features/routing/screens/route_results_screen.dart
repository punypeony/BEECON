import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:beecon_app/core/widgets/responsive_layout.dart';
import 'package:beecon_app/core/data/bgc_context_data.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/services/ors_service.dart';
import 'package:beecon_app/core/services/route_ai_models.dart';
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
  final OrsService _orsService = OrsService();

  List<RouteModel>? _routes;
  RouteType? _recommendedType;
  RouteAiLoadingPhase _phase = RouteAiLoadingPhase.idle;
  String? _selectedRouteId;
  String? _loadedKey;
  int _loadGeneration = 0;
  int _insightGeneration = 0;
  String _mobilityProfile = 'General';
  String? _loadingInsightRouteId;
  final Map<String, Agent2Result> _insightsByRouteId = {};
  final Map<RouteType, ({ContextScoreModel context, SafetyScoreModel safety})>
      _eventAdjustedScores = {};

  Color _scoreBadgeColor(int score) => scoreBadgeColor(score);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoutes();
    });
  }

  void _resetPipeline() {
    _routes = null;
    _recommendedType = null;
    _selectedRouteId = null;
    _loadedKey = null;
    _loadingInsightRouteId = null;
    _insightsByRouteId.clear();
    _eventAdjustedScores.clear();
    _phase = RouteAiLoadingPhase.idle;
    _loadGeneration++;
    _insightGeneration++;
  }

  ContextScoreModel _displayContextFor(RouteModel route) {
    final adjusted = _eventAdjustedScores[route.type];
    if (adjusted != null) return adjusted.context;
    return route.contextScore;
  }

  SafetyScoreModel _displaySafetyFor(RouteModel route) {
    final adjusted = _eventAdjustedScores[route.type];
    if (adjusted != null) return adjusted.safety;
    return route.safetyScore;
  }

  Future<void> _loadRoutes() async {
    final origin = ref.read(selectedOriginProvider);
    final destination = ref.read(selectedDestinationProvider);
    if (origin == null || destination == null) return;

    final key = '${origin.label}::${destination.label}';
    if (_loadedKey == key && _routes != null) return;

    final generation = ++_loadGeneration;

    setState(() {
      _loadedKey = key;
      _routes = null;
      _recommendedType = null;
      _selectedRouteId = null;
      _loadingInsightRouteId = null;
      _insightsByRouteId.clear();
      _eventAdjustedScores.clear();
      _phase = RouteAiLoadingPhase.calculatingRoutes;
    });

    var bundle = ref.read(orsRouteBundleProvider);
    if (bundle == null) {
      final raw = await _orsService.getAllRoutes(
        origin.lat,
        origin.lng,
        destination.lat,
        destination.lng,
      );
      if (!mounted || generation != _loadGeneration) return;
      bundle = _orsService.snapBundleToPins(
        raw,
        originLat: origin.lat,
        originLng: origin.lng,
        destLat: destination.lat,
        destLng: destination.lng,
      );
      ref.read(orsRouteBundleProvider.notifier).state = bundle;
      ref.read(routePolylinesProvider.notifier).state =
          _orsService.polylinesFromBundle(
        bundle,
        originLat: origin.lat,
        originLng: origin.lng,
        destLat: destination.lat,
        destLng: destination.lng,
      );
    }

    if (!mounted || generation != _loadGeneration) return;

    final routes = RouteGenerator.generateBgcRoutes(
      origin: origin,
      destination: destination,
      orsBundle: bundle,
    );

    final prefs = await SharedPreferences.getInstance();
    final mobilityProfile =
        prefs.getString(AppConstants.selectedProfileKey) ?? 'General';

    if (!mounted || generation != _loadGeneration) return;

    final recommended = heuristicRecommendedRoute(routes, mobilityProfile);

    ref.read(recommendedRouteTypeProvider.notifier).state = recommended;
    ref.read(highlightedRouteTypeProvider.notifier).state = recommended;
    ref.read(routeAgentPipelineProvider.notifier).state = null;

    setState(() {
      _routes = routes;
      _recommendedType = recommended;
      _mobilityProfile = mobilityProfile;
      _phase = RouteAiLoadingPhase.complete;
    });
  }

  Future<void> _selectRoute(
    RouteModel route,
    RouteLocation origin,
    RouteLocation destination,
  ) async {
    final generation = ++_insightGeneration;

    setState(() {
      _selectedRouteId = route.id;
      _loadingInsightRouteId = route.id;
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

    if (_insightsByRouteId.containsKey(route.id)) {
      setState(() => _loadingInsightRouteId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${route.typeLabel} selected',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final mobilityProfile =
        prefs.getString(AppConstants.selectedProfileKey) ?? 'General';
    final gemini = ref.read(geminiServiceProvider);

    Agent2Result insight;
    try {
      insight = await gemini.validateSelectedRoute(
        mobilityProfile: mobilityProfile,
        origin: origin.label,
        destination: destination.label,
        route: route,
      );
    } catch (_) {
      insight = Agent2Result(
        finalRoute: agentRouteLabelForType(route.type),
        overridden: false,
        overrideReason: null,
        userInsight: gemini.buildAgent2FallbackInsightPublic(
          accessibilityScore: route.contextScore.adjustedScore,
          safetyScore: route.safetyScore.finalScore,
          localContext: BgcContextMatcher.match(
            now: DateTime.now(),
            destinationLabel: destination.label,
          ),
        ),
        safetyIndicator: 'Route appears safe',
        eventDetected: false,
        eventPenalty: 0,
        failed: true,
        usedLocalFallback: true,
      );
    }

    if (!mounted || generation != _insightGeneration) return;

    if (insight.eventDetected && insight.eventPenalty > 0) {
      _eventAdjustedScores[route.type] = (
        context: route.contextScore.withEventPenalty(
          penalty: -insight.eventPenalty,
        ),
        safety: route.safetyScore.withEventPenalty(
          penalty: -insight.eventPenalty,
        ),
      );
    }

    setState(() {
      _insightsByRouteId[route.id] = insight;
      _loadingInsightRouteId = null;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${route.typeLabel} selected',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(selectedOriginProvider);
    final destination = ref.watch(selectedDestinationProvider);

    ref.listen<RouteLocation?>(selectedDestinationProvider, (previous, next) {
      if (previous != next) {
        setState(_resetPipeline);
        _loadRoutes();
      }
    });

    ref.listen<RouteLocation?>(selectedOriginProvider, (previous, next) {
      if (previous != next) {
        setState(_resetPipeline);
        _loadRoutes();
      }
    });

    final prefsProfile = _mobilityProfile;

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
              routes: _routes,
              loadingPhase: _phase,
              selectedRouteId: _selectedRouteId,
              loadingInsightRouteId: _loadingInsightRouteId,
              insightsByRouteId: _insightsByRouteId,
              recommendedType: _recommendedType,
              mobilityProfile: prefsProfile,
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
    required this.routes,
    required this.loadingPhase,
    required this.selectedRouteId,
    required this.loadingInsightRouteId,
    required this.insightsByRouteId,
    required this.recommendedType,
    required this.mobilityProfile,
    required this.displayContextFor,
    required this.displaySafetyFor,
    required this.scoreBadgeColor,
    required this.onSelectRoute,
    required this.onViewOnMap,
  });

  final RouteLocation origin;
  final RouteLocation destination;
  final List<RouteModel>? routes;
  final RouteAiLoadingPhase loadingPhase;
  final String? selectedRouteId;
  final String? loadingInsightRouteId;
  final Map<String, Agent2Result> insightsByRouteId;
  final RouteType? recommendedType;
  final String mobilityProfile;
  final ContextScoreModel Function(RouteModel route) displayContextFor;
  final SafetyScoreModel Function(RouteModel route) displaySafetyFor;
  final Color Function(int score) scoreBadgeColor;
  final ValueChanged<RouteModel> onSelectRoute;
  final ValueChanged<RouteModel> onViewOnMap;

  String get _loadingLabel {
    switch (loadingPhase) {
      case RouteAiLoadingPhase.calculatingRoutes:
        return 'Calculating 3 routes...';
      default:
        return 'Loading routes...';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (routes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _PhaseShimmer(),
              const SizedBox(height: 20),
              Text(
                _loadingLabel,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final routeCards = routes!.map((route) {
      final contextScore = displayContextFor(route);
      final safetyScore = displaySafetyFor(route);
      final accessibilityDisplay = contextScore.adjustedScore;
      final safetyDisplay = safetyScore.finalScore;
      final overallScore =
          ((accessibilityDisplay + safetyDisplay) / 2).round();
      final isRecommended = recommendedType == route.type;
      final isSelected = selectedRouteId == route.id;
      final insight = insightsByRouteId[route.id];
      final insightLoading =
          isSelected && loadingInsightRouteId == route.id;

      return _RouteCard(
        route: route,
        contextScore: contextScore,
        safetyScore: safetyScore,
        accessibilityDisplay: accessibilityDisplay,
        safetyDisplay: safetyDisplay,
        overallScore: overallScore,
        isSelected: isSelected,
        isRecommended: isRecommended,
        accessibilityBadgeColor: scoreBadgeColor(accessibilityDisplay),
        safetyBadgeColor: scoreBadgeColor(safetyDisplay),
        onSelect: () => onSelectRoute(route),
        onViewOnMap: () => onViewOnMap(route),
        insightLoading: insightLoading,
        showInsight: isSelected && (insight != null || insightLoading),
        userInsight: insight?.userInsight,
        safetyIndicator: insight?.safetyIndicator,
        overridden: insight?.overridden ?? false,
        overrideReason: insight?.overrideReason,
        eventDetected: insight?.eventDetected ?? false,
        usedLocalFallback: insight?.usedLocalFallback ?? false,
        webSearchUsed: insight?.webSearchUsed ?? false,
        bothAgentsFailed: insight?.failed ?? false,
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
        if (recommendedType != null) ...[
          const SizedBox(height: 16),
          _AiRecommendationBanner(
            recommendedRoute: routeLabelForType(recommendedType!),
            confidence: null,
            reasoning: heuristicRecommendationReason(
              recommendedType!,
              mobilityProfile,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tap Select Route for route insight. Uses Gemini when available; '
          'falls back to local BGC data if rate limited.',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
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

class _AiRecommendationBanner extends StatelessWidget {
  const _AiRecommendationBanner({
    required this.recommendedRoute,
    required this.reasoning,
    this.confidence,
  });

  final String recommendedRoute;
  final int? confidence;
  final String reasoning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8A00), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🤖 AI recommended',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF8A00),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendedRoute,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          if (confidence != null)
            Text(
              'Confidence: $confidence%',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          if (confidence != null) const SizedBox(height: 4),
          Text(
            '"$reasoning"',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardInsightShimmer extends StatelessWidget {
  const _CardInsightShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _PhaseShimmer extends StatelessWidget {
  const _PhaseShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
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
    required this.isRecommended,
    required this.accessibilityBadgeColor,
    required this.safetyBadgeColor,
    required this.onSelect,
    required this.onViewOnMap,
    this.insightLoading = false,
    this.showInsight = false,
    this.userInsight,
    this.safetyIndicator,
    this.overridden = false,
    this.overrideReason,
    this.eventDetected = false,
    this.usedLocalFallback = false,
    this.webSearchUsed = false,
    this.bothAgentsFailed = false,
  });

  final RouteModel route;
  final ContextScoreModel contextScore;
  final SafetyScoreModel safetyScore;
  final int accessibilityDisplay;
  final int safetyDisplay;
  final int overallScore;
  final bool isSelected;
  final bool isRecommended;
  final Color accessibilityBadgeColor;
  final Color safetyBadgeColor;
  final VoidCallback onSelect;
  final VoidCallback onViewOnMap;
  final bool showInsight;
  final bool insightLoading;
  final String? userInsight;
  final String? safetyIndicator;
  final bool overridden;
  final String? overrideReason;
  final bool eventDetected;
  final bool usedLocalFallback;
  final bool webSearchUsed;
  final bool bothAgentsFailed;

  Color get _borderColor {
    if (isRecommended) return const Color(0xFFFF8A00);
    if (isSelected) return AppColors.primary;
    return const Color(0xFFE0E0E0);
  }

  double get _borderWidth {
    if (isRecommended || isSelected) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _borderColor, width: _borderWidth),
      ),
      elevation: isSelected || isRecommended ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    route.typeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isRecommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8A00),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AI Pick 🤖',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
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
            if (contextScore.reasons.isNotEmpty || eventDetected) ...[
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
                    isNegative: delta < 0,
                  );
                },
              ),
            ],
            if (safetyScore.reasons.isNotEmpty) ...[
              const SizedBox(height: 4),
              ...safetyScore.reasons.map(
                (reason) {
                  final delta = SafetyScorer.adjustmentDeltaForReason(reason);
                  return _SafetyAdjustmentLine(
                    reason: reason,
                    isNegative: delta < 0,
                  );
                },
              ),
            ],
            if (eventDetected) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '🔍 Web search detected nearby activity',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
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
            if (showInsight && insightLoading) ...[
              const SizedBox(height: 16),
              const _CardInsightShimmer(),
            ],
            if (showInsight && !insightLoading && userInsight != null) ...[
              const SizedBox(height: 16),
              _AgentInsightCard(
                userInsight: userInsight!,
                safetyIndicator: safetyIndicator ?? 'Route appears safe',
                safetyDisplay: safetyDisplay,
                overridden: overridden,
                overrideReason: overrideReason,
                eventDetected: eventDetected,
                usedLocalFallback: usedLocalFallback,
                webSearchUsed: webSearchUsed,
                bothAgentsFailed: bothAgentsFailed,
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
    required this.isNegative,
  });

  final String reason;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    final color = isNegative ? Colors.orange[800] : Colors.green[700];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdjustmentStatusIcon(isNegative: isNegative),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              reason,
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
    required this.isNegative,
  });

  final String reason;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    final color = isNegative ? Colors.orange[800] : Colors.green[700];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdjustmentStatusIcon(isNegative: isNegative),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              reason,
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

class _AgentInsightCard extends StatelessWidget {
  const _AgentInsightCard({
    required this.userInsight,
    required this.safetyIndicator,
    required this.safetyDisplay,
    required this.overridden,
    required this.eventDetected,
    required this.usedLocalFallback,
    required this.webSearchUsed,
    required this.bothAgentsFailed,
    this.overrideReason,
  });

  final String userInsight;
  final String safetyIndicator;
  final int safetyDisplay;
  final bool overridden;
  final String? overrideReason;
  final bool eventDetected;
  final bool usedLocalFallback;
  final bool webSearchUsed;
  final bool bothAgentsFailed;

  Color _safetyBadgeColor() {
    switch (safetyIndicator) {
      case 'Exercise caution':
        return Colors.orange;
      case 'Stay alert on this route':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

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
                    const SizedBox(height: 10),
                    Text(
                      userInsight,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _safetyBadgeColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        safetyIndicator,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _safetyBadgeColor(),
                        ),
                      ),
                    ),
                    if (overridden && overrideReason != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Route updated by AI validator: $overrideReason',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (eventDetected && webSearchUsed) ...[
                      const SizedBox(height: 6),
                      Text(
                        '🔍 Live web data used',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else if (usedLocalFallback) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Using local BGC context data',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (bothAgentsFailed) ...[
                      const SizedBox(height: 6),
                      Text(
                        'AI insight temporarily unavailable.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
