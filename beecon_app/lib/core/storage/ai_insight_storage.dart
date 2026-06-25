import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiInsightStorage {
  AiInsightStorage._();

  static Future<void> saveInsight({
    required String routeId,
    required String insight,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastAiInsightKey, insight);
    await prefs.setString(AppConstants.lastAiInsightRouteIdKey, routeId);
    await prefs.setBool(AppConstants.aiInsightBannerDismissedKey, false);
  }

  static Future<String?> getLastInsight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastAiInsightKey);
  }

  static Future<String?> getLastInsightRouteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastAiInsightRouteIdKey);
  }

  static Future<bool> isBannerDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.aiInsightBannerDismissedKey) ?? false;
  }

  static Future<void> dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.aiInsightBannerDismissedKey, true);
  }
}
