import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/pet.dart';
import 'paw_file_image.dart';
import 'paw_fullscreen_photo_viewer.dart';

class PetCard extends StatelessWidget {
  final Pet pet;
  final double compatibility;
  final VoidCallback? onTap;

  /// Tapping the pet photo opens all photos (profile + gallery) fullscreen.
  final bool avatarOpensFullscreenPhotos;

  const PetCard({
    super.key,
    required this.pet,
    this.compatibility = 0,
    this.onTap,
    this.avatarOpensFullscreenPhotos = true,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrls = pet.photoUrlsForViewer;
    final primaryThumb = pet.photoUrl != null && pet.photoUrl!.trim().isNotEmpty
        ? pet.photoUrl!.trim()
        : (photoUrls.isNotEmpty ? photoUrls.first : null);

    final avatar = CircleAvatar(
      radius: 32,
      backgroundColor: PawPartyColors.primary.withValues(alpha: 0.1),
      child: primaryThumb != null
          ? ClipOval(
              child: PawFileOrNetworkImage(
                path: primaryThumb,
                width: 64,
                height: 64,
              ),
            )
          : Text(
              pet.name.isNotEmpty ? pet.name[0] : '?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: PawPartyColors.primary,
              ),
            ),
    );

    final avatarWidget = avatarOpensFullscreenPhotos && photoUrls.isNotEmpty
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showPawFullscreenPhotos(
                  context,
                  urls: photoUrls,
                  initialIndex: 0,
                ),
            child: avatar,
          )
        : avatar;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pet.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (compatibility > 0) _buildCompatibilityBadge(compatibility),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${pet.breed ?? pet.type} • ${pet.gender} • ${pet.ageDisplay} • ${pet.size.split(' ').first}',
          style: TextStyle(
            fontSize: 13,
            color: PawPartyColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _trait(pet.energyLabel, _energyColor(pet.energyLevel)),
            const SizedBox(width: 6),
            _trait(pet.socialLabel, _socialColor(pet.socialComfort)),
          ],
        ),
        if (pet.playStyles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: pet.playStyles.take(3).map((style) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PawPartyColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  style,
                  style: TextStyle(
                    fontSize: 11,
                    color: PawPartyColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );

    final detailsPane = onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: details,
              ),
            ),
          )
        : details;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PawPartyColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarWidget,
          const SizedBox(width: 16),
          Expanded(child: detailsPane),
        ],
      ),
    );
  }

  Widget _buildCompatibilityBadge(double score) {
    Color color;
    if (score >= 80) {
      color = PawPartyColors.success;
    } else if (score >= 60) {
      color = PawPartyColors.pizzaGold;
    } else {
      color = PawPartyColors.textHint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${score.toInt()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _trait(String label, Color color) {
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

  Color _energyColor(double level) {
    if (level < 0.33) return PawPartyColors.secondary;
    if (level < 0.66) return PawPartyColors.pizzaGold;
    return PawPartyColors.primary;
  }

  Color _socialColor(double level) {
    if (level < 0.33) return PawPartyColors.error;
    if (level < 0.66) return PawPartyColors.pizzaGold;
    return PawPartyColors.success;
  }
}
