import 'pet.dart';

/// A veterinary clinic aggregated from community pets (deduped).
class CommunityVetClinic {
  const CommunityVetClinic({
    required this.dedupeKey,
    required this.displayName,
    this.address,
    this.latitude,
    this.longitude,
    required this.linkCount,
    required this.linkedOwnerCount,
  });

  final String dedupeKey;
  final String displayName;
  final String? address;
  final double? latitude;
  final double? longitude;
  /// Pets on the app linked to this clinic (same clinic may be on multiple pets).
  final int linkCount;
  /// Distinct pet owners (families) linked to this clinic.
  final int linkedOwnerCount;

  /// Google Place ID when pets linked this clinic via Places (`dedupeKey` is `place:…`).
  /// Use with Maps URLs to open the full listing (reviews, hours, photos).
  String? get googlePlaceId {
    if (!dedupeKey.startsWith('place:')) return null;
    final id = dedupeKey.substring(6).trim();
    return id.isEmpty ? null : id;
  }

  /// Stable key: Google Place ID when set, else normalized name + address.
  static String dedupeKeyForPet(Pet p) {
    final place = p.vetGooglePlaceId?.trim();
    if (place != null && place.isNotEmpty) return 'place:$place';
    final n = p.vetClinicName!.trim().toLowerCase();
    final a = (p.vetClinicAddress ?? '').trim().toLowerCase();
    return 'na:$n|$a';
  }

  static List<CommunityVetClinic> aggregateFromPets(List<Pet> pets) {
    final buckets = <String,
        ({
          String name,
          String? addr,
          double? lat,
          double? lng,
          int petCount,
          Set<String> ownerIds,
        })>{};
    for (final p in pets) {
      if (!p.hasVetClinicLink) continue;
      final k = dedupeKeyForPet(p);
      final rawAddr = p.vetClinicAddress?.trim();
      final cleanAddr =
          rawAddr == null || rawAddr.isEmpty ? null : rawAddr;
      final cur = buckets[k];
      if (cur == null) {
        buckets[k] = (
          name: p.vetClinicName!.trim(),
          addr: cleanAddr,
          lat: p.vetClinicLatitude,
          lng: p.vetClinicLongitude,
          petCount: 1,
          ownerIds: {p.ownerId},
        );
      } else {
        final owners = Set<String>.from(cur.ownerIds)..add(p.ownerId);
        buckets[k] = (
          name: cur.name,
          addr: cur.addr ?? cleanAddr,
          lat: cur.lat ?? p.vetClinicLatitude,
          lng: cur.lng ?? p.vetClinicLongitude,
          petCount: cur.petCount + 1,
          ownerIds: owners,
        );
      }
    }
    return buckets.entries
        .map(
          (e) => CommunityVetClinic(
            dedupeKey: e.key,
            displayName: e.value.name,
            address: e.value.addr,
            latitude: e.value.lat,
            longitude: e.value.lng,
            linkCount: e.value.petCount,
            linkedOwnerCount: e.value.ownerIds.length,
          ),
        )
        .toList();
  }
}
