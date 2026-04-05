import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kInk         = Color(0xFF1E1B4B);
const _kInkLight    = Color(0xFF818CF8);
const _kInkMuted    = Color(0xFFA5B4FC);
const _kViolet      = Color(0xFF7B6CF6);
const _kVioletLight = Color(0xFFA78BFA);
const _kVioletSoft  = Color(0xFFEDE9FE);
const _kBlush       = Color(0xFFF472B6);
const _kMint        = Color(0xFF34D399);
const _kSky         = Color(0xFF60A5FA);
const _kAmber       = Color(0xFFFCD34D);
const _kBorderGlass = Color(0xFFE0D9FF);

class NotificationsScreen extends StatefulWidget {
  final int?    localUserId;
  final String? firebaseUserId;

  const NotificationsScreen({
    super.key,
    this.localUserId,
    this.firebaseUserId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  // SQLite notifications (comments + replies)
  List<Map<String, dynamic>> _localNotifs  = [];
  // Firestore notifications (chat + forum)
  List<Map<String, dynamic>> _remoteNotifs = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Load SQLite (local) notifications
    if (widget.localUserId != null) {
      final list = await DatabaseHelper()
          .getNotifications(widget.localUserId!);
      await DatabaseHelper()
          .markAllNotificationsRead(widget.localUserId!);
      if (mounted) setState(() => _localNotifs = list);
    }

    // Load Firestore (remote) notifications
    final userId = widget.firebaseUserId ??
        (widget.localUserId != null
            ? 'local_${widget.localUserId}'
            : null);

    if (userId != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        // Mark all as read
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          if (doc['isRead'] == false) {
            batch.update(doc.reference, {'isRead': true});
          }
        }
        await batch.commit();

        if (mounted) {
          setState(() {
            _remoteNotifs = snap.docs
                .map((d) => {'id': d.id, ...d.data()})
                .toList();
          });
        }
      } catch (e) {
        debugPrint('Remote notifications load failed: $e');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  // ── Delete local notification ──────────────────────────────────────────────
  Future<void> _deleteLocal(int id) async {
    await DatabaseHelper().deleteNotification(id);
    setState(() => _localNotifs.removeWhere((n) => n['id'] == id));
  }

  // ── Delete remote notification ─────────────────────────────────────────────
  Future<void> _deleteRemote(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .delete();
    setState(() => _remoteNotifs.removeWhere((n) => n['id'] == id));
  }

  // ── Clear all ──────────────────────────────────────────────────────────────
  Future<void> _clearAll() async {
    // Clear local
    for (final n in _localNotifs) {
      await DatabaseHelper().deleteNotification(n['id'] as int);
    }
    // Clear remote
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _remoteNotifs) {
      batch.delete(FirebaseFirestore.instance
          .collection('notifications')
          .doc(n['id'] as String));
    }
    await batch.commit();
    setState(() {
      _localNotifs.clear();
      _remoteNotifs.clear();
    });
  }

  String _timeAgo(dynamic dateVal) {
    try {
      DateTime dt;
      if (dateVal is Timestamp) {
        dt = dateVal.toDate();
      } else if (dateVal is String) {
        dt = DateTime.parse(dateVal);
      } else {
        return '';
      }
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours  < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays   < 1) return '${diff.inHours}h ago';
      if (diff.inDays   < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  // ── Total unread count ─────────────────────────────────────────────────────
  int get _totalUnread {
    final localUnread  = _localNotifs
        .where((n) => (n['isRead'] as int? ?? 0) == 0).length;
    final remoteUnread = _remoteNotifs
        .where((n) => n['isRead'] == false).length;
    return localUnread + remoteUnread;
  }

  List<Map<String, dynamic>> get _chatNotifs =>
      _remoteNotifs.where((n) => n['type'] == 'chat').toList();

  List<Map<String, dynamic>> get _forumNotifs =>
      _remoteNotifs.where((n) => n['type'] == 'forum').toList();

  @override
  Widget build(BuildContext context) {
    final hasAny = _localNotifs.isNotEmpty || _remoteNotifs.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
                Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: [0.0, 0.35, 0.68, 1.0],
            ))),

        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _kBorderGlass, width: 1.2),
                    boxShadow: [BoxShadow(
                        color: _kViolet.withOpacity(0.10),
                        blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _kViolet, size: 17),
                ),
              ),
              const SizedBox(width: 14),
              Row(children: [
                const Text("Notifications",
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kInk, letterSpacing: -0.4)),
                if (_totalUnread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kViolet,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_totalUnread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              const Spacer(),
              if (hasAny)
                GestureDetector(
                  onTap: _clearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kBlush.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kBlush.withOpacity(0.30)),
                    ),
                    child: const Text("Clear all",
                        style: TextStyle(fontSize: 11.5,
                            color: _kBlush,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Tabs ─────────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.60),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorderGlass),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: _kViolet,
              unselectedLabelColor: _kInkMuted,
              indicatorColor: _kViolet,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Posts${_localNotifs.isNotEmpty ? ' (${_localNotifs.length})' : ''}'),
                Tab(text: 'Chats${_chatNotifs.isNotEmpty ? ' (${_chatNotifs.length})' : ''}'),
                Tab(text: 'Forums${_forumNotifs.isNotEmpty ? ' (${_forumNotifs.length})' : ''}'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                color: _kViolet))
                : TabBarView(
              controller: _tabCtrl,
              children: [
                // Posts tab (SQLite — comments + replies)
                _buildList(
                  items:     _localNotifs,
                  emptyMsg:  "No post notifications yet",
                  emptyHint: "You'll be notified when someone\ncomments or replies to your posts",
                  builder:   _buildLocalTile,
                ),
                // Chats tab
                _buildList(
                  items:     _chatNotifs,
                  emptyMsg:  "No chat notifications yet",
                  emptyHint: "You'll be notified when someone\nsends you a message",
                  builder:   _buildRemoteTile,
                ),
                // Forums tab
                _buildList(
                  items:     _forumNotifs,
                  emptyMsg:  "No forum notifications yet",
                  emptyHint: "Join forums to get notified\nwhen members post",
                  builder:   _buildRemoteTile,
                ),
              ],
            ),
          ),
        ])),
      ]),
    );
  }

  // ── Generic list builder ───────────────────────────────────────────────────
  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyMsg,
    required String emptyHint,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 72, height: 72,
                  decoration: BoxDecoration(
                      color: _kViolet.withOpacity(0.10),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: _kViolet, size: 36)),
              const SizedBox(height: 14),
              Text(emptyMsg, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _kInkLight)),
              const SizedBox(height: 6),
              Text(emptyHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, color: _kInkMuted)),
            ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      itemBuilder: (_, i) => builder(items[i]),
    );
  }

  // ── Local (SQLite) notification tile ──────────────────────────────────────
  Widget _buildLocalTile(Map<String, dynamic> n) {
    final isRead     = (n['isRead'] as int? ?? 0) == 1;
    final type       = n['type'] as String? ?? 'comment';
    final isReply    = type == 'reply';
    final isAccepted = type == 'accepted';
    final color = isAccepted ? _kMint
        : isReply   ? _kBlush
        : _kViolet;
    final icon  = isAccepted ? Icons.check_circle_rounded
        : isReply   ? Icons.reply_rounded
        : Icons.comment_rounded;

    return _NotifTile(
      id:          n['id'].toString(),
      isRead:      isRead,
      color:       color,
      icon:        icon,
      fromName:    n['fromUserName'] ?? '',
      message:     n['message']     ?? '',
      subtitle:    n['postTitle']   ?? '',
      timeAgo:     _timeAgo(n['createdAt']),
      onDismiss:   () => _deleteLocal(n['id'] as int),
    );
  }

  // ── Remote (Firestore) notification tile ──────────────────────────────────
  Widget _buildRemoteTile(Map<String, dynamic> n) {
    final isRead = n['isRead'] == true;
    final type   = n['type'] as String? ?? 'chat';
    final isChat = type == 'chat';
    final color  = isChat ? _kSky : _kMint;
    final icon   = isChat
        ? Icons.chat_bubble_rounded
        : Icons.forum_rounded;

    return _NotifTile(
      id:        n['id'].toString(),
      isRead:    isRead,
      color:     color,
      icon:      icon,
      fromName:  n['fromName'] ?? '',
      message:   n['message']  ?? '',
      subtitle:  n['title']    ?? '',
      timeAgo:   _timeAgo(n['createdAt']),
      onDismiss: () => _deleteRemote(n['id'] as String),
    );
  }
}

