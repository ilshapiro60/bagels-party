import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/community_vet_clinic.dart';
import '../../models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../../services/approximate_location.dart';

class CommunityVetClinicsScreen extends ConsumerStatefulWidget {
  const CommunityVetClinicsScreen({super.key});

  @override
  ConsumerState<CommunityVetClinicsScreen> createState() =>
      _CommunityVetClinicsScreenState();
}

class _CommunityVetClinicsScreenState
    extends ConsumerState<CommunityVetClinicsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CommunityVetClinic> _filtered(List<CommunityVetClinic> all) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      final name = c.displayName.toLowerCase();
      final addr = (c.address ?? '').toLowerCase();
      return name.contains(q) || addr.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final clinics = ref.watch(communityVetClinicsProvider);
    final user = ref.watch(authStateProvider).user;
    final hasUserCoords =
        user != null && user.latitude != null && user.longitude != null;
    final filtered = _filtered(clinics);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community vet clinics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by clinic name or address…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: PawPartyColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: PawPartyColors.divider),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: PawPartyColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clinics listed here were added on pet profiles (yours and neighbors). '
                    'Always verify details before visiting.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: PawPartyColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!hasUserCoords)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Add your neighborhood location in Profile to sort clinics by distance when coordinates are available.',
                style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        clinics.isEmpty
                            ? 'No community clinics yet. When neighbors link a vet on a pet, it will show up here.'
                            : 'No clinics match your search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PawPartyColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final dist = _distanceLabel(user, c);
                      return Card(
                        elevation: 0,
                        color: PawPartyColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: PawPartyColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (c.address != null &&
                                  c.address!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  c.address!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: PawPartyColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${c.linkedOwnerCount} neighbor${c.linkedOwnerCount == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${c.linkCount} pet${c.linkCount == 1 ? '' : 's'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (dist != null)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: const Icon(Icons.place_outlined, size: 16),
                                      label: Text(dist, style: const TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String? _distanceLabel(UserProfile? user, CommunityVetClinic c) {
    final ulat = user?.latitude;
    final ulng = user?.longitude;
    final plat = c.latitude;
    final plng = c.longitude;
    if (ulat == null || ulng == null || plat == null || plng == null) {
      return null;
    }
    final m = haversineMeters(
      GeoPoint(ulat, ulng),
      GeoPoint(plat, plng),
    );
    if (m < 1609) {
      return '${m.round()} m away';
    }
    final mi = m / 1609.34;
    return '${mi.toStringAsFixed(mi >= 10 ? 0 : 1)} mi away';
  }
}
