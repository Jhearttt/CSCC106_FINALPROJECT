import 'dart:async';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/connectivityService.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';

// ─── Dot Grid Painter ─────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E88E5).withOpacity(0.06)
      ..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = spacing; x < size.width; x += spacing)
      for (double y = spacing; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Comment Data Model ───────────────────────────────────────────────────────
// Satisfies the SRS requirement for CommentsModal as a structured data model.
// Fields: commentId, postId, userId, commentText, timestamp (+ synced status).

class CommentModel {
  final int commentId;
  final int postId;
  final int userId;
  final String commentText;
  final String timestamp;
  final int synced;

  // Optional joined fields (populated when queried with user info)
  final String? userFullName;
  final String? userUserName;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.timestamp,
    this.synced = 0,
    this.userFullName,
    this.userUserName,
  });

  /// Build a CommentModel from a database row map
  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      commentId: map['id'] as int,
      postId: map['postId'] as int? ?? 0,
      userId: map['userId'] as int,
      commentText: map['comment'] as String,
      timestamp: map['dateCommented'] as String,
      synced: map['synced'] as int? ?? 0,
      userFullName: map['userFullName'] as String?,
      userUserName: map['userUserName'] as String?,
    );
  }

  /// Convert a CommentModel to a database row map (for insert / update)
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'comment': commentText,
      'synced': synced,
    };
  }

  /// Return a copy with updated fields
  CommentModel copyWith({
    int? commentId,
    int? postId,
    int? userId,
    String? commentText,
    String? timestamp,
    int? synced,
    String? userFullName,
    String? userUserName,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      commentText: commentText ?? this.commentText,
      timestamp: timestamp ?? this.timestamp,
      synced: synced ?? this.synced,
      userFullName: userFullName ?? this.userFullName,
      userUserName: userUserName ?? this.userUserName,
    );
  }

  @override
  String toString() =>
      'CommentModel(commentId: $commentId, postId: $postId, userId: $userId, '
          'commentText: $commentText, timestamp: $timestamp, synced: $synced)';
}

// ─── Comments Modal (UI) ──────────────────────────────────────────────────────
// Call this from anywhere:
//   CommentsModal.show(context, postId: post['id'], localUserId: widget.localUserId, postTitle: post['title']);

