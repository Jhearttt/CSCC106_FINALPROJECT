import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:final_project/services/forumService.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk    = Color(0xFF1E1B4B);
const _kBg     = Color(0xFFF8FAFC);

class ForumDetailScreen extends StatefulWidget {
  final String forumId;
  final String forumTitle;
  final String currentUserId;
  final String currentUserName;

  const ForumDetailScreen({
    super.key,
    required this.forumId,
    required this.forumTitle,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final _controller      = TextEditingController();
  final _scrollController = ScrollController();
  final _forumService    = ForumService();
  final _focusNode       = FocusNode();
  bool _sending          = false;
  bool _hasText          = false;
  bool _isMember         = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
            () => setState(() => _hasText = _controller.text.trim().isNotEmpty));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Send message ───────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();

    await _forumService.postMessage(
      forumId:  widget.forumId,
      userId:   widget.currentUserId,
      userName: widget.currentUserName,
      text:     text,
    );

    setState(() => _sending = false);
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

  // ── Room info bottom sheet ─────────────────────────────────────────────────
  void _showRoomInfo(Map<String, dynamic> forumData) {
    final members     = List<String>.from(forumData['members'] ?? []);
    final isMember    = members.contains(widget.currentUserId);
    final isCreator   = forumData['createdBy'] == widget.currentUserId;
    final memberCount = forumData['memberCount'] ?? 0;
    final postCount   = forumData['postCount']   ?? 0;
    final category    = forumData['category']    ?? 'General';
    final description = forumData['description'] ?? '';
    final tags        = List<String>.from(forumData['tags'] ?? []);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          // Title + category
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.forum_rounded,
                  color: _kAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(forumData['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: _kInk)),
                  Text(category, style: const TextStyle(
                      fontSize: 13, color: Colors.grey)),
                ])),
          ]),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(description,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700,
                      height: 1.5)),
            ),
          ],

          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _statChip(Icons.people_rounded, '$memberCount members',
                _kAccent),
            const SizedBox(width: 10),
            _statChip(Icons.chat_rounded, '$postCount posts',
                const Color(0xFF10B981)),
          ]),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 6, children: tags.map((t) =>
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kAccent.withOpacity(0.20)),
                  ),
                  child: Text('#$t',
                      style: const TextStyle(
                          fontSize: 12, color: _kAccent,
                          fontWeight: FontWeight.w600)),
                )).toList()),
          ],

          const SizedBox(height: 20),

          // Join / Leave button (non-creators)
          if (!isCreator)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  isMember ? Colors.grey.shade100 : _kAccent,
                  foregroundColor:
                  isMember ? Colors.grey.shade700 : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  if (isMember) {
                    await _forumService.leaveForum(
                        widget.forumId, widget.currentUserId);
                  } else {
                    await _forumService.joinForum(
                        widget.forumId, widget.currentUserId);
                  }
                },
                child: Text(
                  isMember ? 'Leave Room' : 'Join Room',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

          // Delete forum (creator only)
          if (isCreator) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeleteForum(),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16),
                label: const Text('Delete Forum'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Confirm delete forum ───────────────────────────────────────────────────
  void _confirmDeleteForum() {
    Navigator.pop(context); // close info sheet
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete forum?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            'This will permanently delete the forum and all its messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forumService.deleteForum(widget.forumId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Message long-press options ─────────────────────────────────────────────
  void _showMessageOptions({
    required String  messageId,
    required String  senderId,
    required bool    isPinned,
    required String  creatorId,
  }) {
    final isAuthor  = senderId == widget.currentUserId;
    final isCreator = creatorId == widget.currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          // Pin/Unpin — creator only
          if (isCreator)
            ListTile(
              leading: Icon(
                isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: _kAccent,
              ),
              title: Text(isPinned ? 'Unpin message' : 'Pin message',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await _forumService.togglePin(
                  forumId:   widget.forumId,
                  messageId: messageId,
                  isPinned:  isPinned,
                );
              },
            ),

          // Delete — author or creator
          if (isAuthor || isCreator)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red),
              title: const Text('Delete message',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await _forumService.deleteMessage(
                    widget.forumId, messageId);
              },
            ),

          if (!isAuthor && !isCreator)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No options available',
                  style: TextStyle(color: Colors.grey)),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _forumService.getForumStream(widget.forumId),
      builder: (context, forumSnap) {
        final forumData =
            forumSnap.data?.data() as Map<String, dynamic>? ?? {};
        final creatorId =
            forumData['createdBy'] as String? ?? '';
        final members   =
        List<String>.from(forumData['members'] ?? []);
        final isMember  = members.contains(widget.currentUserId);

        return Scaffold(
          backgroundColor: _kBg,
          appBar: _buildAppBar(forumData),
          body: Column(children: [
            // ── Pinned messages banner ───────────────────────────────────
            _PinnedBanner(
                forumId: widget.forumId,
                forumService: _forumService),

            // ── Not a member warning ─────────────────────────────────────
            if (!isMember && forumSnap.hasData)
              _JoinBanner(
                onJoin: () => _forumService.joinForum(
                    widget.forumId, widget.currentUserId),
              ),

            // ── Messages ─────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _forumService.getMessages(widget.forumId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snapshot.data!.docs;
                  _scrollToBottom();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final msgDoc = docs[i];
                      final data   =
                      msgDoc.data() as Map<String, dynamic>;
                      final isMe   =
                          data['userId'] == widget.currentUserId;
                      final likes  =
                      List<String>.from(data['likes'] ?? []);
                      final isLiked =
                      likes.contains(widget.currentUserId);
                      final isPinned = data['isPinned'] == true;
                      final timestamp =
                      data['createdAt'] as Timestamp?;

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(
                          messageId: msgDoc.id,
                          senderId:  data['userId'] ?? '',
                          isPinned:  isPinned,
                          creatorId: creatorId,
                        ),
                        child: _MessageBubble(
                          messageId:    msgDoc.id,
                          text:         data['text'] ?? '',
                          senderName:   data['userName'] ?? 'Unknown',
                          time: timestamp != null
                              ? _formatTime(timestamp.toDate())
                              : '',
                          isMe:    isMe,
                          isPinned: isPinned,
                          likes:   likes.length,
                          isLiked: isLiked,
                          onLike: () => _forumService.toggleLike(
                            forumId:   widget.forumId,
                            messageId: msgDoc.id,
                            userId:    widget.currentUserId,
                            isLiked:   isLiked,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input bar ────────────────────────────────────────────────
            _buildInputBar(isMember),
          ]),
        );
      },
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(Map<String, dynamic> forumData) {
    final memberCount = forumData['memberCount'] ?? 0;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _kInk,
      title: GestureDetector(
        onTap: () => _showRoomInfo(forumData),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.forum_rounded,
                color: _kAccent, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.forumTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15, color: _kInk)),
            Text('$memberCount members · tap for info',
                style: const TextStyle(
                    fontSize: 10, color: Colors.grey)),
          ]),
        ]),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () {}, // forumData available via StreamBuilder above
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('No posts yet.\nBe the first to say something!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar(bool isMember) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: isMember
            ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
                  hintText: 'Write something...',
                  hintStyle: const TextStyle(
                      color: Colors.grey, fontSize: 14),
                  filled: true,
                  fillColor: _kBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
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
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _hasText && !_sending
                    ? _kAccent
                    : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Icon(Icons.send_rounded,
                  color: _hasText
                      ? Colors.white
                      : Colors.grey,
                  size: 20),
            ),
          ),
        ])
        // Not a member — show join prompt instead of input
            : GestureDetector(
          onTap: () => _forumService.joinForum(
              widget.forumId, widget.currentUserId),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _kAccent.withOpacity(0.25)),
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add_rounded,
                      color: _kAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Join this forum to post',
                      style: TextStyle(
                          color: _kAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ]),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Pinned Banner ──────────────────────────────────────────────────────────
