import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/features/auth/screens/splash_screen.dart';
import 'package:beecon_app/features/auth/screens/onboarding_screen.dart';
import 'package:beecon_app/features/auth/screens/profile_select_screen.dart';
import 'package:beecon_app/features/home/screens/home_screen.dart';
import 'package:beecon_app/features/routing/screens/route_results_screen.dart';
import 'package:beecon_app/features/reports/screens/report_screen.dart';
import 'package:beecon_app/features/profile/screens/profile_screen.dart';
import 'package:beecon_app/features/profile/screens/saved_locations_screen.dart';

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
          pageBuilder: (context, state) =>
              _slidePage(state, const ReportScreen()),
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

/// Thin shell that owns the BottomNavigationBar shared across the main tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith(AppConstants.routes)) return 1;
    if (loc.startsWith(AppConstants.report)) return 2;
    if (loc.startsWith(AppConstants.profile)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go(AppConstants.home);
            case 1:
              context.go(AppConstants.routes);
            case 2:
              context.go(AppConstants.report);
            case 3:
              context.go(AppConstants.profile);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Routes',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
