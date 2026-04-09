import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Categories available for newsletter posts.
class NewsCategory {
  const NewsCategory._({
    required this.id,
    required this.label,
    required this.icon,
    this.bodyHint,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? bodyHint;

  static const general = NewsCategory._(
    id: 'general',
    label: 'General',
    icon: Icons.article_outlined,
  );
  static const lostPet = NewsCategory._(
    id: 'lost_pet',
    label: 'Lost Pet',
    icon: Icons.search,
    bodyHint: 'Include breed, color, size, last seen location and time',
  );
  static const foundPet = NewsCategory._(
    id: 'found_pet',
    label: 'Found Pet',
    icon: Icons.pets,
    bodyHint: 'Describe the pet and where you found it',
  );
  static const safety = NewsCategory._(
    id: 'safety',
    label: 'Safety Alert',
    icon: Icons.warning_amber_rounded,
    bodyHint: 'Describe the hazard, location, and when it was observed',
  );
  static const recommendation = NewsCategory._(
    id: 'recommendation',
    label: 'Recommendation',
    icon: Icons.thumb_up_outlined,
    bodyHint: 'Share what you recommend and why',
  );
  static const selling = NewsCategory._(
    id: 'selling',
    label: 'For Sale / Free',
    icon: Icons.sell_outlined,
    bodyHint: 'Describe the item, condition, and price (or free)',
  );
  static const service = NewsCategory._(
    id: 'service',
    label: 'Pet Service',
    icon: Icons.volunteer_activism_outlined,
    bodyHint: 'Describe the service you offer, availability, and rates',
  );

  static const all = [general, lostPet, foundPet, safety, recommendation, selling, service];

  static NewsCategory fromId(String? id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return general;
  }
}

/// Shared area newsletter post (2-week retention enforced by query + optional TTL).
class NeighborhoodNewsPost {
  const NeighborhoodNewsPost({
    required this.id,
    required this.areaKey,
    required this.authorId,
    required this.authorDisplayName,
    this.authorPhotoUrl,
    this.title,
    required this.body,
    required this.createdAt,
    this.hidden = false,
    this.category = 'general',
    this.photoUrls = const [],
  });

  final String id;
  final String areaKey;
  final String authorId;
  final String authorDisplayName;
  final String? authorPhotoUrl;
  final String? title;
  final String body;
  final DateTime createdAt;
  final bool hidden;
  final String category;
  final List<String> photoUrls;

  NewsCategory get newsCategory => NewsCategory.fromId(category);

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final rawPhotos = m['photoUrls'];
    final photos = rawPhotos is List
        ? rawPhotos.whereType<String>().toList()
        : <String>[];
    return NeighborhoodNewsPost(
      id: doc.id,
      areaKey: m['areaKey'] as String? ?? '',
      authorId: m['authorId'] as String? ?? '',
      authorDisplayName: m['authorDisplayName'] as String? ?? 'Member',
      authorPhotoUrl: m['authorPhotoUrl'] as String?,
      title: m['title'] as String?,
      body: m['body'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
      hidden: m['hidden'] as bool? ?? false,
      category: m['category'] as String? ?? 'general',
      photoUrls: photos,
    );
  }
}

class NeighborhoodNewsComment {
  const NeighborhoodNewsComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorDisplayName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorDisplayName;
  final String body;
  final DateTime createdAt;

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsComment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String postId,
  ) {
    final m = doc.data() ?? {};
    return NeighborhoodNewsComment(
      id: doc.id,
      postId: postId,
      authorId: m['authorId'] as String? ?? '',
      authorDisplayName: m['authorDisplayName'] as String? ?? 'Member',
      body: m['body'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
    );
  }
}

class NeighborhoodNewsReport {
  const NeighborhoodNewsReport({
    required this.id,
    required this.postId,
    required this.areaKey,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.postTitleSnippet,
  });

  final String id;
  final String postId;
  final String areaKey;
  final String reporterId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? postTitleSnippet;

  static const String statusPending = 'pending';
  static const String statusDismissed = 'dismissed';
  static const String statusActionTaken = 'action_taken';

  static DateTime _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.parse(v);
    return DateTime.now();
  }

  factory NeighborhoodNewsReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return NeighborhoodNewsReport(
      id: doc.id,
      postId: m['postId'] as String? ?? '',
      areaKey: m['areaKey'] as String? ?? '',
      reporterId: m['reporterId'] as String? ?? '',
      reason: m['reason'] as String? ?? '',
      status: m['status'] as String? ?? statusPending,
      createdAt: _ts(m['createdAt']),
      postTitleSnippet: m['postTitleSnippet'] as String?,
    );
  }
}
