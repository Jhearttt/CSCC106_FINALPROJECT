import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:flutter/material.dart';
import 'chatRoomScreen.dart';
import 'package:final_project/services/chatService.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk = Color(0xFF1E1B4B);
const _kBg = Color(0xFFF8FAFC);

class UserListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const UserListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _searchController = TextEditingController();
  final _chatService = ChatService();
  String _searchQuery = '';

  List<Map<String, dynamic>> _uniqueUsers = [];
  bool _isLoading = true;
  String? _currentUserEmail;
  String? _currentUserCanonicalId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _getCurrentUserInfo();
    await _loadUniqueUsers();
  }

  Future<void> _getCurrentUserInfo() async {
    try {
      if (widget.currentUserId.startsWith('local_')) {
        _currentUserCanonicalId = widget.currentUserId;
        final localId = int.tryParse(widget.currentUserId.replaceFirst('local_', ''));
        if (localId != null) {
          final localUser = await DatabaseHelper().getUserById(localId);
          _currentUserEmail = localUser?['email'];
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final localId = data['localId'];
          _currentUserEmail = data['email'];
          if (localId != null) {
            _currentUserCanonicalId = 'local_$localId';
          } else {
            _currentUserCanonicalId = widget.currentUserId;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting current user info: $e');
    }
  }

  Future<void> _loadUniqueUsers() async {
    try {
      setState(() => _isLoading = true);

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final Map<String, Map<String, dynamic>> userMap = {};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final email = data['email'] as String?;
        final localId = data['localId'];
        final displayName = data['displayName'] as String? ?? '';

        if (email == null || email.isEmpty) continue;
        if (email == _currentUserEmail) continue;

        if (!userMap.containsKey(email)) {
          String name = displayName;
          if (name.isEmpty) {
            name = email.split('@')[0];
          }

          String canonicalId;
          if (localId != null) {
            canonicalId = 'local_$localId';
          } else {
            canonicalId = doc.id;
          }

          userMap[email] = {
            'id': doc.id,
            'canonicalId': canonicalId,
            'name': name,
            'email': email,
            'photoUrl': data['photoUrl'],
            'localId': localId,
          };
        }
      }

      List<Map<String, dynamic>> userList = userMap.values.toList();
      userList.sort((a, b) => a['name'].toLowerCase().compareTo(b['name'].toLowerCase()));

      if (mounted) {
        setState(() {
          _uniqueUsers = userList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openChat(String canonicalOtherId, String otherUserName) async {
    debugPrint('🟢 OPENING CHAT WITH: $otherUserName (ID: $canonicalOtherId)');
    debugPrint('🟢 CURRENT USER: ${widget.currentUserName} (ID: ${widget.currentUserId})');
    debugPrint('🟢 CURRENT CANONICAL: $_currentUserCanonicalId');

    // Make sure we have valid IDs
    if (canonicalOtherId.isEmpty) {
      debugPrint('❌ ERROR: otherUserId is empty!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Invalid user selected')),
      );
      return;
    }

    if (_currentUserCanonicalId == null || _currentUserCanonicalId!.isEmpty) {
      debugPrint('❌ ERROR: currentUserCanonicalId is empty!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Please logout and login again')),
      );
      return;
    }

    // Check if trying to chat with self
    if (_currentUserCanonicalId == canonicalOtherId) {
      debugPrint('❌ ERROR: Trying to chat with yourself!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself')),
      );
      return;
    }

    try {
      final convoId = await _chatService.getOrCreateConversation(
        currentUserId: _currentUserCanonicalId!,
        currentUserName: widget.currentUserName,
        otherUserId: canonicalOtherId,
        otherUserName: otherUserName,
      );

      debugPrint('🟢 CONVERSATION ID: $convoId');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId: convoId,
              currentUserId: _currentUserCanonicalId!,
              currentUserName: widget.currentUserName,
              otherPersonName: otherUserName,
              otherPersonId: canonicalOtherId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _kInk,
      title: const Text('New Message', style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUniqueUsers),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
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

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> filteredUsers = _uniqueUsers;

    if (_searchQuery.isNotEmpty) {
      filteredUsers = _uniqueUsers.where((user) {
        final name = user['name'].toLowerCase();
        final email = user['email'].toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadUniqueUsers,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filteredUsers.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: Colors.grey.shade100),
        itemBuilder: (context, i) {
          final user = filteredUsers[i];
          return _UserTile(
            userId: user['id'],
            name: user['name'],
            email: user['email'],
            onTap: () => _openChat(user['canonicalId'], user['name']),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline_rounded, size: 32, color: _kAccent),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty ? 'No users found for "$_searchQuery"' : 'No other users registered yet',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk),
          ),
          const SizedBox(height: 6),
          const Text('Users will appear here once they register', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String userId;
  final String name;
  final String email;
  final VoidCallback onTap;

  const _UserTile({required this.userId, required this.name, required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _UserListAvatar(userId: userId, name: name),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kInk)),
      subtitle: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: const Text('Message', style: TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600)),
      ),
      onTap: onTap,
    );
  }
}

class _UserListAvatar extends StatefulWidget {
  final String userId;
  final String name;
  const _UserListAvatar({required this.userId, required this.name});

  @override
  State<_UserListAvatar> createState() => _UserListAvatarState();
}

class _UserListAvatarState extends State<_UserListAvatar> {
  String? _photoUrl;
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final photoUrl = data['photoUrl'] as String?;
        final localId = data['localId'] as int?;

        if (localId != null) {
          final localUser = await DatabaseHelper().getUserById(localId);
          final pic = localUser?['profilePic'] as String?;
          if (pic != null && pic.isNotEmpty) {
            if (pic.startsWith('http')) {
              _photoUrl = pic;
            } else {
              _photoBase64 = pic;
            }
          }
        }

        if (_photoUrl == null && photoUrl != null && photoUrl.isNotEmpty) {
          _photoUrl = photoUrl;
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Avatar load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        return CircleAvatar(radius: 24, backgroundImage: MemoryImage(base64Decode(_photoBase64!)));
      } catch (_) {}
    }

    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundImage: NetworkImage(_photoUrl!));
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: _kAccent.withOpacity(0.12),
      child: Text(initials, style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}