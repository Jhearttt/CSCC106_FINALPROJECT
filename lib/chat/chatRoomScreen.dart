import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/chatService.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk = Color(0xFF1E1B4B);
const _kBg = Color(0xFFF8FAFC);

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String currentUserName;
  final String otherPersonName;
  final String otherPersonId;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherPersonName,
    required this.otherPersonId,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  String _myCanonicalId = '';
  bool _sessionReady = false;

  bool _sending = false;
  bool _hasText = false;

  String? _otherPhotoUrl;
  String? _otherPhotoBase64;
  int? _otherLocalId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
            () => setState(() => _hasText = _controller.text.trim().isNotEmpty));
    _resolveSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveSession() async {
    String canonicalId = widget.currentUserId;

    debugPrint('🔍 Resolving session for user: ${widget.currentUserId}');

    if (widget.currentUserId.startsWith('local_')) {
      canonicalId = widget.currentUserId;
      debugPrint('✅ Already canonical format: $canonicalId');
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final localId = data['localId'];
          if (localId != null) {
            canonicalId = 'local_$localId';
            debugPrint('✅ Found local mapping: $canonicalId');
          } else {
            debugPrint('⚠️ No localId found for Google user, using UID: $canonicalId');
          }
        } else {
          debugPrint('⚠️ No user document found for UID: ${widget.currentUserId}');
        }
      } catch (e) {
        debugPrint('❌ Error resolving session: $e');
      }
    }

    if (mounted) {
      setState(() {
        _myCanonicalId = canonicalId;
        _sessionReady = true;
      });
      debugPrint('✅ Session ready: $_myCanonicalId');
    }

    _loadOtherUserProfile();
  }

  Future<void> _loadOtherUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherPersonId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final photoUrl = data['photoUrl'] as String?;
        final localId = data['localId'] as int?;

        String? urlPic = (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null;
        String? base64pic;

        if (localId != null) {
          final localUser = await DatabaseHelper().getUserById(localId);
          final raw = localUser?['profilePic'];
          if (raw is String && raw.isNotEmpty) {
            if (raw.startsWith('http')) {
              urlPic = raw;
            } else {
              base64pic = raw;
            }
          }
        }

        if (mounted) {
          setState(() {
            _otherPhotoUrl = urlPic;
            _otherPhotoBase64 = base64pic;
            _otherLocalId = localId;
          });
        }
        return;
      }

      final altId = widget.otherPersonId.startsWith('local_')
          ? widget.otherPersonId
          : 'local_${widget.otherPersonId}';

      if (altId != widget.otherPersonId) {
        final altDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(altId)
            .get();
        if (altDoc.exists) {
          final data = altDoc.data()!;
          final localId = data['localId'] as int?;
          if (localId != null) {
            final localUser = await DatabaseHelper().getUserById(localId);
            final raw = localUser?['profilePic'];
            if (raw is String && raw.isNotEmpty && mounted) {
              setState(() {
                _otherPhotoBase64 = raw.startsWith('http') ? null : raw;
                _otherPhotoUrl = raw.startsWith('http') ? raw : null;
                _otherLocalId = localId;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load other user profile: $e');
    }
  }

  bool _isMe(String senderId) {
    if (_myCanonicalId.isEmpty) return false;
    if (senderId == _myCanonicalId) return true;

    final sNum = senderId.startsWith('local_')
        ? senderId.replaceFirst('local_', '')
        : null;
    final mNum = _myCanonicalId.startsWith('local_')
        ? _myCanonicalId.replaceFirst('local_', '')
        : null;
    if (sNum != null && mNum != null) return sNum == mNum;
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || !_sessionReady) return;
    setState(() => _sending = true);
    _controller.clear();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: _myCanonicalId,
        senderName: widget.currentUserName,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (diff.inHours < 24) return '$h:$m';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool _showDateSeparator(List<DocumentSnapshot> docs, int index) {
    if (index == 0) return true;
    final curr = (docs[index].data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    final prev = (docs[index - 1].data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    if (curr == null || prev == null) return false;
    final a = curr.toDate(), b = prev.toDate();
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }

  String _formatDateLabel(Timestamp ts) {
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _openOtherProfile() {
    if (_otherLocalId == null) {
      _showProfileSheet();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          localUserId: _otherLocalId,
          isOwnProfile: false,
          embeddedMode: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _kInk,
      titleSpacing: 0,
      title: GestureDetector(
        onTap: _openOtherProfile,
        child: Row(
          children: [
            _UserAvatar(
              name: widget.otherPersonName,
              photoUrl: _otherPhotoUrl,
              photoBase64: _otherPhotoBase64,
              radius: 20,
              fontSize: 14,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherPersonName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _kInk),
                ),
                const Text(
                  'tap to view profile',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.call_rounded), onPressed: () {}),
        IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _showOptionsSheet),
      ],
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(widget.conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyChat();
        }
        final docs = snapshot.data!.docs;
        _scrollToBottom();
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final senderId = data['senderId'] as String? ?? '';
            final isMe = _isMe(senderId);
            final timestamp = data['createdAt'] as Timestamp?;
            final showSeparator = _showDateSeparator(docs, i);
            final isLastInGroup = i == docs.length - 1 ||
                (docs[i + 1].data() as Map<String, dynamic>)['senderId'] != data['senderId'];

            return Column(
              children: [
                if (showSeparator && timestamp != null)
                  _DateSeparator(label: _formatDateLabel(timestamp)),
                _MessageBubble(
                  text: data['text'] ?? '',
                  time: _formatTime(timestamp),
                  isMe: isMe,
                  showTail: isLastInGroup,
                  otherPersonName: widget.otherPersonName,
                  otherPhotoUrl: _otherPhotoUrl,
                  otherPhotoBase64: _otherPhotoBase64,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UserAvatar(
            name: widget.otherPersonName,
            photoUrl: _otherPhotoUrl,
            photoBase64: _otherPhotoBase64,
            radius: 44,
            fontSize: 28,
          ),
          const SizedBox(height: 14),
          Text(
            widget.otherPersonName,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _kInk),
          ),
          const SizedBox(height: 6),
          const Text(
            'No messages yet.\nSay hello! 👋',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _showAttachmentSheet,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(bottom: 1),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kAccent.withOpacity(0.20), width: 1),
                ),
                child: const Icon(Icons.add_rounded, color: _kAccent, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true,
                    fillColor: _kBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _hasText && !_sending ? _kAccent : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.send_rounded,
                    color: _hasText ? Colors.white : Colors.grey, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete conversation', style: TextStyle(color: Colors.red)),
              onTap: () async {
                // Close the bottom sheet first
                if (mounted) Navigator.pop(context);

                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete conversation?',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    content: const Text(
                        'This will remove the conversation for both users.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm != true) return;

                // Show loading indicator
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                try {
                  // Delete the conversation
                  await _chatService.deleteConversation(widget.conversationId);

                  // Close loading dialog
                  if (mounted) Navigator.pop(context);

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Conversation deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  // Navigate back to the previous screen (chat list)
                  if (mounted) {
                    // Pop twice to ensure we go back to the chat list
                    // First pop closes any additional dialogs, second pop goes back
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // Or if you have a specific route name, you can use:
                    // Navigator.of(context).pushNamedAndRemoveUntil('/hub', (route) => false);
                  }
                } catch (e) {
                  // Close loading dialog
                  if (mounted) Navigator.pop(context);

                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete conversation: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.grey),
              title: const Text('Block user'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            _UserAvatar(
              name: widget.otherPersonName,
              photoUrl: _otherPhotoUrl,
              photoBase64: _otherPhotoBase64,
              radius: 44,
              fontSize: 32,
            ),
            const SizedBox(height: 14),
            Text(
              widget.otherPersonName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kInk),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.message_rounded, size: 16),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: BorderSide(color: _kAccent.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Share',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachOption(Icons.image_rounded, 'Photo', const Color(0xFF10B981)),
                _attachOption(Icons.insert_drive_file_rounded, 'File', const Color(0xFF3B82F6)),
                _attachOption(Icons.link_rounded, 'Link', const Color(0xFF8B5CF6)),
                _attachOption(Icons.location_on_rounded, 'Location', const Color(0xFFEF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.20)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? photoBase64;
  final double radius;
  final double fontSize;

  const _UserAvatar({
    required this.name,
    required this.radius,
    required this.fontSize,
    this.photoUrl,
    this.photoBase64,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64!);
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: _kAccent.withOpacity(0.12),
      child: Text(
        initials,
        style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: fontSize),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMe;
  final bool showTail;
  final String otherPersonName;
  final String? otherPhotoUrl;
  final String? otherPhotoBase64;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMe,
    required this.showTail,
    required this.otherPersonName,
    this.otherPhotoUrl,
    this.otherPhotoBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: showTail ? 10 : 3,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showTail) ...[
            _UserAvatar(
              name: otherPersonName,
              photoUrl: otherPhotoUrl,
              photoBase64: otherPhotoBase64,
              radius: 14,
              fontSize: 11,
            ),
            const SizedBox(width: 6),
          ] else if (!isMe)
            const SizedBox(width: 34),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _kAccent : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : (showTail ? 4 : 18)),
                      bottomRight: Radius.circular(isMe ? (showTail ? 4 : 18) : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(color: isMe ? Colors.white : _kInk, fontSize: 14, height: 1.4),
                  ),
                ),
                if (showTail)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ],
      ),
    );
  }
}