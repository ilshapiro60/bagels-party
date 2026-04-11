import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../config/firebase_bootstrap.dart';
import 'storage_put_stub.dart'
    if (dart.library.io) 'storage_put_io.dart' as storage_put_impl;

/// Uploads pet, profile, and story media to Firebase Storage when Firebase is initialized.
/// Falls back to the original [localPath] if Firebase is off or upload fails.
class FirebaseStorageService {
  FirebaseStorageService._();
  static final FirebaseStorageService instance = FirebaseStorageService._();

  bool get _ready =>
      isFirebaseInitialized && FirebaseAuth.instance.currentUser != null;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Uses the app’s [storageBucket] so uploads target the same bucket as
  /// `google-services.json` / `firebase_options.dart` (avoids default-instance
  /// mismatches). On Android, [putFile] avoids some resumable-upload 404s seen
  /// with [putData] for the same paths.
  static FirebaseStorage _storageForApp() {
    final app = Firebase.app();
    final raw = app.options.storageBucket;
    if (raw != null && raw.isNotEmpty) {
      final gs = raw.startsWith('gs://') ? raw : 'gs://$raw';
      return FirebaseStorage.instanceFor(app: app, bucket: gs);
    }
    return FirebaseStorage.instance;
  }

  /// After [putFile]/[putData], the object may not be visible to read APIs yet.
  /// [getDownloadURL] (and sometimes [getMetadata]) can return `object-not-found`
  /// until the upload is fully finalized — see Firebase docs on upload completion
  /// vs byte progress. We wait for [getMetadata] first, then fetch the URL.
  static Future<String> _getDownloadUrlWithRetry(Reference ref) async {
    const delaysMs = [0, 400, 1000, 2500, 5000, 9000, 14000];
    FirebaseException? last;
    for (var i = 0; i < delaysMs.length; i++) {
      if (delaysMs[i] > 0) {
        await Future<void>.delayed(Duration(milliseconds: delaysMs[i]));
      }
      try {
        await ref.getMetadata();
        return await ref.getDownloadURL();
      } on FirebaseException catch (e) {
        last = e;
        final canRetry =
            e.code == 'object-not-found' && i != delaysMs.length - 1;
        if (!canRetry) {
          rethrow;
        }
      }
    }
    throw last ?? StateError('getDownloadURL failed');
  }

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
  ///
  /// When [allowLocalFallback] is false (use for data saved to Firestore), failures
  /// propagate so the UI can show [FirebaseException.code] instead of a generic
  /// "check your connection" message after a silent local-path fallback.
  Future<String> uploadLocalPath({
    required String localPath,
    required String storageRelativePath,
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
      return localPath;
    }
    try {
      final storage = _storageForApp();
      final ref = storage.ref().child(storageRelativePath);
      final meta = SettableMetadata(contentType: _contentType(localPath));
      final TaskSnapshot snapshot;
      if (kIsWeb) {
        final file = XFile(localPath);
        final bytes = await file.readAsBytes();
        snapshot = await ref.putData(bytes, meta);
      } else {
        snapshot = await storage_put_impl.storagePutLocalFile(ref, localPath, meta);
      }
      if (snapshot.state != TaskState.success) {
        throw StateError(
          'Upload finished in an unexpected state: ${snapshot.state}',
        );
      }
      // Give the native upload pipeline a moment to finalize the object before
      // read APIs run (avoids sporadic object-not-found right after success).
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return _getDownloadUrlWithRetry(snapshot.ref);
    } catch (e, st) {
      debugPrint('Storage upload failed ($storageRelativePath): $e');
      if (e is FirebaseException) {
        debugPrint(
          'Storage hint (${e.code}): confirm Cloud Storage is enabled for this '
          'project, deploy storage.rules, and in Firebase Console → App Check '
          'either turn off Storage enforcement for development or add a debug token.',
        );
      }
      debugPrint('$st');
      if (!allowLocalFallback) {
        rethrow;
      }
      return localPath;
    }
  }

  Future<String> uploadProfileAvatar(
    String localPath, {
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadProfileGalleryImage(
    String localPath, {
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/gallery/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadProfileGalleryVideo(
    String localPath, {
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/profile/videos/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadPetAvatar({
    required String localPath,
    required String petId,
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'avatar_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadPetGalleryPhoto({
    required String localPath,
    required String petId,
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'img_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/gallery/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadPassportMedia({
    required String localPath,
    required String entryId,
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'pass_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/passport/$entryId/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  Future<String> uploadPetVideo({
    required String localPath,
    required String petId,
    bool allowLocalFallback = true,
  }) async {
    if (!_ready) {
      if (!allowLocalFallback) {
        throw StateError('Sign in to upload media.');
      }
      return localPath;
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = 'vid_${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'users/$uid/pets/$petId/videos/$name',
      allowLocalFallback: allowLocalFallback,
    );
  }

  /// Deletes a file in Firebase Storage when [url] is an `https` download URL
  /// or `gs://` reference. Ignores local paths and failures (logs only).
  Future<void> deleteRemoteObjectIfPossible(String url) async {
    if (!_ready) return;
    final u = url.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http://') &&
        !u.startsWith('https://') &&
        !u.startsWith('gs://')) {
      return;
    }
    try {
      final ref = FirebaseStorage.instance.refFromURL(u);
      await ref.delete();
    } catch (e, st) {
      debugPrint('Storage delete skipped ($u): $e');
      debugPrint('$st');
    }
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

  Future<String> uploadAlbumMedia({
    required String localPath,
    required String meetupId,
  }) async {
    if (!_ready) {
      throw StateError('Sign in to upload media.');
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'partyAlbums/$meetupId/$uid/$name',
    );
  }

  Future<String> uploadNewsPhoto({
    required String localPath,
    required String postId,
  }) async {
    if (!_ready) {
      throw StateError('Sign in to upload media.');
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'news/$postId/$uid/$name',
      allowLocalFallback: false,
    );
  }

  Future<String> uploadNewsVideo({
    required String localPath,
    required String postId,
  }) async {
    if (!_ready) {
      throw StateError('Sign in to upload media.');
    }
    final uid = _uid!;
    final ext = p.extension(localPath);
    final name = '${const Uuid().v4()}$ext';
    return uploadLocalPath(
      localPath: localPath,
      storageRelativePath: 'news/$postId/$uid/videos/$name',
      allowLocalFallback: false,
    );
  }
}