class CommentsModal {
  static void show(
      BuildContext context, {
        required int postId,
        required int? localUserId,
        required String postTitle,
      }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _CommentsSheet(
        postId: postId,
        localUserId: localUserId,
        postTitle: postTitle,
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final int postId;
  final int? localUserId;
  final String postTitle;

  const _CommentsSheet({
    required this.postId,
    required this.localUserId,
    required this.postTitle,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Use typed CommentModel list instead of raw maps
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  // Offline queue — comments pending sync
  final List<Map<String, dynamic>> _offlineQueue = [];
  bool _isOffline = false;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    // Wire offline banner to real connectivity status
    _isOffline = !ConnectivityService.instance.isOnline;
    _connectivitySub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (mounted) setState(() => _isOffline = !online);
    });
    _loadComments();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    // Pull latest from Firestore so all users' comments are visible
    await SyncService.instance.pullCommentsFromFirestore(widget.postId);
    final rawData = await DatabaseHelper().getCommentsByPost(widget.postId);
    if (mounted) {
      setState(() {
        _comments = rawData.map((row) => CommentModel.fromMap(row)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (widget.localUserId == null) {
      _showSnack("You must be logged in to comment.", isError: true); return;
    }
    setState(() => _submitting = true);

    // Fetch user name so Firestore doc stores the author
    final localUser = await DatabaseHelper().getUserById(widget.localUserId!);
    final fullName  = localUser?['fullName'] as String? ?? 'Unknown';

    final result = await SyncService.instance.saveComment(
      postId:       widget.postId,
      userId:       widget.localUserId!,
      userFullName: fullName,
      comment:      text,
    );

    if (result > 0) {
      _commentCtrl.clear();
      await _loadComments();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    } else {
      _showSnack("Failed to send comment", isError: true);
    }
    setState(() => _submitting = false);
  }

  Future<void> _deleteComment(int commentId) async {
    await SyncService.instance.deleteComment(commentId);
    _loadComments();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? const Color(0xFFD32F2F) : const Color(0xFF1E88E5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _timeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F7FF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Stack(children: [
        // ── Dot grid background ──
        ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          child: IgnorePointer(
              child: CustomPaint(
                  painter: _DotGridPainter(),
                  child: const SizedBox.expand())),
        ),

        Column(children: [
          // ── Handle bar ──
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF90CAF9),
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.comment_rounded,
                    color: Color(0xFF1E88E5), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Comments",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D47A1))),
                        Text(widget.postTitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF90CAF9))),
                      ])),
              // Comment count badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF90CAF9), width: 1.2)),
                child: Text(
                    '${_comments.length + _offlineQueue.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D47A1))),
              ),
            ]),
          ),

          // ── Gradient divider ──
          Container(
              height: 2,
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [
                    Color(0xFF1E88E5),
                    Color(0xFFBBDEFB),
                    Colors.transparent
                  ]))),

          // ── Offline banner ──
          if (_isOffline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: const Color(0xFFFFB74D))),
              child: Row(children: const [
                Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFF57C00), size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        "You're offline. Comments will be queued.",
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF57C00),
                            fontWeight: FontWeight.w500))),
              ]),
            ),

          // ── Pending offline comments ──
          if (_offlineQueue.isNotEmpty)
            ..._offlineQueue.map((q) => _buildPendingCard(q['comment'])),

          // ── Comments list ──
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1E88E5)))
                : _comments.isEmpty && _offlineQueue.isEmpty
                ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFF90CAF9), size: 48),
                      const SizedBox(height: 10),
                      const Text(
                          "No comments yet.\nBe the first to reply!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ]))
                : ListView.builder(
              controller: _scrollCtrl,
              padding:
              const EdgeInsets.fromLTRB(16, 10, 16, 10),
              itemCount: _comments.length,
              itemBuilder: (context, index) =>
                  _buildCommentCard(_comments[index]),
            ),
          ),

          // ── Input area ──
          Container(
            padding:
            EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.90),
              border: const Border(
                  top: BorderSide(
                      color: Color(0xFFBBDEFB), width: 1)),
              boxShadow: [
                BoxShadow(
                    color:
                    const Color(0xFF64B5F6).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3))
              ],
            ),
            child: Row(children: [
              // Avatar placeholder
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Color(0xFF42A5F5),
                    Color(0xFF1565C0)
                  ]),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFF90CAF9),
                          width: 1.2)),
                  child: TextField(
                    controller: _commentCtrl,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        color: Color(0xFF0D47A1), fontSize: 13.5),
                    decoration: const InputDecoration(
                        hintText: "Write a comment...",
                        hintStyle: TextStyle(
                            color: Color(0xFF90CAF9), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              GestureDetector(
                onTap: _submitting ? null : _submitComment,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [
                      Color(0xFF1E88E5),
                      Color(0xFF0D47A1)
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1E88E5)
                              .withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: _submitting
                      ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── Comment card now accepts typed CommentModel ──
  Widget _buildCommentCard(CommentModel comment) {
    final initials =
    (comment.userFullName ?? '?').isNotEmpty
        ? comment.userFullName![0].toUpperCase()
        : '?';
    final isOwner = widget.localUserId != null &&
        comment.userId == widget.localUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF90CAF9).withOpacity(0.40),
            width: 1),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF64B5F6).withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)])),
          child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),

        // Content
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(comment.userFullName ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF0D47A1))),
                    const SizedBox(width: 8),
                    Text(_timeAgo(comment.timestamp),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF90CAF9))),
                    // Show pending indicator if not yet synced
                    if (comment.synced == 0) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.schedule_rounded,
                          size: 11, color: Color(0xFFF9A825)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(comment.commentText,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1565C0),
                          height: 1.4)),
                ])),

        // Delete button (own comments only)
        if (isOwner)
          GestureDetector(
            onTap: () => _deleteComment(comment.commentId),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFEF9A9A).withOpacity(0.50))),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F), size: 13),
            ),
          ),
      ]),
    );
  }

  Widget _buildPendingCard(String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1).withOpacity(0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFCC02).withOpacity(0.60),
              width: 1)),
      child: Row(children: [
        const Icon(Icons.schedule_rounded,
            color: Color(0xFFF9A825), size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF795548)))),
        const Text("Pending",
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFFF9A825),
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}