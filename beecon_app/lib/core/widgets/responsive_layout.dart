import 'package:flutter/material.dart';

/// Breakpoints and helpers for adapting the mobile-first UI to desktop web.
class ResponsiveLayout {
  ResponsiveLayout._();

  static const double desktopBreakpoint = 900;
  static const double wideDesktopBreakpoint = 1200;
  static const double contentMaxWidth = 1280;
  static const double formMaxWidth = 720;
  static const double homeSidePanelWidth = 400;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static bool isWideDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideDesktopBreakpoint;

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.all(isDesktop(context) ? 24 : 16);
  }

  static int profileGridColumns(BuildContext context) {
    if (isWideDesktop(context)) return 3;
    if (isDesktop(context)) return 3;
    return 2;
  }

  static int routeCardColumns(BuildContext context) {
    if (isWideDesktop(context)) return 3;
    if (isDesktop(context)) return 3;
    return 1;
  }
}

/// Centers page content and caps width on large screens.
class ResponsivePageContent extends StatelessWidget {
  const ResponsivePageContent({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.contentMaxWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? ResponsiveLayout.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

/// Colored dot used in place of emoji score indicators.
class ScoreStatusDot extends StatelessWidget {
  const ScoreStatusDot({
    super.key,
    required this.color,
    this.size = 10,
  });

  final Color color;
  final double size;

  factory ScoreStatusDot.forScore(int score, {double size = 10}) {
    return ScoreStatusDot(color: scoreBadgeColor(score), size: size);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Color scoreBadgeColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 50) return Colors.orange;
  return Colors.red;
}

/// Icon for positive / negative score adjustment lines.
class AdjustmentStatusIcon extends StatelessWidget {
  const AdjustmentStatusIcon({super.key, required this.isNegative});

  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    return Icon(
      isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline,
      size: 14,
      color: isNegative ? Colors.orange[800] : Colors.green[700],
    );
  }
}

/// Safety status label with colored dot instead of emoji.
class SafetyStatusLabel extends StatelessWidget {
  const SafetyStatusLabel({super.key, required this.safetyScore});

  final int safetyScore;

  String get _label {
    if (safetyScore >= 80) return 'Route appears safe';
    if (safetyScore >= 50) return 'Exercise caution';
    return 'Stay alert on this route';
  }

  @override
  Widget build(BuildContext context) {
    final color = scoreBadgeColor(safetyScore);
    return Row(
      children: [
        ScoreStatusDot(color: color, size: 10),
        const SizedBox(width: 8),
        Text(
          _label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