// ── Reusable notification tile ─────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final String   id;
  final bool     isRead;
  final Color    color;
  final IconData icon;
  final String   fromName;
  final String   message;
  final String   subtitle;
  final String   timeAgo;
  final VoidCallback onDismiss;

  const _NotifTile({
    required this.id,
    required this.isRead,
    required this.color,
    required this.icon,
    required this.fromName,
    required this.message,
    required this.subtitle,
    required this.timeAgo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notif_$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kBlush.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: _kBlush, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead
              ? Colors.white.withOpacity(0.60)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead
                ? _kBorderGlass
                : color.withOpacity(0.30),
            width: isRead ? 1.0 : 1.5,
          ),
          boxShadow: [BoxShadow(
              color: _kViolet.withOpacity(isRead ? 0.04 : 0.09),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 12),

              // Content
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(fromName,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isRead ? _kInkLight : _kInk))),
                      if (!isRead)
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: _kViolet,
                                shape: BoxShape.circle)),
                    ]),
                    const SizedBox(height: 3),
                    Text(message, style: TextStyle(
                        fontSize: 12.5,
                        color: isRead ? _kInkMuted : _kInkLight,
                        height: 1.4)),
                    const SizedBox(height: 5),
                    Row(children: [
                      if (subtitle.isNotEmpty)
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        )),
                      const Spacer(),
                      Text(timeAgo, style: const TextStyle(
                          fontSize: 10.5, color: _kInkMuted)),
                    ]),
                  ])),
            ]),
      ),
    );
  }
}