import 'package:beecon_app/core/constants/app_constants.dart';
import 'package:beecon_app/core/storage/ai_insight_storage.dart';
import 'package:beecon_app/core/theme/app_theme.dart';
import 'package:beecon_app/core/widgets/beecon_branding.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiInsightBanner extends StatefulWidget {
  const AiInsightBanner({super.key});

  @override
  State<AiInsightBanner> createState() => _AiInsightBannerState();
}

class _AiInsightBannerState extends State<AiInsightBanner> {
  String? _insight;
  bool _dismissed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    final insight = await AiInsightStorage.getLastInsight();
    final dismissed = await AiInsightStorage.isBannerDismissed();
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _dismissed = dismissed;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    await AiInsightStorage.dismissBanner();
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _insight == null || _insight!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      AppConstants.logoPath,
                      width: BeeconLogoSizes.insight,
                      height: BeeconLogoSizes.insight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Accessibility Insight',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _insight!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.4,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: _dismiss,
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
