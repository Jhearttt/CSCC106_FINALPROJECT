import 'package:flutter/material.dart';
import 'createRoomScreen.dart';
import 'knowledgeBaseScreen.dart';
import 'uploadMaterialScreen.dart';

import 'package:final_project/chat/chatListScreen.dart' show ChatListScreen;
import 'package:final_project/chat/userListScreen.dart' show UserListScreen;
import 'package:final_project/forum/forumListScreen.dart';

// ─── Aurora Palette ─────────────────────────────────────────────
const _kInk = Color(0xFF1E1B4B);
const _kAccent = Color(0xFF6366F1);
const _kBg = Color(0xFFF8FAFC);

// ───────────────────────────────────────────────────────────────
// Forums Tab Wrapper
// ───────────────────────────────────────────────────────────────
class _ForumsTab extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;

  const _ForumsTab({
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return ForumListScreen(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );
  }
}

// ───────────────────────────────────────────────────────────────
// MAIN HUB SCREEN
// ───────────────────────────────────────────────────────────────
class HubScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const HubScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    "Chats",
    "Forums",
    "Knowledge",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Floating Button Action
  void _onFabPressed() {
    switch (_tabController.index) {
      case 0: // Chats
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserListScreen(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
            ),
          ),
        );
        break;

      case 1: // Forums
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateRoomScreen(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
            ),
          ),
        );
        break;

      case 2: // Knowledge
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UploadMaterialScreen(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
            ),
          ),
        );
        break;
    }
  }

  IconData _fabIcon() {
    switch (_tabController.index) {
      case 0:
        return Icons.chat_bubble_rounded;
      case 1:
        return Icons.groups_rounded;
      case 2:
        return Icons.upload_file_rounded;
      default:
        return Icons.add;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _kInk,
        title: const Text(
          "Hub",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: _kAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _kAccent,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _ChatsTab(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
          _ForumsTab(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
          _KnowledgeTab(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
        ],
      ),

      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return FloatingActionButton(
            backgroundColor: _kAccent,
            onPressed: _onFabPressed,
            child: Icon(_fabIcon()),
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// CHATS TAB
// ───────────────────────────────────────────────────────────────
class _ChatsTab extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;

  const _ChatsTab({
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    // Import directly here to avoid conflicts
    return Builder(
      builder: (_) => ChatListScreen(
        key: ValueKey(currentUserId),
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// KNOWLEDGE TAB
// ───────────────────────────────────────────────────────────────
class _KnowledgeTab extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;

  const _KnowledgeTab({
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return KnowledgeBaseScreen(
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );
  }
}