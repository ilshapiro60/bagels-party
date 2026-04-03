import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../config/firebase_bootstrap.dart';

/// Uploads pet, profile, and story media to Firebase Storage when Firebase is initialized.
/// Falls back to the original [localPath] if Firebase is off or upload fails.
class FirebaseStorageService {
  FirebaseStorageService._();
  static final FirebaseStorageService instance = FirebaseStorageService._();

  bool get _ready =>
      isFirebaseInitialized && FirebaseAuth.instance.currentUser != null;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  /// Returns download URL, or [localPath] if upload skipped / failed.
  Future<String> uploadLocalPath({
    required String localPath,
    required String storageRelativePath,
  }) async {
    if (!_ready) return localPath;
    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
      return localPath;
    }
    try {
      final file = XFile(localPath);
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child(storageRelativePath);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentType(localPath)),
      );
      return await ref.getDownloadURL();
    } catch (e, st) {
      debugPrint('Storage upload failed ($storageRelativePath): $e');
      debugPrint('$st');
      return localPath;
    }
  }

  Future<String> uploadProfileAvatar(String localPath) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/$name',
    );
  }

  Future<String> uploadProfileGalleryImage(String localPath) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/gallery/$name',
    );
  }

  Future<String> uploadProfileGalleryVideo(String localPath) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/videos/$name',
    );
  }

  Future<String> uploadPetAvatar({
    required String localPath,
    required String petId,
  }) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'avatar_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/$name',
    );
  }

  Future<String> uploadPetGalleryPhoto({
    required String localPath,
    required String petId,
  }) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'img_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/gallery/$name',
    );
  }

  Future<String> uploadPetVideo({
    required String localPath,
    required String petId,
  }) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'vid_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/videos/$name',
    );
  }

  Future<String> uploadStoryMedia({
    required String localPath,
    required String storyId,
  }) async {
    if (!_ready) return localPath;
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'stories/$storyId/$uid/$name',
    );
  }
}
