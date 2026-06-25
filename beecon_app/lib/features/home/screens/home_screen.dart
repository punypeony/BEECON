import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          AppConstants.logoPath,
          height: 48,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar placeholder
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Search destination…',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Map placeholder
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: Colors.grey[500]),
                        const SizedBox(height: 12),
                        Text(
                          'Map coming soon',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
