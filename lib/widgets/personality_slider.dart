import 'package:flutter/material.dart';
import '../config/theme.dart';

class PersonalitySlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String lowLabel;
  final String highLabel;
  final IconData icon;
  final Color color;

  const PersonalitySlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.lowLabel,
    required this.highLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PawPartyColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.15),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lowLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: PawPartyColors.textHint,
                ),
              ),
              Text(
                highLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: PawPartyColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
