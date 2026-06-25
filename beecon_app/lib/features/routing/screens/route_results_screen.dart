import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/services/gemini_service.dart';
import 'package:beecon_app/core/storage/ai_insight_storage.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/features/routing/models/route_location.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/services/route_generator.dart';
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

  Color _scoreBadgeColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return AppColors.primary;
    return Colors.red;
  }

  void _resetRouteSelection() {
    _selectedRouteId = null;
    _insightLoading = false;
    _insightText = null;
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
    });

    ref.read(highlightedRouteTypeProvider.notifier).state = route.type;

    await HiveService.saveRoute(
      route,
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

    try {
      final hasConnection = await HiveService.hasConnectivity();
      if (!hasConnection) {
        throw Exception('No internet connection');
      }

      final insight = await _geminiService.getAccessibilityInsight(
        mobilityProfile: mobilityProfile,
        routeType: route.typeLabel,
        accessibilityScore: route.totalScore,
        warnings: route.warnings,
        origin: origin.label,
        destination: destination.label,
      );

      await AiInsightStorage.saveInsight(
        routeId: route.id,
        insight: insight,
      );

      if (!mounted) return;
      setState(() {
        _insightText = insight;
        _insightLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightText =
            'Unable to load AI insight. Score: ${route.totalScore}/100';
        _insightLoading = false;
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
      appBar: AppBar(
        title: Text(
          destination == null
              ? 'Routes'
              : 'Routes to ${destination.label}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
    required this.scoreBadgeColor,
    required this.onSelectRoute,
    required this.onViewOnMap,
  });

  final RouteLocation origin;
  final RouteLocation destination;
  final String? selectedRouteId;
  final bool insightLoading;
  final String? insightText;
  final Color Function(int score) scoreBadgeColor;
  final ValueChanged<RouteModel> onSelectRoute;
  final ValueChanged<RouteModel> onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final routes = RouteGenerator.generateBgcRoutes(
      origin: origin,
      destination: destination,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${origin.label} → ${destination.label}',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a route based on time and accessibility',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        ...routes.map(
          (route) => _RouteCard(
            route: route,
            isSelected: selectedRouteId == route.id,
            badgeColor: scoreBadgeColor(route.totalScore),
            insightLoading: selectedRouteId == route.id && insightLoading,
            insightText: selectedRouteId == route.id ? insightText : null,
            onSelect: () => onSelectRoute(route),
            onViewOnMap: () => onViewOnMap(route),
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.isSelected,
    required this.badgeColor,
    required this.onSelect,
    required this.onViewOnMap,
    this.insightLoading = false,
    this.insightText,
  });

  final RouteModel route;
  final bool isSelected;
  final Color badgeColor;
  final VoidCallback onSelect;
  final VoidCallback onViewOnMap;
  final bool insightLoading;
  final String? insightText;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${route.totalScore}/100',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
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
              _AiInsightCard(text: insightText!),
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
  const _AiInsightCard({required this.text});

  final String text;

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
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Accessibility Insight',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.5,
                              color: Colors.grey[800],
                            ),
                          ),
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
