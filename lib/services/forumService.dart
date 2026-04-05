import 'package:cloud_firestore/cloud_firestore.dart';

class ForumService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _forums => _db.collection('forums');
  CollectionReference _messages(String forumId) =>
      _forums.doc(forumId).collection('messages');

  // ══════════════════════════════════════════════════════════════════════════
  // FORUMS — read
  // ══════════════════════════════════════════════════════════════════════════

  Stream<QuerySnapshot> getForums() => _forums.snapshots();

  Stream<QuerySnapshot> getMyForums(String userId) => _forums
      .where('members', arrayContains: userId)
      .snapshots();

  Stream<DocumentSnapshot> getForumStream(String forumId) =>
      _forums.doc(forumId).snapshots();

  // ══════════════════════════════════════════════════════════════════════════
  // FORUMS — write
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> joinForum(String forumId, String userId) async {
    await _forums.doc(forumId).update({
      'members':     FieldValue.arrayUnion([userId]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leaveForum(String forumId, String userId) async {
    await _forums.doc(forumId).update({
      'members':     FieldValue.arrayRemove([userId]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> deleteForum(String forumId) async {
    final msgs  = await _messages(forumId).get();
    final batch = _db.batch();
    for (final doc in msgs.docs) batch.delete(doc.reference);
    batch.delete(_forums.doc(forumId));
    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGES — read
  // ══════════════════════════════════════════════════════════════════════════

  Stream<QuerySnapshot> getMessages(String forumId) => _messages(forumId)
      .orderBy('createdAt', descending: false)
      .snapshots();

  Stream<QuerySnapshot> getPinnedMessages(String forumId) =>
      _messages(forumId)
          .where('isPinned', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .snapshots();

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGES — write
  // ══════════════════════════════════════════════════════════════════════════

  /// Post a message and notify all forum members.
  Future<void> postMessage({
    required String forumId,
    required String userId,
    required String userName,
    required String text,
  }) async {
    final batch  = _db.batch();
    final msgRef = _messages(forumId).doc();

    // Add message
    batch.set(msgRef, {
      'userId':    userId,
      'userName':  userName,
      'text':      text,
      'createdAt': FieldValue.serverTimestamp(),
      'likes':     [],
      'isPinned':  false,
    });

    // Update forum metadata
    batch.update(_forums.doc(forumId), {
      'lastActivity':  FieldValue.serverTimestamp(),
      'lastMessage':   text.length > 60 ? '${text.substring(0, 60)}…' : text,
      'lastMessageBy': userName,
      'postCount':     FieldValue.increment(1),
    });

    await batch.commit();

    // ── Notify all forum members except poster ──────────────────────────
    try {
      final forumDoc  = await _forums.doc(forumId).get();
      final forumData = forumDoc.data() as Map<String, dynamic>?;
      final title     = forumData?['title'] as String? ?? 'Forum';
      final members   = List<String>.from(forumData?['members'] ?? []);

      final notifBatch = _db.batch();
      for (final memberId in members) {
        if (memberId == userId) continue; // skip self
        final notifRef = _db.collection('notifications').doc();
        notifBatch.set(notifRef, {
          'userId':    memberId,
          'fromUserId': userId,
          'fromName':  userName,
          'type':      'forum',
          'title':     title,
          'message':   '$userName posted in "$title": "${text.length > 50 ? '${text.substring(0, 50)}…' : text}"',
          'forumId':   forumId,
          'isRead':    false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await notifBatch.commit();
    } catch (e) {
      // Notification failure should never block posting
    }
  }

  Future<void> deleteMessage(String forumId, String messageId) async {
    final batch = _db.batch();
    batch.delete(_messages(forumId).doc(messageId));
    batch.update(_forums.doc(forumId), {
      'postCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<void> toggleLike({
    required String forumId,
    required String messageId,
    required String userId,
    required bool   isLiked,
  }) async {
    await _messages(forumId).doc(messageId).update({
      'likes': isLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> togglePin({
    required String forumId,
    required String messageId,
    required bool   isPinned,
  }) async {
    await _messages(forumId).doc(messageId).update({
      'isPinned': !isPinned,
    });
  }

  // Legacy compatibility
  Stream<QuerySnapshot> getPosts(String forumId) => getMessages(forumId);
}