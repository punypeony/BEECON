import 'package:beecon_app/core/providers/destination_provider.dart';
import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:beecon_app/core/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSelectScreen extends ConsumerStatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  ConsumerState<ProfileSelectScreen> createState() =>
      _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends ConsumerState<ProfileSelectScreen> {
  static const List<_ProfileOption> _profiles = [
    _ProfileOption(icon: Icons.accessible, label: 'Wheelchair'),
    _ProfileOption(icon: Icons.elderly, label: 'Senior Citizen'),
    _ProfileOption(icon: Icons.child_friendly, label: 'Stroller'),
    _ProfileOption(icon: Icons.luggage, label: 'Luggage'),
    _ProfileOption(icon: Icons.personal_injury, label: 'Temporary Injury'),
    _ProfileOption(icon: Icons.directions_walk, label: 'General'),
  ];

  String? _selectedLabel;

  Future<void> _continue() async {
    if (_selectedLabel == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.selectedProfileKey, _selectedLabel!);
    ref.read(geminiServiceProvider).clearAgentCache();
    if (mounted) context.go(AppConstants.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ResponsivePageContent(
          maxWidth: 900,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const BeeconBrandHeader(
                  subtitle: 'Choose your mobility profile',
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0.05,
                        child: Image.asset(
                          AppConstants.logoPath,
                          height: 240,
                          fit: BoxFit.contain,
                        ),
                      ),
                      GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              ResponsiveLayout.profileGridColumns(context),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              ResponsiveLayout.isDesktop(context) ? 1.35 : 1.1,
                        ),
                        itemCount: _profiles.length,
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          return _ProfileCard(
                            profile: profile,
                            isSelected: _selectedLabel == profile.label,
                            onTap: () =>
                                setState(() => _selectedLabel = profile.label),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedLabel == null ? null : _continue,
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  final _ProfileOption profile;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.selectedBackground : AppColors.accent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
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
