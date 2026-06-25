import 'package:beecon_app/features/profile/models/saved_location_model.dart';
import 'package:beecon_app/features/reports/models/report_model.dart';
import 'package:beecon_app/features/routing/models/route_model.dart';
import 'package:beecon_app/features/routing/models/saved_route_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  HiveService._();

  static const String reportsBoxName = 'reports';
  static const String savedRoutesBoxName = 'saved_routes';
  static const String savedLocationsBoxName = 'saved_locations';

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    Hive.registerAdapter(ReportModelAdapter());
    Hive.registerAdapter(SavedLocationModelAdapter());
    Hive.registerAdapter(SavedRouteModelAdapter());

    await Hive.openBox<ReportModel>(reportsBoxName);
    await Hive.openBox<SavedRouteModel>(savedRoutesBoxName);
    await Hive.openBox<SavedLocationModel>(savedLocationsBoxName);

    _initialized = true;
  }

  static Box<ReportModel> get reportsBox =>
      Hive.box<ReportModel>(reportsBoxName);

  static Box<SavedRouteModel> get savedRoutesBox =>
      Hive.box<SavedRouteModel>(savedRoutesBoxName);

  static Box<SavedLocationModel> get savedLocationsBox =>
      Hive.box<SavedLocationModel>(savedLocationsBoxName);

  static List<ReportModel> getAllReports() {
    return reportsBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> saveReport(ReportModel report) async {
    await reportsBox.put(report.id, report);
  }

  static Future<void> upvoteReport(ReportModel report) async {
    report.upvotes += 1;
    await report.save();
  }

  static List<SavedLocationModel> getAllSavedLocations() {
    return savedLocationsBox.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  static Future<void> saveLocation(SavedLocationModel location) async {
    await savedLocationsBox.put(location.id, location);
  }

  static Future<void> deleteLocation(String id) async {
    await savedLocationsBox.delete(id);
  }

  static Future<void> saveRoute(
    RouteModel route, {
    String originLabel = 'High Street',
    String destinationLabel = 'SM Aura',
  }) async {
    final saved = SavedRouteModel(
      routeId: route.id,
      routeType: route.typeLabel,
      totalScore: route.totalScore,
      distanceM: route.distanceM,
      durationMin: route.durationMin,
      originLabel: originLabel,
      destinationLabel: destinationLabel,
    );
    await savedRoutesBox.put(saved.routeId, saved);
  }

  static Future<bool> hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
