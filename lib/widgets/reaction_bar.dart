import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/reaction.dart';
import '../providers/app_providers.dart';
import '../services/firestore_reaction_repository.dart';

/// Compact reaction bar: shows existing reaction counts and a "+" to add.
/// Tapping an existing reaction toggles it; tapping "+" opens the full picker.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({
    super.key,
    required this.targetId,
    this.dark = false,
  });

  final String targetId;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).user?.id;
    if (uid == null) return const SizedBox.shrink();

    final reactionsAsync = ref.watch(reactionsProvider(targetId));
    final reactions = reactionsAsync.value ?? [];
    final summary = ReactionSummary.fromList(reactions, uid);

    final fg = dark ? Colors.white70 : PawPartyColors.textSecondary;
    final activeFg = dark ? Colors.white : PawPartyColors.primary;
    final chipBg = dark
        ? Colors.white.withValues(alpha: 0.12)
        : PawPartyColors.primary.withValues(alpha: 0.08);
    final activeChipBg = dark
        ? Colors.white.withValues(alpha: 0.25)
        : PawPartyColors.primary.withValues(alpha: 0.18);

    final sorted = summary.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in sorted) ...[
          _ReactionChip(
            emoji: PawReaction.fromId(entry.key)?.emoji ?? entry.key,
            count: entry.value,
            isActive: summary.myReactionId == entry.key,
            bg: summary.myReactionId == entry.key ? activeChipBg : chipBg,
            fg: summary.myReactionId == entry.key ? activeFg : fg,
            onTap: () => FirestoreReactionRepository.toggleReaction(
              targetId: targetId,
              userId: uid,
              reactionId: entry.key,
            ),
          ),
          const SizedBox(width: 4),
        ],
        _AddReactionButton(
          dark: dark,
          onSelected: (reactionId) => FirestoreReactionRepository.toggleReaction(
            targetId: targetId,
            userId: uid,
            reactionId: reactionId,
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isActive;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: fg.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({required this.dark, required this.onSelected});

  final bool dark;
  final void Function(String reactionId) onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : PawPartyColors.divider.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          size: 16,
          color: dark ? Colors.white54 : PawPartyColors.textHint,
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: PawReaction.all.map((r) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onSelected(r.id);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 2),
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: PawPartyColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
