import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/homePage.dart';
import 'package:flutter/material.dart';
import 'package:final_project/services/notificationService.dart';

class NotificationsScreen extends StatefulWidget {
  final int? localUserId;
  final String? firebaseUserId;

  const NotificationsScreen({
    super.key,
    this.localUserId,
    this.firebaseUserId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}


class _NotificationBadge extends StatefulWidget {
  final String userId;
  final VoidCallback? onTap;
  
  const _NotificationBadge({
    required this.userId,
    this.onTap,
  });
  
  @override
  State<_NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<_NotificationBadge> {
  late Stream<int> _unreadCountStream;

  @override
  void initState() {
    super.initState();
    _unreadCountStream = NotificationService.instance
        .unreadCountStream(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCountStream,
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: widget.onTap ?? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsScreen(
                      firebaseUserId: widget.userId,
                    ),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _localNotifs = [];
  List<QueryDocumentSnapshot> _remoteNotifs = [];
  late TabController _tabCtrl;
  late Stream<QuerySnapshot> _notificationsStream;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
    _loadLocalNotifications();
    _setupRemoteNotificationsStream();
  }

  Future<void> _loadLocalNotifications() async {
    if (widget.localUserId != null) {
      final list = await DatabaseHelper().getNotifications(widget.localUserId!);
      if (mounted) {
        setState(() {
          _localNotifs = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupRemoteNotificationsStream() {
    final userId = widget.firebaseUserId ??
        (widget.localUserId != null ? 'local_${widget.localUserId}' : null);
    
    if (userId != null) {
      _notificationsStream = NotificationService.instance
          .getNotificationsStream(userId);
    }
  }

  Future<void> _markAllRemoteAsRead() async {
    final userId = widget.firebaseUserId ??
        (widget.localUserId != null ? 'local_${widget.localUserId}' : null);
    
    if (userId != null) {
      await NotificationService.instance.markAllRead(userId);
    }
  }

  Future<void> _deleteLocal(int id) async {
    await DatabaseHelper().deleteNotification(id);
    setState(() {
      _localNotifs.removeWhere((n) => n['id'] == id);
    });
  }

  Future<void> _clearAll() async {
    // Clear local
    for (final n in _localNotifs) {
      await DatabaseHelper().deleteNotification(n['id'] as int);
    }
    
    // Clear remote
    final userId = widget.firebaseUserId ??
        (widget.localUserId != null ? 'local_${widget.localUserId}' : null);
    if (userId != null) {
      await NotificationService.instance.deleteAllNotifications(userId);
    }
    
    if (mounted) {
      setState(() {
        _localNotifs.clear();
        _remoteNotifs.clear();
      });
    }
  }

  String _timeAgo(dynamic dateVal) {
    try {
      DateTime dt;
      if (dateVal is Timestamp) {
        dt = dateVal.toDate();
      } else if (dateVal is DateTime) {
        dt = dateVal;
      } else if (dateVal is String) {
        dt = DateTime.parse(dateVal);
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return '';
    }
  }

  int get _totalUnread {
    final localUnread = _localNotifs
        .where((n) => (n['isRead'] as int? ?? 0) == 0).length;
    final remoteUnread = _remoteNotifs
        .where((n) => n['isRead'] == false).length;
    return localUnread + remoteUnread;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1B4B)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => Homepage(localUserId: widget.localUserId),
                ),
              );
            }
          },
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E1B4B),
          ),
        ),
        actions: [
          if (_localNotifs.isNotEmpty || _remoteNotifs.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text("Clear all"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF472B6),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: const Color(0xFF7B6CF6),
                    unselectedLabelColor: const Color(0xFFA5B4FC),
                    indicatorColor: const Color(0xFF7B6CF6),
                    tabs: [
                      Tab(text: 'Posts ${_localNotifs.isNotEmpty ? '(${_localNotifs.length})' : ''}'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Tab Bar View
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _notificationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasData) {
                        _remoteNotifs = snapshot.data!.docs;
                        // Auto-mark as read when viewing
                        _markAllRemoteAsRead();
                      }
                      
                      return TabBarView(
                        controller: _tabCtrl,
                        children: [
                          // Posts tab
                          _buildList(
                            items: _localNotifs,
                            emptyMsg: "No post notifications",
                            emptyHint: "Get notified when someone comments on your posts",
                            builder: (n) => _buildLocalTile(n),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyMsg,
    required String emptyHint,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: const Color(0xFFA5B4FC)),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              emptyHint,
              style: const TextStyle(color: Color(0xFFA5B4FC)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => builder(items[index]),
    );
  }

  Widget _buildLocalTile(Map<String, dynamic> notification) {
    final isRead = (notification['isRead'] as int? ?? 0) == 1;
    final type = notification['type'] as String? ?? 'comment';
    
    IconData icon;
    Color color;
    
    switch (type) {
      case 'reply':
        icon = Icons.reply;
        color = const Color(0xFFF472B6);
        break;
      case 'accepted':
        icon = Icons.check_circle;
        color = const Color(0xFF34D399);
        break;
      default:
        icon = Icons.comment;
        color = const Color(0xFF7B6CF6);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRead ? Colors.white.withOpacity(0.6) : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          notification['fromUserName'] ?? 'Someone',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? ''),
            if (notification['postTitle'] != null)
              Text(
                notification['postTitle'],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Text(
          _timeAgo(notification['createdAt']),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        onTap: () {
          // Navigate to homepage with community feed tab and scroll to specific post
          final postId = notification['postId'] as int?;
          if (postId != null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => Homepage(
                  localUserId: widget.localUserId,
                  initialPostId: postId,
                ),
              ),
              (route) => false,
            );
          }
        },
      ),
    );
  }
}