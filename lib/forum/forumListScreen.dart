import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:final_project/services/forumService.dart';
import 'forumDetailScreen.dart';
import 'package:final_project/chat/createRoomScreen.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk    = Color(0xFF1E1B4B);
const _kBg     = Color(0xFFF8FAFC);

// Category metadata
const _kCategoryMeta = {
  'All':         {'icon': Icons.apps_rounded,            'color': Color(0xFF6366F1)},
  'General':     {'icon': Icons.forum_rounded,           'color': Color(0xFF6366F1)},
  'Math':        {'icon': Icons.calculate_rounded,       'color': Color(0xFF8B5CF6)},
  'Science':     {'icon': Icons.science_rounded,         'color': Color(0xFF06B6D4)},
  'Programming': {'icon': Icons.code_rounded,            'color': Color(0xFF10B981)},
  'Design':      {'icon': Icons.palette_rounded,         'color': Color(0xFFEC4899)},
  'Business':    {'icon': Icons.business_center_rounded, 'color': Color(0xFFF59E0B)},
  'Language':    {'icon': Icons.translate_rounded,       'color': Color(0xFF3B82F6)},
  'Engineering': {'icon': Icons.engineering_rounded,     'color': Color(0xFFEF4444)},
  'Other':       {'icon': Icons.more_horiz_rounded,      'color': Color(0xFF9CA3AF)},
};

class ForumListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ForumListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<ForumListScreen> createState() => _ForumListScreenState();
}

class _ForumListScreenState extends State<ForumListScreen>
    with SingleTickerProviderStateMixin {
  final _forumService    = ForumService();
  final _searchCtrl      = TextEditingController();
  String _searchQuery    = '';
  String _selectedCat    = 'All';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Category filter chip ───────────────────────────────────────────────────
  Widget _categoryChip(String cat) {
    final meta    = _kCategoryMeta[cat] ?? _kCategoryMeta['Other']!;
    final color   = meta['color'] as Color;
    final icon    = meta['icon'] as IconData;
    final selected = _selectedCat == cat;

    return GestureDetector(
      onTap: () => setState(() => _selectedCat = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:  selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.shade200, width: 1.2),
          boxShadow: selected ? [BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : color),
          const SizedBox(width: 5),
          Text(cat, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _kInk)),
        ]),
      ),
    );
  }

  // ── Filter forums by search + category ────────────────────────────────────
  List<QueryDocumentSnapshot> _filter(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data  = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toLowerCase();
      final desc  = (data['description'] ?? '').toLowerCase();
      final cat   = data['category'] ?? '';

      final matchSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery) ||
          desc.contains(_searchQuery);
      final matchCat = _selectedCat == 'All' || cat == _selectedCat;

      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,

      // ── Search bar ─────────────────────────────────────────────────────────
      body: Column(children: [
        // Search + create button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(fontSize: 14, color: _kInk),
                  decoration: InputDecoration(
                    hintText: 'Search forums...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Colors.grey, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 18),
                    ) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Create room button
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CreateRoomScreen(
                  currentUserId:   widget.currentUserId,
                  currentUserName: widget.currentUserName,
                ),
              )),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _kAccent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: _kAccent.withOpacity(0.30),
                      blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),

        // Category filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 0, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _kCategoryMeta.keys
                  .map(_categoryChip)
                  .toList(),
            ),
          ),
        ),

        // Tabs: All Forums / My Forums
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _kAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _kAccent,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'All Forums'),
              Tab(text: 'My Forums'),
            ],
          ),
        ),

        // ── Tab content ───────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // All forums
              _ForumList(
                stream: _forumService.getForums(),
                filter: _filter,
                currentUserId:   widget.currentUserId,
                currentUserName: widget.currentUserName,
                emptyTitle:   'No forums yet',
                emptySubtitle: 'Be the first to create one!',
              ),
              // My forums
              _ForumList(
                stream: _forumService.getMyForums(widget.currentUserId),
                filter: _filter,
                currentUserId:   widget.currentUserId,
                currentUserName: widget.currentUserName,
                emptyTitle:    'No joined forums',
                emptySubtitle: 'Join a forum to see it here.',
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Forum list builder ─────────────────────────────────────────────────────
class _ForumList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final List<QueryDocumentSnapshot> Function(List<QueryDocumentSnapshot>) filter;
  final String currentUserId;
  final String currentUserName;
  final String emptyTitle;
  final String emptySubtitle;

  const _ForumList({
    required this.stream,
    required this.filter,
    required this.currentUserId,
    required this.currentUserName,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // ADD THESE 3 LINES
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }


        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = filter(snapshot.data!.docs);

        if (filtered.isEmpty) {
          return _EmptyState(title: emptyTitle, subtitle: emptySubtitle);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final doc  = filtered[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ForumCard(
              forumId:         doc.id,
              data:            data,
              currentUserId:   currentUserId,
              currentUserName: currentUserName,
            );
          },
        );
      },
    );
  }
}

// ── Forum Card ─────────────────────────────────────────────────────────────
class _ForumCard extends StatelessWidget {
  final String forumId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final String currentUserName;

  const _ForumCard({
    required this.forumId,
    required this.data,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    final forumService = ForumService();
    final title        = data['title']       ?? 'Untitled';
    final description  = data['description'] ?? '';
    final category     = data['category']    ?? 'General';
    final memberCount  = data['memberCount'] ?? 0;
    final postCount    = data['postCount']   ?? 0;
    final isPrivate    = data['isPrivate']   ?? false;
    final members      = List<String>.from(data['members'] ?? []);
    final isMember     = members.contains(currentUserId);
    final lastMessage  = data['lastMessage'] ?? '';
    final lastBy       = data['lastMessageBy'] ?? '';

    final meta  = _kCategoryMeta[category] ?? _kCategoryMeta['Other']!;
    final color = meta['color'] as Color;
    final icon  = meta['icon'] as IconData;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ForumDetailScreen(
          forumId:         forumId,
          forumTitle:      title,
          currentUserId:   currentUserId,
          currentUserName: currentUserName,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              // Category icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),

              // Title + badges
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15, color: _kInk),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (isPrivate)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.lock_rounded,
                                  size: 10, color: Colors.grey.shade500),
                              const SizedBox(width: 3),
                              Text('Private', style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(category, style: TextStyle(
                            fontSize: 10, color: color,
                            fontWeight: FontWeight.w600)),
                      ),
                    ]),
              ),
            ]),
          ),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(description,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

          // Last message preview
          if (lastMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    lastBy.isNotEmpty ? '$lastBy: $lastMessage' : lastMessage,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),

          // ── Bottom row: stats + join button ───────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(children: [
              // Members
              Icon(Icons.people_outline_rounded,
                  size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('$memberCount',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              // Posts
              Icon(Icons.chat_outlined,
                  size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('$postCount posts',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600)),
              const Spacer(),

              // Join / Leave button
              GestureDetector(
                onTap: () async {
                  if (isMember) {
                    await forumService.leaveForum(forumId, currentUserId);
                  } else {
                    await forumService.joinForum(forumId, currentUserId);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isMember
                        ? Colors.grey.shade100
                        : _kAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isMember ? 'Joined ✓' : 'Join',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isMember ? Colors.grey.shade600 : Colors.white,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.forum_outlined,
              size: 32, color: _kAccent),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(
            fontSize: 13, color: Colors.grey)),
      ]),
    );
  }
}