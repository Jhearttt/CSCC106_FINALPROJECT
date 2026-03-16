import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/connectivityService.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:sqflite/sqflite.dart';

// ─── Firestore Collection Names ───────────────────────────────────────────────
const _kPosts    = 'posts';
const _kComments = 'comments';

/// Singleton that keeps SQLite ↔ Firestore in sync.
///
/// WRITE FLOW:
///   Online  → SQLite first, then Firestore immediately.
///   Offline → SQLite only (synced = 0). Queued for retry on reconnect.
///
/// READ FLOW:
///   Feed refresh → pull Firestore docs → upsert into SQLite
///   → DatabaseHelper queries return the merged result.
///
/// SETUP — call once in main.dart after Firebase.initializeApp():
///   await SyncService.instance.init();
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper    _db        = DatabaseHelper();

  StreamSubscription? _connectivitySub;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await ConnectivityService.instance.init();

    // Auto-flush when connectivity is restored
    _connectivitySub =
        ConnectivityService.instance.onStatusChange.listen((online) async {
          if (online) {
            developer.log('Back online — flushing offline queue', name: 'SyncService');
            await flushOfflineQueue();
          }
        });

    // Flush anything left from a previous offline session
    if (ConnectivityService.instance.isOnline) {
      await flushOfflineQueue();
    }
  }

  void dispose() => _connectivitySub?.cancel();

  // ══════════════════════════════════════════════════════════════════════════
  //  IMAGE — Base64 encode (replaces Firebase Storage)
  // ══════════════════════════════════════════════════════════════════════════

  /// Compress a local image file and encode it to a base64 data URI string.
  /// The result can be stored directly in Firestore and SQLite as text.
  ///
  /// Compression targets ~200KB max to stay well under Firestore's 1MB limit.
  /// Returns null if the file doesn't exist or encoding fails.
  Future<String?> encodeImageToBase64(String localPath) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      // Compress: resize to max 600px wide, quality 60
      final compressed = await FlutterImageCompress.compressWithFile(
        localPath,
        minWidth:  600,
        minHeight: 600,
        quality:   60,
        format:    CompressFormat.jpeg,
      );

      if (compressed == null) {
        // Fallback: read raw and encode without compression
        final bytes = await file.readAsBytes();
        final b64   = base64Encode(bytes);
        developer.log('Image encoded (uncompressed): ${bytes.length} bytes',
            name: 'SyncService');
        return 'data:image/jpeg;base64,$b64';
      }

      // Check size — Firestore doc limit is 1MB, warn if over 700KB
      if (compressed.length > 700000) {
        developer.log('Warning: encoded image is ${compressed.length} bytes '
            '— consider a smaller photo', name: 'SyncService');
      }

      final b64 = base64Encode(compressed);
      developer.log('Image encoded: ${compressed.length} bytes → '
          '${b64.length} base64 chars', name: 'SyncService');
      return 'data:image/jpeg;base64,$b64';
    } catch (e) {
      developer.log('Image encode failed: $e', name: 'SyncService');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POSTS — write
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a new post.
  /// Pass [imageLocalPath] to compress + base64-encode the image inline.
  /// Returns the local SQLite row id.
  Future<int> savePost({
    required int    userId,
    required String userFullName,
    required String userUserName,
    required String title,
    required String description,
    required String postType,
    required String category,
    String  status         = 'Open',
    String  urgencyLevel   = 'Low',
    String? imageLocalPath,
  }) async {
    // Encode image locally — no network needed
    String? imageUrl;
    if (imageLocalPath != null) {
      imageUrl = await encodeImageToBase64(imageLocalPath);
    }
    final localId = await _db.insertPost(
      userId: userId, title: title, description: description,
      postType: postType, category: category, status: status,
      urgencyLevel: urgencyLevel, imageUrl: imageUrl,
    );
    if (localId <= 0) return localId;
    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore.collection(_kPosts).doc(localId.toString()).set({
          'localId': localId, 'userId': userId,
          'userFullName': userFullName, 'userUserName': userUserName,
          'title': title, 'description': description,
          'postType': postType, 'category': category,
          'status': status, 'urgencyLevel': urgencyLevel,
          'imageUrl': imageUrl, 'isBoosted': 0,
          'datePosted': FieldValue.serverTimestamp(),
        });
        await _db.markPostSynced(localId);
        developer.log('Post $localId saved to Firestore', name: 'SyncService');
      } catch (e) {
        developer.log('Firestore write failed: $e', name: 'SyncService');
      }
    }
    return localId;
  }

  Future<int> updatePost({
    required int    postId,
    required int    userId,
    required String title,
    required String description,
    required String postType,
    required String category,
    required String status,
    String  urgencyLevel     = 'Low',
    String? imageLocalPath,
    String? existingImageUrl,  // already-encoded base64 or null
  }) async {
    // Re-encode only if a NEW local path was picked
    String? imageUrl = existingImageUrl;
    if (imageLocalPath != null) {
      imageUrl = await encodeImageToBase64(imageLocalPath);
    }
    final result = await _db.updatePost(
      postId: postId, title: title, description: description,
      postType: postType, category: category, status: status,
      urgencyLevel: urgencyLevel, imageUrl: imageUrl,
    );
    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore.collection(_kPosts).doc(postId.toString()).update({
          'title': title, 'description': description,
          'postType': postType, 'category': category,
          'status': status, 'urgencyLevel': urgencyLevel,
          'imageUrl': imageUrl, 'updatedAt': FieldValue.serverTimestamp(),
        });
        await _db.markPostSynced(postId);
      } catch (e) {
        developer.log('Firestore update failed: $e', name: 'SyncService');
      }
    }
    return result;
  }

  /// Toggle post status Open ↔ Resolved.
  Future<int> updatePostStatus(int postId, String status) async {
    final result = await _db.updatePostStatus(postId, status);

    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore.collection(_kPosts).doc(postId.toString()).update({
          'status':    status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _db.markPostSynced(postId);
      } catch (e) {
        developer.log('Firestore status update failed: $e', name: 'SyncService');
      }
    }
    return result;
  }

  /// Delete a post (and its Firestore comments).
  Future<int> deletePost(int postId) async {
    final result = await _db.deletePost(postId);

    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore.collection(_kPosts).doc(postId.toString()).delete();
        final batch = _firestore.batch();
        final comments = await _firestore
            .collection(_kComments)
            .where('postId', isEqualTo: postId)
            .get();
        for (final doc in comments.docs) batch.delete(doc.reference);
        await batch.commit();
      } catch (e) {
        developer.log('Firestore delete failed: $e', name: 'SyncService');
      }
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMMENTS — write
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a new comment or reply. Call this instead of DatabaseHelper.insertComment().
  /// Fires a notification to the post owner (and parent commenter if it's a reply).
  Future<int> saveComment({
    required int    postId,
    required int    userId,
    required String userFullName,
    required String comment,
    int?            parentCommentId,
  }) async {
    final localId = await _db.insertComment(
      postId:          postId,
      userId:          userId,
      comment:         comment,
      parentCommentId: parentCommentId,
    );
    if (localId <= 0) return localId;

    // ── Notifications ───────────────────────────────────────────────────────
    // Get the post to find its owner and title
    final posts = await _db.getAllPosts();
    final post  = posts.firstWhere((p) => p['id'] == postId, orElse: () => {});
    if (post.isNotEmpty) {
      final postOwnerId = post['userId'] as int?;
      final postTitle   = post['title']  as String? ?? 'a post';

      if (parentCommentId != null) {
        // It's a REPLY — notify the parent comment's author (if different from replier)
        final allComments = await _db.getCommentsByPost(postId);
        // getCommentsByPost returns threaded, flatten to find parent
        Map<String, dynamic>? parentComment;
        for (final c in allComments) {
          if (c['id'] == parentCommentId) { parentComment = c; break; }
          for (final r in (c['replies'] as List)) {
            if (r['id'] == parentCommentId) { parentComment = r; break; }
          }
          if (parentComment != null) break;
        }
        final parentAuthorId = parentComment?['userId'] as int?;
        if (parentAuthorId != null && parentAuthorId != userId) {
          await _db.insertNotification(
            userId:       parentAuthorId,
            fromUserId:   userId,
            fromUserName: userFullName,
            postId:       postId,
            postTitle:    postTitle,
            commentId:    localId,
            type:         'reply',
            message:      '$userFullName replied to your comment: "$comment"',
          );
        }
        // Also notify the post owner if they're different from the parent author
        if (postOwnerId != null && postOwnerId != userId &&
            postOwnerId != parentAuthorId) {
          await _db.insertNotification(
            userId:       postOwnerId,
            fromUserId:   userId,
            fromUserName: userFullName,
            postId:       postId,
            postTitle:    postTitle,
            commentId:    localId,
            type:         'reply',
            message:      '$userFullName also replied on your post: "$comment"',
          );
        }
      } else {
        // It's a top-level COMMENT — notify the post owner
        if (postOwnerId != null && postOwnerId != userId) {
          await _db.insertNotification(
            userId:       postOwnerId,
            fromUserId:   userId,
            fromUserName: userFullName,
            postId:       postId,
            postTitle:    postTitle,
            commentId:    localId,
            type:         'comment',
            message:      '$userFullName commented on your post: "$comment"',
          );
        }
      }
    }

    // ── Firestore sync ──────────────────────────────────────────────────────
    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore.collection(_kComments).doc(localId.toString()).set({
          'localId':          localId,
          'postId':           postId,
          'userId':           userId,
          'userFullName':     userFullName,
          'comment':          comment,
          'parentCommentId':  parentCommentId,
          'dateCommented':    FieldValue.serverTimestamp(),
        });
        await _db.markCommentSynced(localId);
        developer.log('Comment $localId saved to Firestore', name: 'SyncService');
      } catch (e) {
        developer.log('Firestore comment write failed: $e', name: 'SyncService');
      }
    }
    return localId;
  }

  /// Delete a comment from both stores.
  Future<int> deleteComment(int commentId) async {
    final result = await _db.deleteComment(commentId);

    if (ConnectivityService.instance.isOnline) {
      try {
        await _firestore
            .collection(_kComments)
            .doc(commentId.toString())
            .delete();
      } catch (e) {
        developer.log('Firestore comment delete failed: $e', name: 'SyncService');
      }
    }
    return result;
  }

  /// Accept a comment as the solution.
  /// Syncs isAccepted flag + post Resolved status to Firestore.
  /// Returns true on success, false if a rule blocked it.
  Future<bool> acceptSolution({
    required int    commentId,
    required int    postId,
    required int    helperId,
    required int    postOwnerId,
    required String category,
  }) async {
    final success = await _db.acceptSolution(
      commentId:   commentId,
      postId:      postId,
      helperId:    helperId,
      postOwnerId: postOwnerId,
      category:    category,
    );
    if (!success) return false;

    if (ConnectivityService.instance.isOnline) {
      try {
        // Mark comment accepted in Firestore
        await _firestore.collection(_kComments)
            .doc(commentId.toString())
            .update({'isAccepted': 1});

        // Resolve post in Firestore
        await _firestore.collection(_kPosts)
            .doc(postId.toString())
            .update({
          'status':     'Resolved',
          'resolvedBy': helperId,
          'resolvedAt': DateTime.now().toIso8601String(),
          'updatedAt':  FieldValue.serverTimestamp(),
        });
        await _db.markPostSynced(postId);
      } catch (e) {
        developer.log('Firestore acceptSolution failed: $e', name: 'SyncService');
      }
    }
    return true;
  }
  // ══════════════════════════════════════════════════════════════════════════

  /// Push all unsynced local rows to Firestore.
  /// Runs automatically on reconnect and at startup.
  Future<void> flushOfflineQueue() async {
    if (!ConnectivityService.instance.isOnline) return;
    await _flushPosts();
    await _flushComments();
  }

  Future<void> _flushPosts() async {
    final rows = await _db.getUnsyncedPosts();
    if (rows.isEmpty) return;
    developer.log('Flushing ${rows.length} post(s)', name: 'SyncService');

    for (final post in rows) {
      try {
        final ref = _firestore.collection(_kPosts).doc(post['id'].toString());
        final exists = (await ref.get()).exists;
        if (exists) {
          await ref.update({
            'title':       post['title'],
            'description': post['description'],
            'postType':    post['postType'],
            'category':    post['category'],
            'status':      post['status'],
            'updatedAt':   FieldValue.serverTimestamp(),
          });
        } else {
          await ref.set({
            'localId':     post['id'],
            'userId':      post['userId'],
            'title':       post['title'],
            'description': post['description'],
            'postType':    post['postType'],
            'category':    post['category'],
            'status':      post['status'],
            'datePosted':  FieldValue.serverTimestamp(),
          });
        }
        await _db.markPostSynced(post['id'] as int);
      } catch (e) {
        developer.log('Flush failed for post ${post['id']}: $e',
            name: 'SyncService');
      }
    }
  }

  Future<void> _flushComments() async {
    final rows = await _db.getUnsyncedComments();
    if (rows.isEmpty) return;
    developer.log('Flushing ${rows.length} comment(s)', name: 'SyncService');

    for (final comment in rows) {
      try {
        final ref =
        _firestore.collection(_kComments).doc(comment['id'].toString());
        final exists = (await ref.get()).exists;
        if (exists) {
          await ref.update({
            'comment':   comment['comment'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await ref.set({
            'localId':       comment['id'],
            'postId':        comment['postId'],
            'userId':        comment['userId'],
            'comment':       comment['comment'],
            'dateCommented': FieldValue.serverTimestamp(),
          });
        }
        await _db.markCommentSynced(comment['id'] as int);
      } catch (e) {
        developer.log('Flush failed for comment ${comment['id']}: $e',
            name: 'SyncService');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PULL FIRESTORE → LOCAL SQLITE
  // ══════════════════════════════════════════════════════════════════════════

  /// Pull all posts from Firestore → upsert into SQLite.
  /// Call on community feed refresh so users see posts from all devices.
  Future<void> pullPostsFromFirestore() async {
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final snapshot = await _firestore
          .collection(_kPosts)
          .orderBy('datePosted', descending: true)
          .get();
      for (final doc in snapshot.docs) {
        await _upsertPost(doc.data());
      }
      developer.log('Pulled ${snapshot.docs.length} post(s)', name: 'SyncService');
    } catch (e) {
      developer.log('Pull failed: $e', name: 'SyncService');
    }
  }

  /// Pull comments for a post from Firestore → upsert into SQLite.
  /// Call when opening the CommentsModal.
  Future<void> pullCommentsFromFirestore(int postId) async {
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final snapshot = await _firestore
          .collection(_kComments)
          .where('postId', isEqualTo: postId)
          .orderBy('dateCommented', descending: false)
          .get();
      for (final doc in snapshot.docs) {
        await _upsertComment(doc.data());
      }
    } catch (e) {
      developer.log('Comment pull failed for post $postId: $e',
          name: 'SyncService');
    }
  }

  // ── Private upsert helpers ────────────────────────────────────────────────

  Future<void> _upsertPost(Map<String, dynamic> data) async {
    final localId = data['localId'] as int?;
    if (localId == null) return;

    final userId   = (data['userId']       as num?)?.toInt() ?? 0;
    final fullName = data['userFullName']  as String? ?? 'Unknown';
    final userName = data['userUserName']  as String? ?? 'user_$userId';

    await _ensureUser(userId: userId, fullName: fullName, userName: userName);

    final db = await _db.getDatabase();
    final exists =
        (await db.query('posts', where: 'id = ?', whereArgs: [localId])).isNotEmpty;

    final row = {
      'id':          localId,
      'userId':      userId,
      'title':       data['title']       ?? '',
      'description': data['description'] ?? '',
      'postType':    data['postType']    ?? 'Help Request',
      'category':    data['category']   ?? 'Others',
      'status':      data['status']     ?? 'Open',
      'synced':      1,
      'datePosted':  (data['datePosted'] as Timestamp?)
          ?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
    };

    if (exists) {
      await db.update('posts', row, where: 'id = ?', whereArgs: [localId]);
    } else {
      await db.insert('posts', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _upsertComment(Map<String, dynamic> data) async {
    final localId = data['localId'] as int?;
    if (localId == null) return;

    final userId   = (data['userId']      as num?)?.toInt() ?? 0;
    final fullName = data['userFullName'] as String? ?? 'Unknown';

    await _ensureUser(userId: userId, fullName: fullName, userName: 'user_$userId');

    final db = await _db.getDatabase();
    final exists = (await db.query('comments',
        where: 'id = ?', whereArgs: [localId]))
        .isNotEmpty;

    final row = {
      'id':            localId,
      'postId':        (data['postId'] as num?)?.toInt() ?? 0,
      'userId':        userId,
      'comment':       data['comment'] ?? '',
      'synced':        1,
      'dateCommented': (data['dateCommented'] as Timestamp?)
          ?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
    };

    if (exists) {
      await db.update('comments', row, where: 'id = ?', whereArgs: [localId]);
    } else {
      await db.insert('comments', row,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Create a stub user row locally for posts/comments from other devices.
  Future<void> _ensureUser({
    required int    userId,
    required String fullName,
    required String userName,
  }) async {
    final db = await _db.getDatabase();
    final exists = (await db.query('users',
        where: 'id = ?', whereArgs: [userId]))
        .isNotEmpty;
    if (!exists) {
      await db.insert('users', {
        'id':       userId,
        'fullName': fullName,
        'userName': userName,
        'password': '',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}