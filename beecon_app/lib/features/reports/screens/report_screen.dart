import 'dart:io';

import 'package:beecon_app/core/storage/hive_service.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/features/reports/models/report_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _reportTypes = [
    'Broken Elevator',
    'Blocked Ramp',
    'Construction',
    'Damaged Sidewalk',
    'Unsafe Crossing',
    'Other',
  ];

  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  String _reportType = _reportTypes.first;
  String? _photoPath;
  double? _lat;
  double? _lng;
  bool _loadingLocation = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadGpsCoordinates();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGpsCoordinates() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (!status.isGranted) {
          if (mounted) setState(() => _loadingLocation = false);
          return;
        }
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _loadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _photoPath = picked.path);
    }
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('Choose from gallery', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: Text('Take a photo', style: GoogleFonts.poppins()),
                    onTap: () {
                      Navigator.pop(context);
                      _pickPhoto(ImageSource.camera);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitReport() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a description.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS coordinates unavailable. Enable location and try again.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final report = ReportModel(
      reportType: _reportType,
      description: description,
      lat: _lat!,
      lng: _lng!,
      photoPath: _photoPath,
    );

    await HiveService.saveReport(report);

    if (!mounted) return;
    setState(() => _submitting = false);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Success',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Report submitted successfully',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    _descriptionController.clear();
    setState(() => _photoPath = null);
    await _loadGpsCoordinates();
  }

  String get _coordinatesLabel {
    if (_loadingLocation) return 'Fetching GPS…';
    if (_lat == null || _lng == null) return 'Location unavailable';
    return '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report an accessibility obstacle',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reports are saved locally on your device.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            Text(
              'Report type',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _reportType,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.accent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
              items: _reportTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type, style: GoogleFonts.poppins()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _reportType = value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe the obstacle…',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                filled: true,
                fillColor: AppColors.accent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Photo (optional)',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showPhotoSourcePicker,
              child: Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: _photoPath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined,
                              color: Colors.grey, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add photo',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(_photoPath!, fit: BoxFit.cover,
                                width: double.infinity, height: 140)
                            : Image.file(
                                File(_photoPath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 140,
                              ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'GPS coordinates',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Row(
                children: [
                  if (_loadingLocation)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.gps_fixed, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _coordinatesLabel,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReport,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Submit Report',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
