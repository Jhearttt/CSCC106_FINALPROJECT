import 'dart:async';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/connectivityService.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kBlue      = Color(0xFF1E88E5);
const _kBlueDark  = Color(0xFF0D47A1);
const _kBlueLight = Color(0xFF90CAF9);
const _kBlueSoft  = Color(0xFFF0F7FF);
const _kViolet    = Color(0xFF7B6CF6);
const _kBlush     = Color(0xFFF472B6);
const _kMint      = Color(0xFF34D399);

// ─── Comment Model ────────────────────────────────────────────────────────────
class CommentModel {
  final int     commentId;
  final int     postId;
  final int     userId;
  final String  commentText;
  final String  timestamp;
  final int     synced;
  final int?    parentCommentId;
  final String? userFullName;
  final String? userUserName;
  final String? userProfilePic;
  final List<CommentModel> replies;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.timestamp,
    this.synced = 0,
    this.parentCommentId,
    this.userFullName,
    this.userUserName,
    this.userProfilePic,
    this.replies = const [],
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    final rawReplies = map['replies'] as List? ?? [];
    return CommentModel(
      commentId:       map['id']             as int,
      postId:          map['postId']         as int?    ?? 0,
      userId:          map['userId']         as int,
      commentText:     map['comment']        as String,
      timestamp:       map['dateCommented']  as String,
      synced:          map['synced']         as int?    ?? 0,
      parentCommentId: map['parentCommentId'] as int?,
      userFullName:    map['userFullName']   as String?,
      userUserName:    map['userUserName']   as String?,
      userProfilePic:  map['userProfilePic'] as String?,
      replies:         rawReplies
          .map((r) => CommentModel.fromMap(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Comments Modal entry point ───────────────────────────────────────────────
class CommentsModal {
  static void show(BuildContext context, {
    required int    postId,
    required int?   localUserId,
    required String postTitle,
  }) {
    showGeneralDialog(
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'CommentsModal',
      barrierColor:       Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder:  (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
      pageBuilder: (_, __, ___) => Dialog(
        backgroundColor:  Colors.transparent,
        insetPadding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
        child: _CommentsCard(
            postId: postId, localUserId: localUserId, postTitle: postTitle),
      ),
    );
  }
}

// ─── Comments Card ────────────────────────────────────────────────────────────
class _CommentsCard extends StatefulWidget {
  final int postId; final int? localUserId; final String postTitle;
  const _CommentsCard({required this.postId, required this.localUserId,
    required this.postTitle});
  @override
  State<_CommentsCard> createState() => _CommentsCardState();
}

class _CommentsCardState extends State<_CommentsCard> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();

  List<CommentModel> _comments  = [];
  bool _loading    = true;
  bool _submitting = false;
  bool _isOffline  = false;

  // Reply state — set when user taps "Reply" on a comment
  CommentModel? _replyingTo;

  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.instance.isOnline;
    _connectivitySub = ConnectivityService.instance.onStatusChange
        .listen((online) { if (mounted) setState(() => _isOffline = !online); });
    _load();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await SyncService.instance.pullCommentsFromFirestore(widget.postId);
    final raw = await DatabaseHelper().getCommentsByPost(widget.postId);
    if (mounted) setState(() {
      _comments = raw.map((r) => CommentModel.fromMap(r)).toList();
      _loading  = false;
    });
  }

  Future<void> _submit() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (widget.localUserId == null) {
      _snack("You must be logged in to comment.", error: true); return;
    }
    setState(() => _submitting = true);

    final user     = await DatabaseHelper().getUserById(widget.localUserId!);
    final fullName = user?['fullName'] as String? ?? 'Unknown';

    final result = await SyncService.instance.saveComment(
      postId:          widget.postId,
      userId:          widget.localUserId!,
      userFullName:    fullName,
      comment:         text,
      parentCommentId: _replyingTo?.commentId,
    );

    if (result > 0) {
      _commentCtrl.clear();
      setState(() => _replyingTo = null);
      await _load();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });
    } else {
      _snack("Failed to send. Try again.", error: true);
    }
    setState(() => _submitting = false);
  }

  Future<void> _delete(int commentId) async {
    await SyncService.instance.deleteComment(commentId);
    _load();
  }

  final FocusNode _inputFocus = FocusNode();