class _PinnedBanner extends StatelessWidget {
  final String forumId;
  final ForumService forumService;
  const _PinnedBanner(
      {required this.forumId, required this.forumService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: forumService.getPinnedMessages(forumId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final pinned =
        snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return Container(
          color: _kAccent.withOpacity(0.06),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.push_pin_rounded,
                size: 14, color: _kAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pinned['text'] ?? '',
                style: const TextStyle(
                    fontSize: 12, color: _kAccent,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Join Banner ────────────────────────────────────────────────────────────
class _JoinBanner extends StatelessWidget {
  final VoidCallback onJoin;
  const _JoinBanner({required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 16, color: Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Join this forum to post messages',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF92400E),
                  fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: onJoin,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Join',
                style: TextStyle(
                    fontSize: 12, color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String text;
  final String senderName;
  final String time;
  final bool   isMe;
  final bool   isPinned;
  final int    likes;
  final bool   isLiked;
  final VoidCallback onLike;

  const _MessageBubble({
    required this.messageId,
    required this.text,
    required this.senderName,
    required this.time,
    required this.isMe,
    required this.isPinned,
    required this.likes,
    required this.isLiked,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom:  10,
        left:  isMe ? 60 : 0,
        right: isMe ? 0  : 60,
      ),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: _kAccent.withOpacity(0.12),
              child: Text(
                senderName.isNotEmpty
                    ? senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Sender name
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, bottom: 3),
                    child: Text(senderName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kInk)),
                  ),

                // Pin indicator
                if (isPinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded,
                            size: 10, color: _kAccent.withOpacity(0.6)),
                        const SizedBox(width: 3),
                        Text('Pinned',
                            style: TextStyle(
                                fontSize: 10,
                                color: _kAccent.withOpacity(0.6),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _kAccent : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                      Radius.circular(isMe ? 18 : 4),
                      bottomRight:
                      Radius.circular(isMe ? 4 : 18),
                    ),
                    border: isPinned
                        ? Border.all(
                        color: _kAccent.withOpacity(0.30),
                        width: 1.2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(text,
                      style: TextStyle(
                          color: isMe ? Colors.white : _kInk,
                          fontSize: 14, height: 1.4)),
                ),

                // Time + like button
                Padding(
                  padding: const EdgeInsets.only(
                      top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 8),
                      // Like button
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 13,
                                color: isLiked
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                              if (likes > 0) ...[
                                const SizedBox(width: 3),
                                Text('$likes',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isLiked
                                            ? Colors.red
                                            : Colors.grey,
                                        fontWeight:
                                        FontWeight.w600)),
                              ],
                            ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}