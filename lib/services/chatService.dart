import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  /// Get the canonical ID for any user (converts to consistent format)
  Future<String> getCanonicalId(String userId) async {
    if (userId.startsWith('local_')) {
      return userId;
    }

    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final localId = data?['localId'];
        if (localId != null) {
          return 'local_$localId';
        }
      }
    } catch (e) {
      debugPrint('Error getting canonical ID for $userId: $e');
    }

    return userId;
  }

  Stream<QuerySnapshot> getConversations(String currentUserId) async* {
    final canonicalId = await getCanonicalId(currentUserId);
    debugPrint('🔍 Getting conversations for user: $canonicalId');

    yield* _db
        .collection('conversations')
        .where('participants', arrayContains: canonicalId)
        .snapshots(includeMetadataChanges: true)
        .handleError((error) {
      debugPrint('❌ Error getting conversations: $error');
      return Stream.error(error);
    });
  }

  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    final canonicalCurrentId = await getCanonicalId(currentUserId);
    final canonicalOtherId = await getCanonicalId(otherUserId);

    debugPrint('🔍 Creating/finding conversation between $canonicalCurrentId and $canonicalOtherId');

    final existingConversations = await _db
        .collection('conversations')
        .where('participants', arrayContains: canonicalCurrentId)
        .get();

    for (final doc in existingConversations.docs) {
      final participants = List<String>.from(doc['participants']);
      for (final participant in participants) {
        final participantCanonical = await getCanonicalId(participant);
        if (participantCanonical == canonicalOtherId) {
          debugPrint('✅ Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }
    }

    debugPrint('🆕 Creating new conversation');
    final participants = [canonicalCurrentId, canonicalOtherId];
    final participantNames = {
      canonicalCurrentId: currentUserName,
      canonicalOtherId: otherUserName,
    };

    final docRef = await _db.collection('conversations').add({
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadCounts': {
        canonicalCurrentId: 0,
        canonicalOtherId: 0,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Created conversation: ${docRef.id}');
    return docRef.id;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final canonicalSenderId = await getCanonicalId(senderId);
    debugPrint('📤 Sending message from $canonicalSenderId in conversation $conversationId');

    final batch = _db.batch();
    final convoRef = _db.collection('conversations').doc(conversationId);

    // Add message
    final msgRef = convoRef.collection('messages').doc();
    batch.set(msgRef, {
      'senderId': canonicalSenderId,
      'senderName': senderName,
      'text': text,
      'isRead': false,
      'readBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Get conversation data to update unread counts
    final convoDoc = await convoRef.get();
    final convoData = convoDoc.data() as Map<String, dynamic>?;
    final participants = List<String>.from(convoData?['participants'] ?? []);
    final unreadCounts = Map<String, int>.from(convoData?['unreadCounts'] ?? {});

    // Increment unread count for all participants except sender
    for (final participant in participants) {
      if (participant != canonicalSenderId) {
        unreadCounts[participant] = (unreadCounts[participant] ?? 0) + 1;
      }
    }

    // Update last message and unread counts
    batch.update(convoRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': canonicalSenderId,
      'unreadCounts': unreadCounts,
    });

    await batch.commit();
    debugPrint('✅ Message sent successfully');

    // Notify recipient
    try {
      String? recipientId;
      for (final participant in participants) {
        if (participant != canonicalSenderId) {
          recipientId = participant;
          break;
        }
      }

      if (recipientId != null && recipientId.isNotEmpty) {
        debugPrint('🔔 Creating notification for recipient: $recipientId');
        await _db.collection('notifications').add({
          'userId': recipientId,
          'fromUserId': canonicalSenderId,
          'fromName': senderName,
          'type': 'chat',
          'title': senderName,
          'message': '$senderName sent you a message: "${text.length > 60 ? '${text.substring(0, 60)}…' : text}"',
          'conversationId': conversationId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Chat notification failed: $e');
    }
  }

  Stream<QuerySnapshot> getMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final canonicalUserId = await getCanonicalId(userId);
      final convoRef = _db.collection('conversations').doc(conversationId);

      // Get all unread messages in this conversation
      final messages = await convoRef
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();

      // Mark each message as read
      for (final msgDoc in messages.docs) {
        final msgData = msgDoc.data();
        final readBy = List<String>.from(msgData['readBy'] ?? []);

        if (!readBy.contains(canonicalUserId)) {
          readBy.add(canonicalUserId);
          batch.update(msgDoc.reference, {
            'isRead': true,
            'readBy': readBy,
          });
        }
      }

      // Reset unread count for this user
      batch.update(convoRef, {
        'unreadCounts.$canonicalUserId': 0,
      });

      await batch.commit();
      debugPrint('✅ Marked messages as read for user $canonicalUserId in conversation $conversationId');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  Future<int> getUnreadCount(String conversationId, String userId) async {
    try {
      final canonicalUserId = await getCanonicalId(userId);
      final convoDoc = await _db.collection('conversations').doc(conversationId).get();
      final data = convoDoc.data() as Map<String, dynamic>?;
      final unreadCounts = Map<String, int>.from(data?['unreadCounts'] ?? {});
      return unreadCounts[canonicalUserId] ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    debugPrint('🗑️ Deleting conversation: $conversationId');

    final messagesRef = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages');

    final messages = await messagesRef.get();
    final batch = _db.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_db.collection('conversations').doc(conversationId));
    await batch.commit();

    debugPrint('✅ Conversation deleted');
  }
}