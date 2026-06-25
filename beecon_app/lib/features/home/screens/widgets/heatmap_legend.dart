import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          _LegendRow(color: const Color(0xFF4CAF50), label: 'Accessible'),
          const SizedBox(height: 4),
          _LegendRow(color: const Color(0xFFFF8A00), label: 'Moderate'),
          const SizedBox(height: 4),
          _LegendRow(color: const Color(0xFFF44336), label: 'Barrier'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[800]),
        ),
      ],
    );
  }
}
