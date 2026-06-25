import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RouteResultsScreen extends StatelessWidget {
  const RouteResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Routes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Route results coming soon',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
