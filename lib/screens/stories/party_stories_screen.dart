import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/party_story.dart';
import '../../providers/app_providers.dart';
import '../../services/firestore_story_repository.dart';
import '../../widgets/fullscreen_video.dart';
import '../../widgets/paw_file_image.dart';
import '../../widgets/paw_video_thumb.dart';

class PartyStoriesScreen extends ConsumerWidget {
  const PartyStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).user?.id;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Party stories')),
        body: const Center(child: Text('Sign in to see your stories.')),
      );
    }
    final storiesAsync = ref.watch(myPartyStoriesProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Party stories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/add-story'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-story'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('New story'),
        backgroundColor: PawPartyColors.bloomPink,
        foregroundColor: Colors.white,
      ),
      body: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading stories: $e'),
          ),
        ),
        data: (stories) => stories.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 56, color: PawPartyColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'No stories yet',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share photos and videos from your parties. Tap + to post.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: PawPartyColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  return _StoryCard(
                    story: stories[index],
                    isOwner: true,
                    onDelete: () => _confirmDelete(context, stories[index]),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PartyStory story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        content: Text('This will permanently remove "${story.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirestoreStoryRepository.deleteStory(
        storyId: story.id,
        actingUid: story.authorId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    this.isOwner = false,
    this.onDelete,
  });

  final PartyStory story;
  final bool isOwner;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(story.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      PawPartyColors.secondary.withValues(alpha: 0.2),
                  child: story.authorPhotoPath != null &&
                          story.authorPhotoPath!.isNotEmpty
                      ? ClipOval(
                          child: PawFileOrNetworkImage(
                            path: story.authorPhotoPath!,
                            width: 40,
                            height: 40,
                          ),
                        )
                      : Text(
                          story.authorName.isNotEmpty
                              ? story.authorName[0]
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: PawPartyColors.secondary,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.authorName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: PawPartyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner && onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: PawPartyColors.textHint),
                    tooltip: 'Delete story',
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (story.caption != null && story.caption!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                story.caption!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (story.hasMedia) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...story.imagePaths.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: PawFileOrNetworkImage(path: p),
                          ),
                        ),
                      ),
                    ),
                    ...story.videoPaths.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => openFullscreenLocalVideo(context, p),
                          child: SizedBox(
                            width: 112,
                            height: 112,
                            child: PawVideoThumbnail(path: p, height: 112),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
