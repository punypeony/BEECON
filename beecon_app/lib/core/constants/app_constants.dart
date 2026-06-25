class AppConstants {
  // Asset paths
  static const String logoPath = 'assets/images/beecon_logo.png';

  // SharedPreferences keys
  static const String selectedProfileKey = 'selected_mobility_profile';
  static const String lastAiInsightKey = 'last_ai_insight';
  static const String lastAiInsightRouteIdKey = 'last_ai_insight_route_id';
  static const String aiInsightBannerDismissedKey = 'ai_insight_banner_dismissed';

  // Route names
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String profileSelect = '/profile-select';
  static const String home = '/home';
  static const String routes = '/routes';
  static const String report = '/report';
  static const String profile = '/profile';
  static const String savedLocations = '/saved-locations';

  static String reportWithLocation(double lat, double lng) =>
      '$report?lat=$lat&lng=$lng';
}
