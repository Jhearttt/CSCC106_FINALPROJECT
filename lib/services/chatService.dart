import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  /// Get the canonical ID for any user (converts to consistent format)
  Future<String> getCanonicalId(String userId) async {
    // If already in local_ format, return as is
    if (userId.startsWith('local_')) {
      return userId;
    }

    // If it's a Firebase UID, check if there's a local account linked
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

    // Return original if no local mapping found
    return userId;
  }

  /// Normalize participant IDs for consistent storage
  Future<List<String>> normalizeParticipants(List<String> participants) async {
    List<String> normalized = [];
    for (final participant in participants) {
      normalized.add(await getCanonicalId(participant));
    }
    return normalized;
  }

  Stream<QuerySnapshot> getConversations(String currentUserId) async* {
    // First, get the canonical ID for the current user
    final canonicalId = await getCanonicalId(currentUserId);
    debugPrint('🔍 Getting conversations for user: $canonicalId (original: $currentUserId)');

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
    // Get canonical IDs for both users
    final canonicalCurrentId = await getCanonicalId(currentUserId);
    final canonicalOtherId = await getCanonicalId(otherUserId);

    debugPrint('🔍 Creating/finding conversation between:');
    debugPrint('   Current: $canonicalCurrentId (original: $currentUserId)');
    debugPrint('   Other: $canonicalOtherId (original: $otherUserId)');

    // First, try to find existing conversation using canonical IDs
    final existingConversations = await _db
        .collection('conversations')
        .where('participants', arrayContains: canonicalCurrentId)
        .get();

    for (final doc in existingConversations.docs) {
      final participants = List<String>.from(doc['participants']);
      debugPrint('   Checking conversation ${doc.id}: participants = $participants');

      // Check if other user is in participants (using canonical comparison)
      for (final participant in participants) {
        final participantCanonical = await getCanonicalId(participant);
        if (participantCanonical == canonicalOtherId) {
          debugPrint('✅ Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }
    }

    // Create new conversation with canonical IDs
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
    // Get canonical sender ID
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
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update last message
    batch.update(convoRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('✅ Message sent successfully');

    // Notify recipient
    try {
      final convoDoc = await convoRef.get();
      final data = convoDoc.data() as Map<String, dynamic>?;
      final participants = List<String>.from(data?['participants'] ?? []);

      // Find recipient (the one who isn't the sender)
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

  Future<void> deleteConversation(String conversationId) async {
    debugPrint('🗑️ Deleting conversation: $conversationId');

    // Also delete all messages in the conversation
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