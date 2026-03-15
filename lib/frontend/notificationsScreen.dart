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
const _kBorderGlass = Color(0xFFE0D9FF);

class NotificationsScreen extends StatefulWidget {
  final int? localUserId;
  const NotificationsScreen({super.key, this.localUserId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.localUserId == null) {
      setState(() => _loading = false);
      return;
    }
    final list = await DatabaseHelper().getNotifications(widget.localUserId!);
    await DatabaseHelper().markAllNotificationsRead(widget.localUserId!);
    if (mounted) setState(() { _notifications = list; _loading = false; });
  }

  Future<void> _delete(int id) async {
    await DatabaseHelper().deleteNotification(id);
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
  }

  String _timeAgo(String dateStr) {
    try {
      final dt   = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours  < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays   < 1) return '${diff.inHours}h ago';
      if (diff.inDays   < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Stack(children: [
        // Background gradient
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
            Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.68, 1.0],
        ))),

        SafeArea(child: Column(children: [

          // ── Header ──
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
                        boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                            blurRadius: 8, offset: const Offset(0, 3))]),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _kViolet, size: 17)),
              ),
              const SizedBox(width: 14),
              const Text("Notifications", style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.4)),
              const Spacer(),
              if (_notifications.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    for (final n in _notifications) {
                      await DatabaseHelper().deleteNotification(n['id'] as int);
                    }
                    setState(() => _notifications.clear());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _kBlush.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBlush.withOpacity(0.30))),
                    child: const Text("Clear all", style: TextStyle(
                        fontSize: 11.5, color: _kBlush, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── List ──
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kViolet))
              : _notifications.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 72, height: 72,
                    decoration: BoxDecoration(
                        color: _kViolet.withOpacity(0.10), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: _kViolet, size: 36)),
                const SizedBox(height: 14),
                const Text("No notifications yet", style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kInkLight)),
                const SizedBox(height: 6),
                const Text("You'll be notified when someone\nreplies to your posts",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: _kInkMuted)),
              ]))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: _notifications.length,
            itemBuilder: (_, i) => _buildTile(_notifications[i]),
          )),
        ])),
      ]),
    );
  }

  Widget _buildTile(Map<String, dynamic> n) {
    final isRead  = (n['isRead'] as int? ?? 0) == 1;
    final type    = n['type']  as String? ?? 'comment';
    final isReply    = type == 'reply';
    final isAccepted = type == 'accepted';
    final color = isAccepted ? _kMint
        : isReply   ? _kBlush
        : _kViolet;
    final icon  = isAccepted ? Icons.check_circle_rounded
        : isReply   ? Icons.reply_rounded
        : Icons.comment_rounded;

    return Dismissible(
      key: Key('notif_${n['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(n['id'] as int),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: _kBlush.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: _kBlush, size: 22),
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
              color: isRead ? _kBorderGlass : color.withOpacity(0.30),
              width: isRead ? 1.0 : 1.5),
          boxShadow: [BoxShadow(
              color: _kViolet.withOpacity(isRead ? 0.04 : 0.09),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(n['fromUserName'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 13, color: isRead ? _kInkLight : _kInk))),
                  if (!isRead)
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: _kViolet, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 3),
                Text(n['message'] ?? '', style: TextStyle(
                    fontSize: 12.5, color: isRead ? _kInkMuted : _kInkLight,
                    height: 1.4)),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(n['postTitle'] ?? '', overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: color))),
                  const Spacer(),
                  Text(_timeAgo(n['createdAt'] ?? ''),
                      style: const TextStyle(fontSize: 10.5, color: _kInkMuted)),
                ]),
              ])),
        ]),
      ),
    );
  }
}