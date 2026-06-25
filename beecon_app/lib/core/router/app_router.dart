import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/features/auth/screens/splash_screen.dart';
import 'package:beecon_app/features/auth/screens/onboarding_screen.dart';
import 'package:beecon_app/features/auth/screens/profile_select_screen.dart';
import 'package:beecon_app/features/home/screens/home_screen.dart';
import 'package:beecon_app/features/routing/screens/route_results_screen.dart';
import 'package:beecon_app/features/reports/screens/report_screen.dart';
import 'package:beecon_app/features/profile/screens/profile_screen.dart';
import 'package:beecon_app/features/profile/screens/saved_locations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: AppConstants.splash,
  routes: [
    GoRoute(
      path: AppConstants.splash,
      pageBuilder: (context, state) =>
          _slidePage(state, const SplashScreen()),
    ),
    GoRoute(
      path: AppConstants.onboarding,
      pageBuilder: (context, state) =>
          _slidePage(state, const OnboardingScreen()),
    ),
    GoRoute(
      path: AppConstants.profileSelect,
      pageBuilder: (context, state) =>
          _slidePage(state, const ProfileSelectScreen()),
    ),
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppConstants.home,
          pageBuilder: (context, state) =>
              _slidePage(state, const HomeScreen()),
        ),
        GoRoute(
          path: AppConstants.routes,
          pageBuilder: (context, state) =>
              _slidePage(state, const RouteResultsScreen()),
        ),
        GoRoute(
          path: AppConstants.report,
          pageBuilder: (context, state) {
            final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '');
            final lng = double.tryParse(state.uri.queryParameters['lng'] ?? '');
            return _slidePage(
              state,
              ReportScreen(lat: lat, lng: lng),
            );
          },
        ),
        GoRoute(
          path: AppConstants.profile,
          pageBuilder: (context, state) =>
              _slidePage(state, const ProfileScreen()),
        ),
      ],
    ),
    GoRoute(
      path: AppConstants.savedLocations,
      pageBuilder: (context, state) =>
          _slidePage(state, const SavedLocationsScreen()),
    ),
  ],
);

/// Shell that owns the branded bottom navigation bar shared across main tabs.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppConstants.routes)) return 1;
    if (loc.startsWith(AppConstants.report)) return 2;
    if (loc.startsWith(AppConstants.profile)) return 3;
    return 0;
  }

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.home);
      case 1:
        context.go(AppConstants.routes);
      case 2:
        ref.read(reportTapModeProvider.notifier).state = true;
        ref.read(pendingReportPinProvider.notifier).state = null;
        context.go(AppConstants.home);
      case 3:
        context.go(AppConstants.profile);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => _onTap(context, ref, 0),
                ),
                _NavItem(
                  icon: Icons.route_outlined,
                  selectedIcon: Icons.route,
                  label: 'Routes',
                  selected: currentIndex == 1,
                  onTap: () => _onTap(context, ref, 1),
                ),
                _NavItem(
                  icon: Icons.report_outlined,
                  selectedIcon: Icons.report,
                  label: 'Report',
                  selected: currentIndex == 2,
                  onTap: () => _onTap(context, ref, 2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  selected: currentIndex == 3,
                  onTap: () => _onTap(context, ref, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
