import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  /// Normalize user ID to consistent format for conversations
  String _normalizeParticipantId(String userId) {
    // If it's already local_X format, keep it
    if (userId.startsWith('local_')) {
      return userId;
    }

    // If it's a numeric string, convert to local_ format
    if (RegExp(r'^\d+$').hasMatch(userId)) {
      return 'local_$userId';
    }

    // Otherwise keep as is (Firebase UID)
    return userId;
  }

  /// Check if two user IDs represent the same person
  bool _isSamePerson(String idA, String idB) {
    if (idA == idB) return true;

    // Extract numeric IDs if present
    final aNum = idA.startsWith('local_') ? idA.replaceFirst('local_', '') : null;
    final bNum = idB.startsWith('local_') ? idB.replaceFirst('local_', '') : null;

    if (aNum != null && bNum != null) return aNum == bNum;

    return false;
  }

  Stream<QuerySnapshot> getConversations(String currentUserId) {
    print('🔍 Getting conversations for user: $currentUserId');

    return _db
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots(includeMetadataChanges: true)
        .handleError((error) {
      print('❌ Error getting conversations: $error');
      return Stream.error(error);
    });
  }

  Future<String> getOrCreateConversation({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    // Normalize both IDs
    final normalizedCurrentId = _normalizeParticipantId(currentUserId);
    final normalizedOtherId = _normalizeParticipantId(otherUserId);

    print('🔍 Creating/finding conversation between $normalizedCurrentId and $normalizedOtherId');

    // First, try to find existing conversation
    final existingConversations = await _db
        .collection('conversations')
        .where('participants', arrayContains: normalizedCurrentId)
        .get();

    for (final doc in existingConversations.docs) {
      final participants = List<String>.from(doc['participants']);

      // Check if other user is in participants
      for (final participant in participants) {
        if (_isSamePerson(participant, normalizedOtherId)) {
          print('✅ Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }
    }

    // Create new conversation
    print('🆕 Creating new conversation');
    final participants = [normalizedCurrentId, normalizedOtherId];
    final participantNames = {
      normalizedCurrentId: currentUserName,
      normalizedOtherId: otherUserName,
    };

    final docRef = await _db.collection('conversations').add({
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Created conversation: ${docRef.id}');
    return docRef.id;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    print('📤 Sending message from $senderId in conversation $conversationId');

    final batch = _db.batch();
    final convoRef = _db.collection('conversations').doc(conversationId);

    // Add message
    final msgRef = convoRef.collection('messages').doc();
    batch.set(msgRef, {
      'senderId': senderId,
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
    print('✅ Message sent successfully');

    // Notify recipient
    try {
      final convoDoc = await convoRef.get();
      final data = convoDoc.data() as Map<String, dynamic>?;
      final participants = List<String>.from(data?['participants'] ?? []);

      // Find recipient (the one who isn't the sender)
      String? recipientId;
      for (final participant in participants) {
        if (!_isSamePerson(participant, senderId)) {
          recipientId = participant;
          break;
        }
      }

      if (recipientId != null && recipientId.isNotEmpty) {
        print('🔔 Creating notification for recipient: $recipientId');
        await _db.collection('notifications').add({
          'userId': recipientId,
          'fromUserId': senderId,
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
      print('❌ Chat notification failed: $e');
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
    print('🗑️ Deleting conversation: $conversationId');

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

    print('✅ Conversation deleted');
  }
}