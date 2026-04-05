import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:final_project/services/chatService.dart';
import 'chatRoomScreen.dart';
import 'package:final_project/backend/databaseHelper.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk    = Color(0xFF1E1B4B);
const _kBg     = Color(0xFFF8FAFC);

// ─────────────────────────────────────────────────────────────────────────────
// Avatar widget
// ─────────────────────────────────────────────────────────────────────────────
class ConvoAvatar extends StatefulWidget {
  final String otherPersonId;
  final String otherPersonName;
  final double radius;

  const ConvoAvatar({
    super.key,
    required this.otherPersonId,
    required this.otherPersonName,
    this.radius = 26,
  });

  @override
  State<ConvoAvatar> createState() => _ConvoAvatarState();
}

class _ConvoAvatarState extends State<ConvoAvatar> {
  String? _photoUrl;
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherPersonId)
          .get();

      // Fallback: try local_ prefix
      if (!doc.exists) {
        final altId = widget.otherPersonId.startsWith('local_')
            ? widget.otherPersonId
            : 'local_${widget.otherPersonId}';
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(altId)
            .get();
      }

      if (doc.exists) {
        final data     = doc.data()!;
        final photoUrl = data['photoUrl'] as String?;
        final localId  = data['localId']  as int?;

        String? base64;
        if (localId != null) {
          final localUser = await DatabaseHelper().getUserById(localId);
          final raw = localUser?['profilePic'];
          if (raw is String && raw.isNotEmpty) base64 = raw;
        }

        if (mounted) {
          setState(() {
            _photoUrl    = (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null;
            _photoBase64 = base64;
          });
        }
      }
    } catch (e) {
      debugPrint('ConvoAvatar load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.otherPersonName.isNotEmpty
        ? widget.otherPersonName[0].toUpperCase()
        : '?';

    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        return CircleAvatar(
            radius: widget.radius,
            backgroundImage: MemoryImage(base64Decode(_photoBase64!)));
      } catch (_) {}
    }

    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: NetworkImage(_photoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: _kAccent.withOpacity(0.12),
      child: Text(
        initials,
        style: TextStyle(
            color: _kAccent,
            fontWeight: FontWeight.bold,
            fontSize: widget.radius * 0.6),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ChatListScreen
// ─────────────────────────────────────────────────────────────────────────────
class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService      = ChatService();
  final _searchController = TextEditingController();
  String _searchQuery     = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Other participant name ─────────────────────────────────────────────────
  String _getOtherPersonName(Map<String, dynamic> data) {
    final names = Map<String, String>.from(data['participantNames'] ?? {});
    names.remove(widget.currentUserId);
    return names.values.firstOrNull ?? 'Unknown';
  }

  // ── Other participant ID ───────────────────────────────────────────────────
  String _getOtherPersonId(Map<String, dynamic> data) {
    final participants = List<String>.from(data['participants'] ?? []);
    participants.remove(widget.currentUserId);
    return participants.firstOrNull ?? '';
  }

  // ── Format timestamp ───────────────────────────────────────────────────────
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt   = timestamp.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours   < 24) return '${diff.inHours}h';
    if (diff.inDays    <  7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildSearchBar(),
      Expanded(child: _buildConversationList()),
    ]);
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close_rounded,
                color: Colors.grey, size: 18),
          )
              : null,
          filled: true,
          fillColor: _kBg,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Conversation list ──────────────────────────────────────────────────────
  Widget _buildConversationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getConversations(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var docs = snapshot.data!.docs;

        // ── KEY FIX: only show rooms with actual messages ──────────────────
        docs = docs.where((doc) {
          final data        = doc.data() as Map<String, dynamic>;
          final lastMessage = (data['lastMessage'] ?? '').toString().trim();
          return lastMessage.isNotEmpty;
        }).toList();

        // Sort by lastMessageAt descending
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          // Support both field names for compatibility
          final aTime = (aData['lastMessageAt'] ?? aData['lastMessageTime']) as Timestamp?;
          final bTime = (bData['lastMessageAt'] ?? bData['lastMessageTime']) as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        // Search filter
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data    = doc.data() as Map<String, dynamic>;
            final name    = _getOtherPersonName(data).toLowerCase();
            final lastMsg = (data['lastMessage'] ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                lastMsg.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, indent: 80, color: Colors.grey.shade100),
          itemBuilder: (context, i) {
            final data        = docs[i].data() as Map<String, dynamic>;
            final convoId     = docs[i].id;
            final otherName   = _getOtherPersonName(data);
            final otherUserId = _getOtherPersonId(data);
            final lastMessage = data['lastMessage'] ?? '';

            // Support both timestamp field names
            final lastTime =
            (data['lastMessageAt'] ?? data['lastMessageTime']) as Timestamp?;

            return _ConversationTile(
              key:             ValueKey(convoId),
              conversationId:  convoId,
              otherPersonName: otherName,
              otherPersonId:   otherUserId,
              lastMessage:     lastMessage,
              timeLabel:       _formatTime(lastTime),
              currentUserId:   widget.currentUserId,
              currentUserName: widget.currentUserName,
              onDelete:        () => _confirmDelete(convoId),
            );
          },
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 36, color: _kAccent),
        ),
        const SizedBox(height: 16),
        const Text('No messages yet',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
        const SizedBox(height: 6),
        const Text('Tap the pencil icon to start a conversation',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }

  // ── Delete confirmation ────────────────────────────────────────────────────
  void _confirmDelete(String conversationId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete conversation?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('This will remove the conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ChatService().deleteConversation(conversationId);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation Tile
// ─────────────────────────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final String       conversationId;
  final String       otherPersonName;
  final String       otherPersonId;
  final String       lastMessage;
  final String       timeLabel;
  final String       currentUserId;
  final String       currentUserName;
  final VoidCallback onDelete;

  const _ConversationTile({
    super.key,
    required this.conversationId,
    required this.otherPersonName,
    required this.otherPersonId,
    required this.lastMessage,
    required this.timeLabel,
    required this.currentUserId,
    required this.currentUserName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(conversationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade50,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.red, size: 24),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: ConvoAvatar(
          otherPersonId:   otherPersonId,
          otherPersonName: otherPersonName,
        ),
        title: Row(children: [
          Expanded(
            child: Text(otherPersonName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15, color: _kInk),
                overflow: TextOverflow.ellipsis),
          ),
          Text(timeLabel,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            lastMessage.isEmpty ? 'No messages yet' : lastMessage,
            style: TextStyle(
                fontSize: 13,
                color: lastMessage.isEmpty
                    ? Colors.grey.shade400
                    : Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId:  conversationId,
              currentUserId:   currentUserId,
              currentUserName: currentUserName,
              otherPersonName: otherPersonName,
              otherPersonId:   otherPersonId,
            ),
          ),
        ),
      ),
    );
  }
}