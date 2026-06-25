import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/theme/app_theme.dart';

class ProfileSelectScreen extends StatelessWidget {
  const ProfileSelectScreen({super.key});

  static const List<_ProfileOption> _profiles = [
    _ProfileOption(icon: Icons.accessible, label: 'Wheelchair'),
    _ProfileOption(icon: Icons.elderly, label: 'Senior Citizen'),
    _ProfileOption(icon: Icons.child_friendly, label: 'Stroller'),
    _ProfileOption(icon: Icons.luggage, label: 'Luggage'),
    _ProfileOption(icon: Icons.personal_injury, label: 'Temporary Injury'),
    _ProfileOption(icon: Icons.directions_walk, label: 'General'),
  ];

  Future<void> _selectProfile(BuildContext context, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedProfileKey, label);
    if (context.mounted) context.go(AppConstants.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Image.asset(AppConstants.logoPath, height: 32, fit: BoxFit.contain),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your profile',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We\'ll tailor routes to suit your needs.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    return _ProfileCard(
                      profile: profile,
                      onTap: () => _selectProfile(context, profile.label),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final _ProfileOption profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(profile.icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              profile.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption {
  const _ProfileOption({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
