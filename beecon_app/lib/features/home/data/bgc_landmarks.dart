import 'package:latlong2/latlong.dart';

/// Canonical BGC landmark coordinates — single source for map pins, routing,
/// accessibility markers, and safety scoring.
class BgcLandmarks {
  BgcLandmarks._();

  static const LatLng smAura = LatLng(14.5467, 121.0534);
  static const LatLng highStreet = LatLng(14.5512, 121.0489);
  static const LatLng uptownMall = LatLng(14.5575, 121.0530);
  static const LatLng marketMarket = LatLng(14.5494, 121.0555);
  static const LatLng burgosCircle = LatLng(14.5517, 121.0446);
  static const LatLng bonifacioStopover = LatLng(14.5586, 121.0478);
  static const LatLng theFortStrip = LatLng(14.5518, 121.0455);
  static const LatLng veniceGrandCanal = LatLng(14.5345, 121.0497);
  static const LatLng mindMuseum = LatLng(14.5524, 121.0466);
  static const LatLng stLukes = LatLng(14.5536, 121.0584);
  static const LatLng serendra = LatLng(14.5524, 121.0472);
  static const LatLng oneBonifacioHighStreet = LatLng(14.5512, 121.0489);
  static const LatLng mckinleyHill = LatLng(14.5345, 121.0488);
  static const LatLng rizalPark = LatLng(14.5520, 121.0485);
  static const LatLng bgcBusStop = LatLng(14.5586, 121.0478);
  static const LatLng crossroads = LatLng(14.5510, 121.0497);
  static const LatLng track30th = LatLng(14.5538, 121.0512);
  static const LatLng centuryCity = LatLng(14.5655, 121.0134);
  static const LatLng picadillyStar = LatLng(14.5578, 121.0501);
  static const LatLng nationalUniversity = LatLng(14.5530, 121.0475);

  /// Default origin when GPS is unavailable (center of High Street area).
  static const LatLng defaultOrigin = highStreet;

  static const Map<String, LatLng> searchAliases = {
    'high street': highStreet,
    'high street bgc': highStreet,
    'sm aura': smAura,
    'sm aura premier': smAura,
    'uptown bgc': uptownMall,
    'uptown mall': uptownMall,
    'uptown mall bgc': uptownMall,
    'uptown': uptownMall,
    'market market': marketMarket,
    'market! market!': marketMarket,
    'burgos circle': burgosCircle,
    'bonifacio stopover': bonifacioStopover,
    'stopover': bonifacioStopover,
    'bgc bus stop': bgcBusStop,
    'track 30th': track30th,
    'track 30th bgc': track30th,
    'serendra': serendra,
    'serendra bgc': serendra,
    'mind museum': mindMuseum,
    'mind museum bgc': mindMuseum,
    'the fort strip': theFortStrip,
    'mckinley hill': mckinleyHill,
    'national university bgc': nationalUniversity,
  };
}
