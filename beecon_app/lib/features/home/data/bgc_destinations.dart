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
}

class BgcDestinations {
  BgcDestinations._();

  static const List<BgcDestination> all = [
    BgcDestination(
      name: 'SM Aura Premier',
      address: '26th St cor McKinley Parkway, Taguig',
      lat: 14.5465,
      lng: 121.0530,
    ),
    BgcDestination(
      name: 'High Street BGC',
      address: '7th Ave cor 26th St, Bonifacio Global City',
      lat: 14.5547,
      lng: 121.0507,
    ),
    BgcDestination(
      name: 'Uptown Mall BGC',
      address: '9th Ave cor 36th St, Taguig',
      lat: 14.5600,
      lng: 121.0514,
    ),
    BgcDestination(
      name: 'Market! Market!',
      address: 'McKinley Pkwy, Fort Bonifacio, Taguig',
      lat: 14.5514,
      lng: 121.0500,
    ),
    BgcDestination(
      name: 'Burgos Circle',
      address: 'Forbes Town Center, Burgos Circle, Taguig',
      lat: 14.5525,
      lng: 121.0468,
    ),
    BgcDestination(
      name: 'Bonifacio Stopover',
      address: '31st St cor 3rd Ave, Bonifacio Global City',
      lat: 14.5489,
      lng: 121.0476,
    ),
    BgcDestination(
      name: 'The Fort Strip',
      address: '28th St cor 7th Ave, Bonifacio Global City',
      lat: 14.5518,
      lng: 121.0455,
    ),
    BgcDestination(
      name: 'Venice Grand Canal Mall',
      address: 'Upper McKinley Rd, McKinley Hill, Taguig',
      lat: 14.5073,
      lng: 121.0420,
    ),
    BgcDestination(
      name: 'Mind Museum BGC',
      address: '3rd Ave, Bonifacio Global City, Taguig',
      lat: 14.5534,
      lng: 121.0448,
    ),
    BgcDestination(
      name: "St. Luke's Medical Center BGC",
      address: '32nd St cor 5th Ave, Bonifacio Global City',
      lat: 14.5536,
      lng: 121.0584,
    ),
    BgcDestination(
      name: 'Serendra BGC',
      address: '11th Ave, Bonifacio Global City, Taguig',
      lat: 14.5573,
      lng: 121.0472,
    ),
    BgcDestination(
      name: 'One Bonifacio High Street',
      address: '5th Ave cor 28th St, Bonifacio Global City',
      lat: 14.5560,
      lng: 121.0510,
    ),
    BgcDestination(
      name: 'Mckinley Hill',
      address: 'Upper McKinley Rd, Fort Bonifacio, Taguig',
      lat: 14.5352,
      lng: 121.0488,
    ),
    BgcDestination(
      name: 'Rizal Park BGC',
      address: 'Rizal Dr, Bonifacio Global City, Taguig',
      lat: 14.5489,
      lng: 121.0510,
    ),
    BgcDestination(
      name: 'BGC Bus Stop',
      address: '26th St, Bonifacio Global City, Taguig',
      lat: 14.5547,
      lng: 121.0480,
    ),
    BgcDestination(
      name: 'Crossroads BGC',
      address: '32nd St cor 8th Ave, Bonifacio Global City',
      lat: 14.5510,
      lng: 121.0497,
    ),
    BgcDestination(
      name: 'Track 30th BGC',
      address: '30th St cor 3rd Ave, Bonifacio Global City',
      lat: 14.5555,
      lng: 121.0463,
    ),
    BgcDestination(
      name: 'Century City Mall',
      address: 'Kalayaan Ave, Makati',
      lat: 14.5530,
      lng: 121.0134,
    ),
    BgcDestination(
      name: 'Picadilly Star BGC',
      address: '5th Ave, Bonifacio Global City, Taguig',
      lat: 14.5578,
      lng: 121.0501,
    ),
    BgcDestination(
      name: 'National University BGC',
      address: 'Finance Dr, Bonifacio Global City, Taguig',
      lat: 14.5994,
      lng: 121.0154,
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

    final results = search(query, limit: 1);
    return results.isEmpty ? null : results.first;
  }
}
