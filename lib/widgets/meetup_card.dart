import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/meetup.dart';

class MeetupCard extends StatelessWidget {
  final Meetup meetup;
  final String? currentUserId;
  /// When set, host sees a delete control to remove the party from Firestore.
  final void Function(Meetup meetup)? onHostDelete;
  /// Replaces "X/Y families" when using [partyInvites] instead of embedded meetup invites.
  final String? guestSummaryOverride;
  final VoidCallback? onHostInviteMore;
  final VoidCallback? onHostManageGuests;
  final VoidCallback? onAddPhotos;

  const MeetupCard({
    super.key,
    required this.meetup,
    this.currentUserId,
    this.onHostDelete,
    this.guestSummaryOverride,
    this.onHostInviteMore,
    this.onHostManageGuests,
    this.onAddPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final isHosting =
        currentUserId != null && meetup.hostId == currentUserId;
    final dateStr = DateFormat('EEE, MMM d').format(meetup.dateTime);
    final timeStr = DateFormat('h:mm a').format(meetup.dateTime);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHosting
              ? PawPartyColors.primary.withValues(alpha: 0.3)
              : PawPartyColors.divider.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isHosting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PawPartyColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HOSTING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: PawPartyColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (isHosting && onHostDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => onHostDelete!(meetup),
                  icon: Icon(Icons.delete_outline, size: 20, color: PawPartyColors.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Delete party',
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _themeColor(meetup.theme).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  meetup.theme,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _themeColor(meetup.theme),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meetup.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Hosted by ${meetup.hostName}',
            style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: PawPartyColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '$dateStr • $timeStr',
                style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.people, size: 14, color: PawPartyColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  guestSummaryOverride ??
                      (meetup.maxGuests > 0
                          ? '${meetup.acceptedCount}/${meetup.maxGuests} families'
                          : '${meetup.acceptedCount} accepted'),
                  style: TextStyle(fontSize: 12, color: PawPartyColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.local_pizza, size: 16, color: PawPartyColors.pizzaGold),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  meetup.pizzaCommitment.pizzaPartner ?? 'Pizza included',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PawPartyColors.pizzaGold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (isHosting &&
              (onHostInviteMore != null || onHostManageGuests != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onHostInviteMore != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onHostInviteMore,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Invite'),
                      style: TextButton.styleFrom(
                        foregroundColor: PawPartyColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                if (onHostManageGuests != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onHostManageGuests,
                      icon: const Icon(Icons.groups, size: 18),
                      label: const Text('Guests'),
                      style: TextButton.styleFrom(
                        foregroundColor: PawPartyColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (onAddPhotos != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Add photos'),
                style: TextButton.styleFrom(
                  foregroundColor: PawPartyColors.bloomPink,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _themeColor(String theme) {
    switch (theme) {
      case 'Birthday Bash':
        return PawPartyColors.primary;
      case 'Puppy Bowl Sunday':
        return PawPartyColors.secondary;
      case 'Summer Splash':
        return Colors.blue;
      case 'Halloween Costume Party':
        return Colors.deepOrange;
      case 'Holiday Howl':
        return Colors.red;
      default:
        return PawPartyColors.textSecondary;
    }
  }
}
