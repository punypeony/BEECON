import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:beecon_app/features/profile/models/saved_location_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final _nameController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showAddLocationDialog() async {
    _nameController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add saved location',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              hintText: 'Location name',
              hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _addLocation();
              },
              child: Text(
                'Save',
                style: GoogleFonts.poppins(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a location name.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    setState(() => _adding = true);

    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location permission is required.',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
          return;
        }
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to get GPS coordinates.',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = SavedLocationModel(
        name: name,
        lat: position.latitude,
        lng: position.longitude,
      );

      await HiveService.saveLocation(location);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"$name" saved.',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save location.',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteLocation(SavedLocationModel location) async {
    await HiveService.deleteLocation(location.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${location.name}" deleted.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BeeconBrandedAppBar(
        logoHeader: BeeconLogoHeader(title: 'Saved Locations'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _showAddLocationDialog,
        backgroundColor: AppColors.primary,
        icon: _adding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_location_alt_outlined),
        label: Text(
          'Add location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ValueListenableBuilder<Box<SavedLocationModel>>(
        valueListenable: HiveService.savedLocationsBox.listenable(),
        builder: (context, box, _) {
          final locations = HiveService.getAllSavedLocations();

          if (locations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No saved locations yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add location" to save your current GPS position.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: locations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final location = locations[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.place_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    location.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${location.lat.toStringAsFixed(5)}, '
                    '${location.lng.toStringAsFixed(5)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteLocation(location),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
