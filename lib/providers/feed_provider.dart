import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_item.dart';
import '../models/neighborhood_news.dart';
import '../models/pet.dart';
import '../services/firestore_neighborhood_news_repository.dart';
import 'app_providers.dart';

/// Minimum local items before we pull from other areas.
const _localThreshold = 8;

final feedItemsProvider = FutureProvider<List<FeedItem>>((ref) async {
  final user = ref.watch(authStateProvider).user;
  if (user == null) return [];

  final localPets = ref.watch(nearbyPetsProvider);
  final localPosts =
      ref.watch(neighborhoodNewsPostsProvider).value ?? [];

  final local = <FeedItem>[];

  // ── 1. Videos from local pets ───────────────────────────────────────────
  for (final pet in localPets) {
    for (var i = 0; i < pet.videoPaths.length; i++) {
      final url = pet.videoPaths[i];
      if (url.isNotEmpty) {
        local.add(_petVideo(pet, url, i));
      }
    }
  }

  // ── 2. Videos from local news posts ────────────────────────────────────
  for (final post in localPosts) {
    for (var i = 0; i < post.videoUrls.length; i++) {
      final url = post.videoUrls[i];
      if (url.isNotEmpty) {
        local.add(_postVideo(post, url, i));
      }
    }
  }

  // ── 3. Photos from local pets (pad if still thin) ──────────────────────
  if (local.length < _localThreshold) {
    for (final pet in localPets) {
      for (var i = 0; i < pet.photoGallery.length && i < 3; i++) {
        final url = pet.photoGallery[i];
        if (url.isNotEmpty) {
          local.add(_petPhoto(pet, url, i));
        }
      }
    }
  }

  // ── 4. Photos from local news posts ────────────────────────────────────
  if (local.length < _localThreshold) {
    for (final post in localPosts) {
      for (var i = 0; i < post.photoUrls.length; i++) {
        final url = post.photoUrls[i];
        if (url.isNotEmpty) {
          local.add(_postPhoto(post, url, i));
        }
      }
    }
  }

  // ── 5. Fallback: popular from other areas ──────────────────────────────
  final global = <FeedItem>[];
  if (local.length < _localThreshold) {
    final globalPosts =
        await FirestoreNeighborhoodNewsRepository.fetchMediaPostsGlobally(
      excludeAreaKey: user.neighborhoodKey,
      limit: 30,
    );
    for (final post in globalPosts) {
      final label = _titleCaseArea(post.areaKey);
      for (var i = 0; i < post.videoUrls.length; i++) {
        final url = post.videoUrls[i];
        if (url.isNotEmpty) {
          global.add(_postVideo(post, url, i,
              idPrefix: 'g', areaLabel: label));
        }
      }
      for (var i = 0; i < post.photoUrls.length; i++) {
        final url = post.photoUrls[i];
        if (url.isNotEmpty) {
          global.add(_postPhoto(post, url, i,
              idPrefix: 'g', areaLabel: label));
        }
      }
    }
  }

  // Local content first; global shuffled (variety) then appended
  global.shuffle();
  return [...local, ...global];
});

// ── helpers ────────────────────────────────────────────────────────────────

FeedItem _petVideo(Pet pet, String url, int i) => FeedItem(
      id: '${pet.id}_v$i',
      type: FeedItemType.video,
      mediaUrl: url,
      authorName: '',
      petName: pet.name,
      petBreed: pet.breed,
      petId: pet.id,
    );

FeedItem _petPhoto(Pet pet, String url, int i) => FeedItem(
      id: '${pet.id}_p$i',
      type: FeedItemType.photo,
      mediaUrl: url,
      authorName: '',
      petName: pet.name,
      petBreed: pet.breed,
      petId: pet.id,
    );

FeedItem _postVideo(NeighborhoodNewsPost post, String url, int i,
        {String idPrefix = '', String? areaLabel}) =>
    FeedItem(
      id: '$idPrefix${post.id}_v$i',
      type: FeedItemType.video,
      mediaUrl: url,
      authorName: post.authorDisplayName,
      authorPhotoUrl: post.authorPhotoUrl,
      caption: (post.title?.isNotEmpty == true ? post.title : post.body)
          ?.trim(),
      areaLabel: areaLabel,
      postId: post.id,
    );

FeedItem _postPhoto(NeighborhoodNewsPost post, String url, int i,
        {String idPrefix = '', String? areaLabel}) =>
    FeedItem(
      id: '$idPrefix${post.id}_p$i',
      type: FeedItemType.photo,
      mediaUrl: url,
      authorName: post.authorDisplayName,
      authorPhotoUrl: post.authorPhotoUrl,
      caption: (post.title?.isNotEmpty == true ? post.title : post.body)
          ?.trim(),
      areaLabel: areaLabel,
      postId: post.id,
    );

String _titleCaseArea(String key) => key
    .split(RegExp(r'[-_\s]+'))
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
