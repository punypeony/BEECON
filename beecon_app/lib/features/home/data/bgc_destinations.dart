import 'package:beecon_app/features/home/data/bgc_landmarks.dart';
import 'package:latlong2/latlong.dart';

class BgcDestination {
  const BgcDestination({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;

  LatLng get position => LatLng(lat, lng);

  factory BgcDestination.fromLandmark({
    required String name,
    required String address,
    required LatLng landmark,
  }) {
    return BgcDestination(
      name: name,
      address: address,
      lat: landmark.latitude,
      lng: landmark.longitude,
    );
  }
}

class BgcDestinations {
  BgcDestinations._();

  static final List<BgcDestination> all = [
    BgcDestination.fromLandmark(
      name: 'SM Aura Premier',
      address: '26th St cor McKinley Parkway, Taguig',
      landmark: BgcLandmarks.smAura,
    ),
    BgcDestination.fromLandmark(
      name: 'High Street BGC',
      address: '7th Ave cor 26th St, Bonifacio Global City',
      landmark: BgcLandmarks.highStreet,
    ),
    BgcDestination.fromLandmark(
      name: 'Uptown Mall BGC',
      address: '9th Ave cor 36th St, Taguig',
      landmark: BgcLandmarks.uptownMall,
    ),
    BgcDestination.fromLandmark(
      name: 'Market! Market!',
      address: 'McKinley Pkwy, Fort Bonifacio, Taguig',
      landmark: BgcLandmarks.marketMarket,
    ),
    BgcDestination.fromLandmark(
      name: 'Burgos Circle',
      address: 'Forbes Town Center, Burgos Circle, Taguig',
      landmark: BgcLandmarks.burgosCircle,
    ),
    BgcDestination.fromLandmark(
      name: 'Bonifacio Stopover',
      address: '31st St cor 3rd Ave, Bonifacio Global City',
      landmark: BgcLandmarks.bonifacioStopover,
    ),
    BgcDestination.fromLandmark(
      name: 'The Fort Strip',
      address: '28th St cor 7th Ave, Bonifacio Global City',
      landmark: BgcLandmarks.theFortStrip,
    ),
    BgcDestination.fromLandmark(
      name: 'Venice Grand Canal Mall',
      address: 'Upper McKinley Rd, McKinley Hill, Taguig',
      landmark: BgcLandmarks.veniceGrandCanal,
    ),
    BgcDestination.fromLandmark(
      name: 'Mind Museum BGC',
      address: '3rd Ave, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.mindMuseum,
    ),
    BgcDestination.fromLandmark(
      name: "St. Luke's Medical Center BGC",
      address: '32nd St cor 5th Ave, Bonifacio Global City',
      landmark: BgcLandmarks.stLukes,
    ),
    BgcDestination.fromLandmark(
      name: 'Serendra BGC',
      address: '11th Ave, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.serendra,
    ),
    BgcDestination.fromLandmark(
      name: 'One Bonifacio High Street',
      address: '5th Ave cor 28th St, Bonifacio Global City',
      landmark: BgcLandmarks.oneBonifacioHighStreet,
    ),
    BgcDestination.fromLandmark(
      name: 'Mckinley Hill',
      address: 'Upper McKinley Rd, Fort Bonifacio, Taguig',
      landmark: BgcLandmarks.mckinleyHill,
    ),
    BgcDestination.fromLandmark(
      name: 'Rizal Park BGC',
      address: 'Rizal Dr, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.rizalPark,
    ),
    BgcDestination.fromLandmark(
      name: 'BGC Bus Stop',
      address: '26th St, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.bgcBusStop,
    ),
    BgcDestination.fromLandmark(
      name: 'Crossroads BGC',
      address: '32nd St cor 8th Ave, Bonifacio Global City',
      landmark: BgcLandmarks.crossroads,
    ),
    BgcDestination.fromLandmark(
      name: 'Track 30th BGC',
      address: '30th St cor 3rd Ave, Bonifacio Global City',
      landmark: BgcLandmarks.track30th,
    ),
    BgcDestination.fromLandmark(
      name: 'Century City Mall',
      address: 'Kalayaan Ave, Makati',
      landmark: BgcLandmarks.centuryCity,
    ),
    BgcDestination.fromLandmark(
      name: 'Picadilly Star BGC',
      address: '5th Ave, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.picadillyStar,
    ),
    BgcDestination.fromLandmark(
      name: 'National University BGC',
      address: 'Finance Dr, Bonifacio Global City, Taguig',
      landmark: BgcLandmarks.nationalUniversity,
    ),
  ];

  static List<BgcDestination> search(String query, {int limit = 5}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    return all
        .where(
          (destination) =>
              destination.name.toLowerCase().contains(normalized) ||
              destination.address.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList();
  }

  static BgcDestination? matchSubmitted(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final destination in all) {
      if (destination.name.toLowerCase() == normalized) {
        return destination;
      }
    }

    final alias = BgcLandmarks.searchAliases[normalized];
    if (alias != null) {
      for (final destination in all) {
        if ((destination.lat - alias.latitude).abs() < 0.0002 &&
            (destination.lng - alias.longitude).abs() < 0.0002) {
          return destination;
        }
      }
    }

    for (final entry in BgcLandmarks.searchAliases.entries) {
      if (normalized.contains(entry.key)) {
        for (final destination in all) {
          if ((destination.lat - entry.value.latitude).abs() < 0.0002 &&
              (destination.lng - entry.value.longitude).abs() < 0.0002) {
            return destination;
          }
        }
      }
    }

    final results = search(query, limit: 1);
    return results.isEmpty ? null : results.first;
  }
}
