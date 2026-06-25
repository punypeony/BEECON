import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared logo size tokens used across the app.
class BeeconLogoSizes {
  static const double splash = 168;
  static const double appBar = 44;
  static const double pageHeader = 40;
  static const double onboarding = 52;
  static const double brand = 88;
  static const double insight = 30;
}

/// Small logo + title row for app bars and page headers.
class BeeconLogoHeader extends StatelessWidget {
  const BeeconLogoHeader({
    super.key,
    required this.title,
    this.logoHeight = BeeconLogoSizes.pageHeader,
    this.titleColor = AppColors.primary,
    this.titleFontSize = 18,
  });

  final String title;
  final double logoHeight;
  final Color titleColor;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppConstants.logoPath,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo + "Beecon" wordmark for app bar left side.
class BeeconAppBarTitle extends StatelessWidget {
  const BeeconAppBarTitle({super.key, this.logoHeight = BeeconLogoSizes.appBar});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppConstants.logoPath,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        Text(
          'Beecon',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Compact logo for onboarding slide top-left.
class BeeconLogoSmall extends StatelessWidget {
  const BeeconLogoSmall({super.key, this.height = BeeconLogoSizes.onboarding});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.logoPath,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

/// Centered logo + wordmark for profile selection header.
class BeeconBrandHeader extends StatelessWidget {
  const BeeconBrandHeader({
    super.key,
    this.subtitle,
    this.logoHeight = BeeconLogoSizes.brand,
  });

  final String? subtitle;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          AppConstants.logoPath,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        Text(
          'Beecon',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

/// Animated orange loading dots for splash screen.
class BeeconLoadingDots extends StatefulWidget {
  const BeeconLoadingDots({super.key});

  @override
  State<BeeconLoadingDots> createState() => _BeeconLoadingDotsState();
}

class _BeeconLoadingDotsState extends State<BeeconLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * (1 - (t * 2 - 1).abs())).clamp(0.3, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// White app bar wrapper with bottom shadow.
class BeeconBrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BeeconBrandedAppBar({
    super.key,
    this.title,
    this.logoHeader,
    this.actions,
    this.centerTitle = false,
  });

  final Widget? title;
  final BeeconLogoHeader? logoHeader;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: centerTitle,
        title: logoHeader ?? title,
        actions: actions,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
    );
  }
}
