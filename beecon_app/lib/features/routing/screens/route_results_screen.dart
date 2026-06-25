import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/services/gemini_service.dart';
import 'package:beecon_app/core/storage/ai_insight_storage.dart';
import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/services/route_generator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouteResultsScreen extends StatefulWidget {
  const RouteResultsScreen({super.key});

  @override
  State<RouteResultsScreen> createState() => _RouteResultsScreenState();
}

class _RouteResultsScreenState extends State<RouteResultsScreen> {
  static const _origin = 'High Street';
  static const _destination = 'SM Aura';

  late final List<RouteModel> _routes;
  final GeminiService _geminiService = GeminiService();

  String? _selectedRouteId;
  bool _insightLoading = false;
  String? _insightText;

  @override
  void initState() {
    super.initState();
    _routes = RouteGenerator.generateBgcRoutes();
  }

  Color _scoreBadgeColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return AppColors.primary;
    return Colors.red;
  }

  Future<void> _selectRoute(RouteModel route) async {
    setState(() {
      _selectedRouteId = route.id;
      _insightLoading = true;
      _insightText = null;
    });

    await HiveService.saveRoute(
      route,
      originLabel: _origin,
      destinationLabel: _destination,
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
        origin: _origin,
        destination: _destination,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Routes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$_origin → $_destination',
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
          ..._routes.map(
            (route) => _RouteCard(
              route: route,
              isSelected: _selectedRouteId == route.id,
              badgeColor: _scoreBadgeColor(route.totalScore),
              insightLoading:
                  _selectedRouteId == route.id && _insightLoading,
              insightText: _selectedRouteId == route.id ? _insightText : null,
              onSelect: () => _selectRoute(route),
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
    required this.isSelected,
    required this.badgeColor,
    required this.onSelect,
    this.insightLoading = false,
    this.insightText,
  });

  final RouteModel route;
  final bool isSelected;
  final Color badgeColor;
  final VoidCallback onSelect;
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
                _InfoChip(
                  icon: Icons.straighten,
                  label: '${route.distanceM} m',
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.schedule,
                  label: '${route.durationMin} min',
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  icon: Icons.signpost_outlined,
                  label: '${route.segments.length} segments',
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Generating AI insight…',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (isSelected && insightText != null) ...[
              const SizedBox(height: 16),
              _AiInsightCard(text: insightText!),
            ],
            const SizedBox(height: 16),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
