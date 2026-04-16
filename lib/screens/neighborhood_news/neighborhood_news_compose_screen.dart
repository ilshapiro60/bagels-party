import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme.dart';
import '../../models/neighborhood_news.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/firestore_neighborhood_news_repository.dart';

class NeighborhoodNewsComposeScreen extends ConsumerStatefulWidget {
  const NeighborhoodNewsComposeScreen({super.key});

  @override
  ConsumerState<NeighborhoodNewsComposeScreen> createState() =>
      _NeighborhoodNewsComposeScreenState();
}

class _NeighborhoodNewsComposeScreenState
    extends ConsumerState<NeighborhoodNewsComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  NewsCategory _selectedCategory = NewsCategory.general;
  final List<XFile> _pickedPhotos = [];
  final List<XFile> _pickedVideos = [];
  static const _maxPhotos = 5;
  static const _maxVideos = 3;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _pickedPhotos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 photos reached.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked.isEmpty) return;
      setState(() {
        final take = picked.take(remaining).toList();
        _pickedPhotos.addAll(take);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick photos: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _pickedPhotos.removeAt(index));
  }

  Future<void> _pickVideo() async {
    final remaining = _maxVideos - _pickedVideos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 videos reached.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return;
      setState(() => _pickedVideos.add(picked));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick video: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeVideo(int index) {
    setState(() => _pickedVideos.removeAt(index));
  }

  Future<void> _submit() async {
    final user = ref.read(authStateProvider).user;
    if (user == null) return;
    final bodyTrim = _body.text.trim();
    if (bodyTrim.isEmpty && _pickedPhotos.isEmpty && _pickedVideos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a message or at least one photo or video.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final postId = const Uuid().v4();
      final storage = FirebaseStorageService.instance;

      final photoUrls = <String>[];
      for (final photo in _pickedPhotos) {
        final url = await storage.uploadNewsPhoto(
          localPath: photo.path,
          postId: postId,
        );
        photoUrls.add(url);
      }

      final videoUrls = <String>[];
      for (final video in _pickedVideos) {
        final url = await storage.uploadNewsVideo(
          localPath: video.path,
          postId: postId,
        );
        videoUrls.add(url);
      }

      await FirestoreNeighborhoodNewsRepository.createPost(
        author: user,
        title: _title.text,
        body: _body.text,
        category: _selectedCategory.id,
        photoUrls: photoUrls,
        videoUrls: videoUrls,
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your post is live for neighbors.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _bodyHint =>
      _selectedCategory.bodyHint ?? 'What do you want neighbors to know?';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : user.neighborhoodKey.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Set your neighborhood in Profile before posting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawPartyColors.textSecondary),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Sharing with area: ${user.neighborhood ?? user.neighborhoodKey}',
                      style: TextStyle(
                        fontSize: 13,
                        color: PawPartyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Posts stay visible for about 30 days. Be kind — content can be reported.',
                      style: TextStyle(fontSize: 12, color: PawPartyColors.textHint),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryChips(),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                        hintText: 'Short headline',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _body,
                      minLines: 6,
                      maxLines: 16,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        hintText: _bodyHint,
                        alignLabelWithHint: true,
                        helperText: 'Optional if you add photos or a video',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),
                    const SizedBox(height: 12),
                    _buildVideoSection(),
                  ],
                ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: NewsCategory.all.map((cat) {
        final selected = _selectedCategory.id == cat.id;
        return ChoiceChip(
          avatar: Icon(cat.icon, size: 18),
          label: Text(cat.label),
          selected: selected,
          onSelected: (_) => setState(() => _selectedCategory = cat),
          selectedColor: PawPartyColors.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? PawPartyColors.primary : PawPartyColors.textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _pickedPhotos.isEmpty
                    ? 'Add photos'
                    : 'Add more (${_pickedPhotos.length}/$_maxPhotos)',
              ),
            ),
          ],
        ),
        if (_pickedPhotos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedPhotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              _pickedPhotos[i].path,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_pickedPhotos[i].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickVideo,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(
                _pickedVideos.isEmpty
                    ? 'Add video'
                    : 'Add more (${_pickedVideos.length}/$_maxVideos)',
              ),
            ),
          ],
        ),
        if (_pickedVideos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pickedVideos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, color: Colors.white70, size: 36),
                          const SizedBox(height: 4),
                          Text(
                            _pickedVideos[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeVideo(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
