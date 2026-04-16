enum MeetupStatus { draft, open, full, inProgress, completed, cancelled }

MeetupStatus _parseMeetupStatus(Object? raw) {
  if (raw is! String) return MeetupStatus.open;
  for (final v in MeetupStatus.values) {
    if (v.name == raw) return v;
  }
  return MeetupStatus.open;
}

InviteStatus _parseInviteStatus(Object? raw) {
  if (raw is! String) return InviteStatus.pending;
  for (final v in InviteStatus.values) {
    if (v.name == raw) return v;
  }
  return InviteStatus.pending;
}

enum InviteStatus { pending, accepted, declined }

class Meetup {
  final String id;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final String title;
  final String? description;
  final String theme;
  final DateTime dateTime;
  final int durationMinutes;
  final String address;
  final double latitude;
  final double longitude;
  final int maxGuests;
  final List<MeetupInvite> invites;
  final PizzaCommitment pizzaCommitment;
  final MeetupStatus status;
  final bool hasYard;
  final bool hasPool;
  final bool kidFriendly;
  final List<String> compatiblePetIds;
  final DateTime createdAt;

  /// When true the event is discoverable by all nearby users (not invite-only).
  final bool isPublic;
  final String? venueName;
  final String? venuePlaceId;

  const Meetup({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    required this.title,
    this.description,
    required this.theme,
    required this.dateTime,
    this.durationMinutes = 120,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.maxGuests = 4,
    this.invites = const [],
    required this.pizzaCommitment,
    this.status = MeetupStatus.open,
    this.hasYard = false,
    this.hasPool = false,
    this.kidFriendly = true,
    this.compatiblePetIds = const [],
    required this.createdAt,
    this.isPublic = false,
    this.venueName,
    this.venuePlaceId,
  });

  int get acceptedCount => invites.where((i) => i.status == InviteStatus.accepted).length;
  bool get isFull => acceptedCount >= maxGuests;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'title': title,
      'description': description,
      'theme': theme,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maxGuests': maxGuests,
      'invites': invites.map((i) => i.toMap()).toList(),
      'pizzaCommitment': pizzaCommitment.toMap(),
      'status': status.name,
      'hasYard': hasYard,
      'hasPool': hasPool,
      'kidFriendly': kidFriendly,
      'compatiblePetIds': compatiblePetIds,
      'createdAt': createdAt.toIso8601String(),
      'isPublic': isPublic,
      'venueName': venueName,
      'venuePlaceId': venuePlaceId,
    };
  }

  factory Meetup.fromMap(Map<String, dynamic> map) {
    return Meetup(
      id: map['id'] as String,
      hostId: map['hostId'] as String,
      hostName: map['hostName'] as String,
      hostPhotoUrl: map['hostPhotoUrl'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      theme: map['theme'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      durationMinutes: map['durationMinutes'] as int? ?? 120,
      address: map['address'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      maxGuests: map['maxGuests'] as int? ?? 4,
      invites: (map['invites'] as List?)
              ?.map((i) => MeetupInvite.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      pizzaCommitment: PizzaCommitment.fromMap(
          map['pizzaCommitment'] as Map<String, dynamic>),
      status: _parseMeetupStatus(map['status']),
      hasYard: map['hasYard'] as bool? ?? false,
      hasPool: map['hasPool'] as bool? ?? false,
      kidFriendly: map['kidFriendly'] as bool? ?? true,
      compatiblePetIds: List<String>.from(map['compatiblePetIds'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isPublic: map['isPublic'] as bool? ?? false,
      venueName: map['venueName'] as String?,
      venuePlaceId: map['venuePlaceId'] as String?,
    );
  }

  /// Displayable location label: venue name if set, otherwise raw address.
  String get venueDisplayName =>
      venueName != null && venueName!.trim().isNotEmpty ? venueName! : address;

  DateTime get endDateTime =>
      dateTime.add(Duration(minutes: durationMinutes));

  /// Scheduled end is still in the future and the party is not cancelled.
  bool get hasNotEnded =>
      status != MeetupStatus.cancelled &&
      endDateTime.isAfter(DateTime.now());
}

/// All hosted parties: upcoming / in-progress first (soonest first), then past (most recent first).
List<Meetup> sortHostedMeetupsFutureFirst(List<Meetup> all) {
  final upcoming = all.where((m) => m.hasNotEnded).toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final past = all.where((m) => !m.hasNotEnded).toList()
    ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return [...upcoming, ...past];
}

class MeetupInvite {
  final String guestId;
  final String guestName;
  final List<String> petIds;
  final InviteStatus status;
  final DateTime sentAt;

  const MeetupInvite({
    required this.guestId,
    required this.guestName,
    required this.petIds,
    this.status = InviteStatus.pending,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'guestId': guestId,
      'guestName': guestName,
      'petIds': petIds,
      'status': status.name,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory MeetupInvite.fromMap(Map<String, dynamic> map) {
    return MeetupInvite(
      guestId: map['guestId'] as String,
      guestName: map['guestName'] as String,
      petIds: List<String>.from(map['petIds'] ?? []),
      status: _parseInviteStatus(map['status']),
      sentAt: DateTime.parse(map['sentAt'] as String),
    );
  }
}

class PizzaCommitment {
  final bool willProvidePizza;
  final bool willProvideDrinks;
  final bool willAccommodateAllergies;
  final bool acknowledgesHostDuty;
  /// Guests may bring a dish to share in addition to (or without) hosted pizza.
  final bool willIncludePotluck;
  final String? pizzaPartner;
  final String? specialNotes;

  const PizzaCommitment({
    this.willProvidePizza = false,
    this.willProvideDrinks = false,
    this.willAccommodateAllergies = false,
    this.acknowledgesHostDuty = false,
    this.willIncludePotluck = false,
    this.pizzaPartner,
    this.specialNotes,
  });

  bool get isComplete =>
      willProvidePizza &&
      willProvideDrinks &&
      willAccommodateAllergies &&
      acknowledgesHostDuty;

  /// Compact label for meetup cards (pizza and potluck can both apply).
  String get foodSummaryForCard {
    if (willProvidePizza && willIncludePotluck) {
      final p = (pizzaPartner?.trim().isNotEmpty ?? false)
          ? pizzaPartner!.trim()
          : 'Pizza included';
      return '$p + potluck';
    }
    if (willProvidePizza) {
      return (pizzaPartner?.trim().isNotEmpty ?? false)
          ? pizzaPartner!.trim()
          : 'Pizza included';
    }
    if (willIncludePotluck) return 'Potluck welcome';
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'willProvidePizza': willProvidePizza,
      'willProvideDrinks': willProvideDrinks,
      'willAccommodateAllergies': willAccommodateAllergies,
      'acknowledgesHostDuty': acknowledgesHostDuty,
      'willIncludePotluck': willIncludePotluck,
      'pizzaPartner': pizzaPartner,
      'specialNotes': specialNotes,
    };
  }

  factory PizzaCommitment.fromMap(Map<String, dynamic> map) {
    return PizzaCommitment(
      willProvidePizza: map['willProvidePizza'] as bool? ?? false,
      willProvideDrinks: map['willProvideDrinks'] as bool? ?? false,
      willAccommodateAllergies: map['willAccommodateAllergies'] as bool? ?? false,
      acknowledgesHostDuty: map['acknowledgesHostDuty'] as bool? ?? false,
      willIncludePotluck: map['willIncludePotluck'] as bool? ?? false,
      pizzaPartner: map['pizzaPartner'] as String?,
      specialNotes: map['specialNotes'] as String?,
    );
  }
}
