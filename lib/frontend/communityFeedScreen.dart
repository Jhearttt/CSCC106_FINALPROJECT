import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/backend/commentsModal.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:flutter/material.dart';

// ─── Painters ─────────────────────────────────────────────────────────────────
class _FeedGeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p0 = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.15);
    final p1 = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.18);
    final p3 = Paint()..color = const Color(0xFFBBDEFB).withOpacity(0.25);

    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width * 0.50, 0)
      ..lineTo(0, size.height * 0.10)..close(), p0);
    canvas.drawPath(Path()..moveTo(size.width, 0)..lineTo(size.width, size.height * 0.08)
      ..lineTo(size.width * 0.60, 0)..close(), p1);
    canvas.drawPath(Path()..moveTo(size.width, size.height * 0.80)..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.50, size.height)..close(), p0);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.88)..lineTo(0, size.height)
      ..lineTo(size.width * 0.28, size.height)..close(), p3);
    _drawHexagon(canvas, Offset(size.width * 0.92, size.height * 0.30), size.width * 0.05, p1);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      i == 0 ? path.moveTo(center.dx + radius * cos(angle), center.dy + radius * sin(angle))
          : path.lineTo(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
    }
    path.close(); canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E88E5).withOpacity(0.06)..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = spacing; x < size.width; x += spacing)
      for (double y = spacing; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.4, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Community Feed Screen ────────────────────────────────────────────────────
class CommunityFeedScreen extends StatefulWidget {
  final int? localUserId;
  const CommunityFeedScreen({super.key, this.localUserId});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _typeFilter  = 'All';       // All / Help Request / Skill Offer
  String? _catFilter;                // null = all categories
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  final _categories = ['All', 'Programming', 'Academic', 'Design', 'Others'];
  final _typeFilters = ['All', 'Help Request', 'Skill Offer'];

  @override
  void initState() { super.initState(); _loadPosts(); }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper().getAllPosts(
      postType : _typeFilter == 'All' ? null : _typeFilter,
      category : (_catFilter == null || _catFilter == 'All') ? null : _catFilter,
    );
    if (mounted) setState(() { _posts = data; _loading = false; });
  }

  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) { _loadPosts(); return; }
    setState(() => _loading = true);
    final data = await DatabaseHelper().searchPosts(kw.trim());
    if (mounted) setState(() { _posts = data; _loading = false; });
  }

  void _deletePost(int postId) {
    AwesomeDialog(
      context: context, dialogType: DialogType.warning,
      title: 'Delete Post', desc: 'Are you sure you want to delete this post?',
      btnOkOnPress: () async {
        await DatabaseHelper().deletePost(postId);
        _loadPosts();
      },
      btnCancelOnPress: () {},
    ).show();
  }

  void _toggleStatus(int postId, String currentStatus) async {
    final newStatus = currentStatus == 'Open' ? 'Resolved' : 'Open';
    await DatabaseHelper().updatePostStatus(postId, newStatus);
    _loadPosts();
  }

  String _timeAgo(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
      if (diff.inDays < 1)     return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0F7FF), Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.68, 1.0],
        ),
      )),
      CustomPaint(painter: _FeedGeometricPainter(), child: const SizedBox.expand()),
      IgnorePointer(child: CustomPaint(painter: _DotGridPainter(), child: const SizedBox.expand())),

      SafeArea(
        child: Column(children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
                boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.10),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 14),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1E88E5), size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close_rounded, color: Color(0xFF90CAF9), size: 18),
                        onPressed: () { _searchCtrl.clear(); _loadPosts(); })
                        : null,
                    hintText: "Search posts...",
                    hintStyle: const TextStyle(color: Color(0xFF90CAF9), fontSize: 13.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),

          // ── Type filter tabs ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: _typeFilters.map((t) {
              final active = _typeFilter == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _typeFilter = t); _loadPosts(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF1E88E5) : Colors.white.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? const Color(0xFF1E88E5) : const Color(0xFF90CAF9), width: 1.2),
                      boxShadow: active ? [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.30),
                          blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? Colors.white : const Color(0xFF1976D2))),
                  ),
                ),
              );
            }).toList()),
          ),

          // ── Category filter ──
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final active = (_catFilter == null && cat == 'All') || _catFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _catFilter = cat == 'All' ? null : cat);
                      _loadPosts();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF0D47A1) : Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: active ? const Color(0xFF0D47A1) : const Color(0xFFBBDEFB)),
                      ),
                      child: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: active ? Colors.white : const Color(0xFF1976D2))),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Post count badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF90CAF9), width: 1.2)),
                child: Row(children: [
                  const Icon(Icons.circle, color: Color(0xFF1E88E5), size: 8),
                  const SizedBox(width: 6),
                  Text("${_posts.length} post${_posts.length != 1 ? 's' : ''}",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),

          // ── Posts list ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
                : _posts.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_rounded, color: const Color(0xFF90CAF9), size: 54),
              const SizedBox(height: 12),
              const Text("No posts found", style: TextStyle(color: Color(0xFF1976D2),
                  fontSize: 15, fontWeight: FontWeight.w600)),
            ]))
                : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _posts.length,
                itemBuilder: (context, index) => _buildPostCard(_posts[index]),
              ),
            ),
          ),
        ]),
      ),

      // ── FAB ──
      Positioned(
        bottom: 24, right: 20,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CreatePostScreen(localUserId: widget.localUserId))).then((_) => _loadPosts()),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF0D47A1)]),
              boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.45),
                  blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isOpen       = post['status'] == 'Open';
    final isHelpReq    = post['postType'] == 'Help Request';
    final isOwner      = widget.localUserId != null && post['userId'] == widget.localUserId;
    final initials     = (post['userFullName'] as String? ?? '?').isNotEmpty
        ? (post['userFullName'] as String)[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 5)),
          BoxShadow(color: Colors.white.withOpacity(0.70), blurRadius: 6, offset: const Offset(-2, -2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row: avatar + name + badges ──
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
                boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.30), blurRadius: 6)],
              ),
              child: Center(child: Text(initials, style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['userFullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: Color(0xFF0D47A1))),
              Text(_timeAgo(post['datePosted'] ?? ''), style: const TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
            ])),
            // Status badge
            GestureDetector(
              onTap: isOwner ? () => _toggleStatus(post['id'], post['status']) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isOpen ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isOpen ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7))),
                child: Text(post['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: isOpen ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32))),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // ── Title ──
          Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 15, color: Color(0xFF0D47A1))),
          const SizedBox(height: 4),

          // ── Description snippet ──
          Text(
            (post['description'] ?? '').length > 100
                ? '${(post['description'] as String).substring(0, 100)}...'
                : post['description'] ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2), height: 1.4),
          ),

          const SizedBox(height: 10),

          // ── Bottom row: type + category + actions ──
          Row(children: [
            _buildChip(
              isHelpReq ? Icons.help_outline_rounded : Icons.lightbulb_outline_rounded,
              post['postType'],
              isHelpReq ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9),
              isHelpReq ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 6),
            _buildChip(Icons.label_outline_rounded, post['category'],
                const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
            const SizedBox(width: 6),
// Comment button — visible to everyone
            GestureDetector(
              onTap: () => CommentsModal.show(
                context,
                postId: post['id'],
                localUserId: widget.localUserId,
                postTitle: post['title'] ?? '',
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.comment_outlined, color: Color(0xFF1E88E5), size: 13),
                  const SizedBox(width: 4),
                  const Text("Reply", style: TextStyle(fontSize: 11,
                      color: Color(0xFF1E88E5), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const Spacer(),
            if (isOwner) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CreatePostScreen(localUserId: widget.localUserId, existingPost: post)))
                    .then((_) => _loadPosts()),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50))),
                    child: const Icon(Icons.edit_rounded, color: Color(0xFF1E88E5), size: 15)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deletePost(post['id']),
                child: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEF9A9A).withOpacity(0.50))),
                    child: const Icon(Icons.delete_rounded, color: Color(0xFFD32F2F), size: 15)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}