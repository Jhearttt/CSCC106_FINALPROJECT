// notification_service.dart (enhanced version)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for creating and managing Firestore notifications.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a single notification doc
  Future<void> _create({
    required String userId,
    required String type,
    required String fromName,
    required String message,
    String title = '',
    String? relatedId,
    String? fromUserId,
    String? avatarUrl,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'type': type,
        'fromName': fromName,
        'fromUserId': fromUserId,
        'avatarUrl': avatarUrl,
        'message': message,
        'title': title,
        'relatedId': relatedId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] Notification created for user: $userId');
    } catch (e) {
      debugPrint('[NotificationService] _create failed: $e');
    }
  }

  // CHAT: notify recipient of a new message
  Future<void> notifyNewChatMessage({
    required String recipientUserId,
    required String senderName,
    required String senderUserId,
    required String messagePreview,
    required String conversationId,
    String? senderAvatar,
  }) async {
    await _create(
      userId: recipientUserId,
      type: 'chat',
      fromName: senderName,
      fromUserId: senderUserId,
      avatarUrl: senderAvatar,
      message: messagePreview.length > 80
          ? '${messagePreview.substring(0, 80)}…'
          : messagePreview,
      title: 'New message',
      relatedId: conversationId,
    );
  }

  // FORUM: notify creator when someone joins their forum
  Future<void> notifyForumJoin({
    required String forumCreatorUserId,
    required String joinerName,
    required String joinerUserId,
    required String forumTitle,
    required String forumId,
    String? joinerAvatar,
  }) async {
    await _create(
      userId: forumCreatorUserId,
      type: 'forum_join',
      fromName: joinerName,
      fromUserId: joinerUserId,
      avatarUrl: joinerAvatar,
      message: '$joinerName joined your forum "$forumTitle"',
      title: forumTitle,
      relatedId: forumId,
    );
  }

  // FORUM: notify all members when someone posts in a forum
  Future<void> notifyForumPost({
    required String forumId,
    required String forumTitle,
    required String posterUserId,
    required String posterName,
    required String messagePreview,
    String? posterAvatar,
  }) async {
    try {
      final forumDoc = await _db.collection('forums').doc(forumId).get();
      if (!forumDoc.exists) return;

      final members = List<String>.from(forumDoc['members'] ?? []);
      
      // Use batched writes for better performance
      final batch = _db.batch();
      int batchCount = 0;

      for (final memberId in members) {
        if (memberId == posterUserId) continue;
        
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'userId': memberId,
          'type': 'forum_post',
          'fromName': posterName,
          'fromUserId': posterUserId,
          'avatarUrl': posterAvatar,
          'message': messagePreview.length > 80
              ? '${messagePreview.substring(0, 80)}…'
              : messagePreview,
          'title': forumTitle,
          'relatedId': forumId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        
        // Commit in batches of 500 (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          batchCount = 0;
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[NotificationService] notifyForumPost failed: $e');
    }
  }

  // COMMENT: notify post owner
  Future<void> notifyComment({
    required String postOwnerFirebaseId,
    required String commenterName,
    required String commenterUserId,
    required String postTitle,
    required String commentPreview,
    required int postId,
    String? commenterAvatar,
  }) async {
    if (postOwnerFirebaseId.isEmpty) return;
    await _create(
      userId: postOwnerFirebaseId,
      type: 'comment',
      fromName: commenterName,
      fromUserId: commenterUserId,
      avatarUrl: commenterAvatar,
      message: commentPreview.length > 80
          ? '${commentPreview.substring(0, 80)}…'
          : commentPreview,
      title: postTitle,
      relatedId: postId.toString(),
    );
  }

  // Get unread count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('[NotificationService] getUnreadCount failed: $e');
      return 0;
    }
  }

  // Real-time unread count stream for posts only (exclude chat)
  Stream<int> unreadPostsCountStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .where('type', whereIn: ['comment', 'reply', 'accepted'])
        .snapshots()
        .map((snap) => snap.size)
        .handleError((error) {
          debugPrint('[NotificationService] Posts stream error: $error');
          return 0;
        });
  }

  // Real-time unread count stream
  Stream<int> unreadCountStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size)
        .handleError((error) {
          debugPrint('[NotificationService] Stream error: $error');
          return 0;
        });
  }

  // Get real-time notifications stream
  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('__name__', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[NotificationService] markAsRead failed: $e');
    }
  }

  // Mark all as read
  Future<void> markAllRead(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationService] markAllRead failed: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('[NotificationService] deleteNotification failed: $e');
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationService] deleteAllNotifications failed: $e');
    }
  }
}