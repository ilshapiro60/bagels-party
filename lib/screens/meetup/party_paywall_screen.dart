import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/meetup.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_meetup_repository.dart';
import '../../services/firestore_profile_repository.dart';
import '../../services/iap_service.dart';
import '../../utils/hosting_fee.dart';

class PartyPaywallScreen extends ConsumerStatefulWidget {
  final Meetup meetup;
  final double fee;

  const PartyPaywallScreen({
    super.key,
    required this.meetup,
    required this.fee,
  });

  @override
  ConsumerState<PartyPaywallScreen> createState() => _PartyPaywallScreenState();
}

class _PartyPaywallScreenState extends ConsumerState<PartyPaywallScreen> {
  bool _processing = false;

  Future<void> _payAndPublish() async {
    setState(() => _processing = true);

    try {
      final productId = hostingFeeProductId(widget.fee);
      final success = await IapService.instance.purchasePartyHosting(productId);

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment was cancelled or failed. Please try again.')),
        );
        setState(() => _processing = false);
        return;
      }

      await _publishMeetup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e')),
      );
      setState(() => _processing = false);
    }
  }

  Future<void> _publishMeetup() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;

    try {
      await FirestoreMeetupRepository.createMeetup(widget.meetup);
      await FirestoreProfileRepository.incrementHostCount(user.id);
      ref.read(authStateProvider.notifier).updateUser(
            user.copyWithHostCount(user.hostCount + 1),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.meetup.isPublic
                ? 'Public event created! Nearby pet owners can now discover it.'
                : 'Party created! Now invite your friends.',
          ),
          backgroundColor: PawPartyColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      if (widget.meetup.isPublic) {
        context.go('/home');
      } else {
        context.go('/invite-friends/${widget.meetup.id}');
      }
    } catch (e) {
      if (!mounted) return;
      final es = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            es.contains('permission-denied')
                ? 'Permission denied saving the party. Deploy latest rules: '
                    'firebase deploy --only firestore:rules'
                : 'Could not create party: $e',
          ),
        ),
      );
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meetup;
    final formattedDate = DateFormat('EEE, MMM d · h:mm a').format(m.dateTime);
    final fee = widget.fee;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _processing ? null : () => context.pop(),
        ),
        title: const Text('Confirm & Pay'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: PawPartyColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.celebration,
                        size: 40,
                        color: PawPartyColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      m.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 15,
                        color: PawPartyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _summaryCard(context, m),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            PawPartyColors.pizzaGold.withValues(alpha: 0.15),
                            PawPartyColors.primary.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: PawPartyColors.pizzaGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, color: PawPartyColors.pizzaGold),
                          const SizedBox(width: 12),
                          Text(
                            '\$${fee.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: PawPartyColors.textPrimary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'hosting fee',
                            style: TextStyle(
                              fontSize: 15,
                              color: PawPartyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _payAndPublish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PawPartyColors.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Pay \$${fee.toStringAsFixed(2)} & Publish',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, Meetup m) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PawPartyColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PawPartyColors.divider),
      ),
      child: Column(
        children: [
          _summaryRow(Icons.location_on, m.venueDisplayName),
          const Divider(height: 20),
          _summaryRow(Icons.schedule, '${m.durationMinutes} minutes'),
          if (m.isPublic) ...[
            const Divider(height: 20),
            _summaryRow(Icons.group, 'Up to ${m.maxGuests} guests'),
          ],
          if (m.isPublic) ...[
            const Divider(height: 20),
            _summaryRow(Icons.public, 'Public event'),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: PawPartyColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: PawPartyColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