  void _setReplyTo(CommentModel c) {
    setState(() => _replyingTo = c);
    _commentCtrl.clear();
    // Small delay so the banner renders before keyboard opens
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() { _replyingTo = null; _commentCtrl.clear(); });
    _inputFocus.unfocus();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFD32F2F) : _kBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _timeAgo(String s) {
    try {
      final dt   = DateTime.parse(s);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours  < 1) return '${diff.inMinutes}m';
      if (diff.inDays   < 1) return '${diff.inHours}h';
      if (diff.inDays   < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Count including replies
    final total = _comments.fold<int>(
        0, (sum, c) => sum + 1 + c.replies.length);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82),
      decoration: BoxDecoration(
        color: _kBlueSoft,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: _kBlue.withOpacity(0.14),
              blurRadius: 30, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.comment_rounded, color: _kBlue, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Comments", style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800, color: _kBlueDark)),
                    Text(widget.postTitle, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _kBlueLight)),
                  ])),
              // Count badge
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBlueLight, width: 1.2)),
                  child: Text('$total', style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _kBlueDark))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: _kBlue.withOpacity(0.10), shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: _kBlue, size: 17))),
            ]),
          ),

          // Divider
          Container(height: 2, margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                      colors: [_kBlue, _kBlueLight, Colors.transparent]))),

          // ── Offline banner ──
          if (_isOffline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D))),
              child: const Row(children: [
                Icon(Icons.wifi_off_rounded, color: Color(0xFFF57C00), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text("You're offline. Comments will sync later.",
                    style: TextStyle(fontSize: 12, color: Color(0xFFF57C00),
                        fontWeight: FontWeight.w500))),
              ]),
            ),

          // ── Reply-to banner ──
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kViolet.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kViolet.withOpacity(0.30)),
              ),
              child: Row(children: [
                const Icon(Icons.reply_rounded, color: _kViolet, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'Replying to ${_replyingTo!.userFullName ?? "someone"}',
                    style: const TextStyle(fontSize: 12.5,
                        color: _kViolet, fontWeight: FontWeight.w600))),
                GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close_rounded,
                        color: _kViolet, size: 16)),
              ]),
            ),

          // ── Comment list ──
          Flexible(child: _loading
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: _kBlue)))
              : _comments.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: _kBlueLight, size: 44),
                    const SizedBox(height: 10),
                    const Text("No comments yet.\nBe the first to reply!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _kBlueDark,
                            fontSize: 13.5, fontWeight: FontWeight.w500)),
                  ])))
              : ListView.builder(
            controller: _scrollCtrl,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            itemCount: _comments.length,
            itemBuilder: (_, i) => _buildCommentThread(_comments[i]),
          ),
          ),

          // ── Input ──
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.90),
              border: const Border(top: BorderSide(color: Color(0xFFBBDEFB))),
              boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.06),
                  blurRadius: 10, offset: const Offset(0, -3))],
            ),
            child: Row(children: [
              // User avatar
              Container(width: 36, height: 36,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [Color(0xFF42A5F5), Color(0xFF1565C0)])),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Container(
                decoration: BoxDecoration(color: _kBlueSoft,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _kBlueLight, width: 1.2)),
                child: TextField(
                  controller: _commentCtrl,
                  focusNode:  _inputFocus,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(color: _kBlueDark, fontSize: 13.5),
                  decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Write a reply...' : 'Write a comment...',
                      hintStyle: const TextStyle(color: _kBlueLight, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10)),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: _replyingTo != null
                        ? [_kViolet, const Color(0xFFA78BFA)]
                        : [_kBlue, _kBlueDark]),
                    boxShadow: [BoxShadow(
                        color: (_replyingTo != null ? _kViolet : _kBlue)
                            .withOpacity(0.35),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: _submitting
                      ? const Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Icon(_replyingTo != null
                      ? Icons.reply_rounded : Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── One comment + its replies ─────────────────────────────────────────────
  Widget _buildCommentThread(CommentModel comment) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildCommentCard(comment, isReply: false),
      // Indented replies
      if (comment.replies.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Column(children: [
            // Thread line
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 2, height: 12,
                  color: _kBlueLight.withOpacity(0.50)),
            ]),
            ...comment.replies.map((r) => _buildCommentCard(r, isReply: true)),
          ]),
        ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _buildCommentCard(CommentModel comment, {required bool isReply}) {
    final initials = (comment.userFullName ?? '?').isNotEmpty
        ? comment.userFullName![0].toUpperCase() : '?';
    final isOwner  = widget.localUserId != null &&
        comment.userId == widget.localUserId;

    return Container(
      margin: EdgeInsets.only(bottom: isReply ? 6 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply
            ? const Color(0xFFEEF5FF).withOpacity(0.80)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(isReply ? 14 : 16),
        border: Border.all(
            color: isReply
                ? _kBlueLight.withOpacity(0.30)
                : _kBlueLight.withOpacity(0.40), width: 1),
        boxShadow: [BoxShadow(color: _kBlue.withOpacity(0.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        _buildAvatar(comment.userProfilePic, initials, isReply ? 28.0 : 34.0),
        const SizedBox(width: 10),

        // Content
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(comment.userFullName ?? 'Unknown', style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isReply ? 11.5 : 12.5,
                    color: _kBlueDark)),
                const SizedBox(width: 6),
                Text(_timeAgo(comment.timestamp), style: const TextStyle(
                    fontSize: 10, color: _kBlueLight)),
                if (comment.synced == 0) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.schedule_rounded,
                      size: 11, color: Color(0xFFF9A825)),
                ],
              ]),
              const SizedBox(height: 3),
              Text(comment.commentText, style: const TextStyle(
                  fontSize: 13, color: _kBlueDark, height: 1.4)),
              const SizedBox(height: 6),

              // Actions: Reply + Delete
              Row(children: [
                // Reply button (only on top-level comments)
                if (!isReply)
                  GestureDetector(
                    onTap: () => _setReplyTo(comment),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.reply_rounded,
                          color: _kBlueLight, size: 13),
                      const SizedBox(width: 3),
                      const Text("Reply", style: TextStyle(
                          fontSize: 11, color: _kBlueLight,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                // Reply count badge on top-level
                if (!isReply && comment.replies.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: _kBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          '${comment.replies.length} repl${comment.replies.length == 1 ? 'y' : 'ies'}',
                          style: const TextStyle(fontSize: 10,
                              color: _kBlue, fontWeight: FontWeight.w600))),
                ],
                const Spacer(),
                // Delete own comment
                if (isOwner)
                  GestureDetector(
                      onTap: () => _delete(comment.commentId),
                      child: Container(padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE), shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFEF9A9A).withOpacity(0.50))),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFD32F2F), size: 12))),
              ]),
            ])),
      ]),
    );
  }

  Widget _buildAvatar(String? photoUrl, String initial, double size) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
          image: photoUrl != null && photoUrl.isNotEmpty
              ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
              : null,
        ),
        child: photoUrl == null || photoUrl.isEmpty
            ? Center(child: Text(initial, style: TextStyle(
            color: Colors.white, fontSize: size * 0.38,
            fontWeight: FontWeight.w800))) : null,
      );
}