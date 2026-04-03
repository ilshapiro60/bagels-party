import 'package:flutter/material.dart';
import '../config/theme.dart';

class MapUnavailablePlaceholder extends StatelessWidget {
  const MapUnavailablePlaceholder({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: height,
        color: PawPartyColors.surfaceVariant,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 40, color: PawPartyColors.textHint),
                const SizedBox(height: 12),
                Text(
                  'Map preview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Google Maps runs on Android, iOS, and web. Use one of those targets to see approximate pet areas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: PawPartyColors.textSecondary,
                    height: 1.35,
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
