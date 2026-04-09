import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/passport_entry.dart';
import 'fullscreen_video.dart';
import 'paw_file_image.dart';
import 'paw_video_thumb.dart';

class PassportEntryCard extends StatelessWidget {
  final PassportEntry entry;
  final VoidCallback? onDelete;
  /// Show pet name chip (e.g. on Community feed).
  final bool showPetAttribution;
  const PassportEntryCard({
    super.key,
    required this.entry,
    this.onDelete,
    this.showPetAttribution = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stamp design
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _themeColor(entry.meetupTheme).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _themeColor(entry.meetupTheme).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _themeColor(entry.meetupTheme).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      entry.playOutcome.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.meetupTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(entry.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: PawPartyColors.textSecondary,
                            ),
                          ),
                          if (entry.meetupTheme != null) ...[
                            const Text(' • ', style: TextStyle(color: PawPartyColors.textHint)),
                            Flexible(
                              child: Text(
                                entry.meetupTheme!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _themeColor(entry.meetupTheme),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (entry.rating != null) _buildRating(entry.rating!),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: PawPartyColors.error),
                    tooltip: 'Delete entry',
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
          if (showPetAttribution && entry.petName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PawPartyColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.petName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PawPartyColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.home, size: 14, color: PawPartyColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      'Hosted by ${entry.hostName}',
                      style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pets, size: 14, color: PawPartyColors.textHint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Met: ${entry.metPetNames.join(", ")}',
                        style: TextStyle(fontSize: 13, color: PawPartyColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (entry.behaviorNotes != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PawPartyColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote,
                          size: 16,
                          color: PawPartyColors.textHint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.behaviorNotes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: PawPartyColors.textPrimary,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (entry.photoUrls.isNotEmpty || entry.videoPaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...entry.photoUrls.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: PawFileOrNetworkImage(path: p),
                              ),
                            ),
                          ),
                        ),
                        ...entry.videoPaths.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => openFullscreenLocalVideo(context, p),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: PawVideoThumbnail(path: p, height: 72),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(
                      entry.playOutcome.label,
                      _outcomeColor(entry.playOutcome),
                    ),
                    if (entry.warmUpMinutes > 0)
                      _tag(
                        '${entry.warmUpMinutes}min warm-up',
                        PawPartyColors.secondary,
                      ),
                    if (entry.wasAnxious)
                      _tag('Anxious', PawPartyColors.error),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PawPartyColors.pizzaGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: PawPartyColors.pizzaGold),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PawPartyColors.pizzaGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _themeColor(String? theme) {
    switch (theme) {
      case 'Summer Splash':
        return Colors.blue;
      case 'Birthday Bash':
        return PawPartyColors.primary;
      case 'Holiday Howl':
        return Colors.red;
      case 'New Pet Welcome':
        return PawPartyColors.secondary;
      default:
        return PawPartyColors.textSecondary;
    }
  }

  Color _outcomeColor(PlayOutcome outcome) {
    switch (outcome) {
      case PlayOutcome.excellent:
        return PawPartyColors.success;
      case PlayOutcome.good:
        return PawPartyColors.secondary;
      case PlayOutcome.okay:
        return PawPartyColors.pizzaGold;
      case PlayOutcome.difficult:
        return PawPartyColors.error;
      case PlayOutcome.notCompatible:
        return Colors.red;
    }
  }
}
