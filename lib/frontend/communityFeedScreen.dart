import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/backend/commentsModal.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:flutter/material.dart';

// ─── Aurora Palette ───────────────────────────────────────────────────────────
const _kInk         = Color(0xFF1E1B4B);
const _kInkMid      = Color(0xFF4338CA);
const _kInkLight    = Color(0xFF818CF8);
const _kInkMuted    = Color(0xFFA5B4FC);
const _kViolet      = Color(0xFF7B6CF6);
const _kVioletLight = Color(0xFFA78BFA);
const _kVioletSoft  = Color(0xFFEDE9FE);
const _kBlush       = Color(0xFFF472B6);
const _kBlushSoft   = Color(0xFFFCE7F3);
const _kMint        = Color(0xFF34D399);
const _kMintSoft    = Color(0xFFD1FAE5);
const _kSky         = Color(0xFF60A5FA);
const _kSkySoft     = Color(0xFFDBEAFE);
const _kAmber       = Color(0xFFFCD34D);
const _kAmberSoft   = Color(0xFFFEF3C7);
const _kBorderGlass = Color(0xFFE0D9FF);
const _kBase        = Color(0xFFF0EEFF);

// ─── Aurora Mesh Background ───────────────────────────────────────────────────
class _AuroraMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)));
    }
    orb(Offset(size.width * 0.10, size.height * 0.05), size.width * 0.5, _kViolet, 0.18);
    orb(Offset(size.width * 0.92, size.height * 0.12), size.width * 0.4, const Color(0xFFC084FC), 0.15);
    orb(Offset(size.width * 0.88, size.height * 0.55), size.width * 0.35, _kBlush, 0.12);
    orb(Offset(size.width * 0.05, size.height * 0.82), size.width * 0.38, _kMint, 0.11);
    orb(Offset(size.width * 0.82, size.height * 0.90), size.width * 0.35, _kSky, 0.11);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _kViolet.withOpacity(0.05)..style = PaintingStyle.fill;
    const s = 26.0;
    for (double x = s; x < size.width; x += s)
      for (double y = s; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.3, p);
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
  // ── Original state ──
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _typeFilter  = 'All';
  String? _catFilter;
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  final _categories  = ['All', 'Programming', 'Academic', 'Design', 'Others'];
  final _typeFilters = ['All', 'Help Request', 'Skill Offer'];

  @override
  void initState() { super.initState(); _loadPosts(); }

  // ── Original methods ──
  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper().getAllPosts(
      postType: _typeFilter == 'All' ? null : _typeFilter,
      category: (_catFilter == null || _catFilter == 'All') ? null : _catFilter,
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
      btnOkOnPress: () async { await DatabaseHelper().deletePost(postId); _loadPosts(); },
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
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1)   return '${diff.inMinutes}m ago';
      if (diff.inDays < 1)    return '${diff.inHours}h ago';
      if (diff.inDays < 7)    return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // ── Aurora bg ──
      Container(decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
            Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.68, 1.0],
        ),
      )),
      CustomPaint(painter: _AuroraMeshPainter(), child: const SizedBox.expand()),
      IgnorePointer(child: CustomPaint(painter: _DotGridPainter(), child: const SizedBox.expand())),

      SafeArea(
        child: Column(children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.80),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _kBorderGlass, width: 1.2),
                boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                    blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: const TextStyle(color: _kInk, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, color: _kViolet, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: _kInkMuted, size: 18),
                    onPressed: () { _searchCtrl.clear(); _loadPosts(); },
                  ) : null,
                  hintText: "Search posts...",
                  hintStyle: const TextStyle(color: _kInkMuted, fontSize: 13.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ── Type filter tabs ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _typeFilters.map((t) {
                  final active = _typeFilter == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _typeFilter = t); _loadPosts(); },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: active
                              ? const LinearGradient(
                              colors: [_kViolet, _kVioletLight],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          color: active ? null : Colors.white.withOpacity(0.70),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? _kViolet : _kBorderGlass, width: 1.2),
                          boxShadow: active
                              ? [BoxShadow(color: _kViolet.withOpacity(0.28),
                              blurRadius: 10, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Text(t, style: TextStyle(fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _kInkLight)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
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
                        gradient: active
                            ? const LinearGradient(colors: [Color(0xFF4338CA), _kViolet],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)
                            : null,
                        color: active ? null : Colors.white.withOpacity(0.60),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: active ? _kInkMid : _kBorderGlass, width: 1),
                      ),
                      child: Text(cat, style: TextStyle(fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _kInkMuted)),
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
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kViolet.withOpacity(0.25), width: 1),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: _kViolet, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text("${_posts.length} post${_posts.length != 1 ? 's' : ''}",
                      style: const TextStyle(fontSize: 12, color: _kInkMid,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),

          // ── Posts list ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kViolet))
                : _posts.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_rounded, color: _kInkMuted, size: 54),
              const SizedBox(height: 12),
              const Text("No posts found",
                  style: TextStyle(color: _kInkLight, fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ]))
                : RefreshIndicator(
              onRefresh: _loadPosts,
              color: _kViolet,
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
              builder: (_) => CreatePostScreen(localUserId: widget.localUserId)))
              .then((_) => _loadPosts()),
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(color: _kViolet.withOpacity(0.40),
                    blurRadius: 18, offset: const Offset(0, 7)),
                BoxShadow(color: _kBlush.withOpacity(0.20),
                    blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final isOpen    = post['status'] == 'Open';
    final isHelpReq = post['postType'] == 'Help Request';
    final isOwner   = widget.localUserId != null && post['userId'] == widget.localUserId;
    final initials  = (post['userFullName'] as String? ?? '?').isNotEmpty
        ? (post['userFullName'] as String)[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorderGlass, width: 1.2),
        boxShadow: [
          BoxShadow(color: _kViolet.withOpacity(0.08),
              blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.white.withOpacity(0.80),
              blurRadius: 6, offset: const Offset(-2, -2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row: avatar + name + status ──
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [_kViolet, _kVioletLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.30), blurRadius: 8)],
              ),
              child: Center(child: Text(initials, style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['userFullName'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 13.5, color: _kInk)),
                  Text(_timeAgo(post['datePosted'] ?? ''),
                      style: const TextStyle(fontSize: 11, color: _kInkMuted)),
                ])),
            // Status badge — tap to toggle (owner only)
            GestureDetector(
              onTap: isOwner ? () => _toggleStatus(post['id'], post['status']) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isOpen
                      ? const LinearGradient(colors: [Color(0xFFFCE7F3), Color(0xFFFBCFE8)])
                      : const LinearGradient(colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isOpen ? _kBlush.withOpacity(0.40) : _kMint.withOpacity(0.40),
                      width: 1),
                ),
                child: Text(post['status'], style: TextStyle(fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isOpen ? const Color(0xFF9D174D) : const Color(0xFF065F46))),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // ── Title ──
          Text(post['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 15, color: _kInk, letterSpacing: -0.2)),

          const SizedBox(height: 4),

          // ── Description snippet ──
          Text(
            (post['description'] ?? '').length > 100
                ? '${(post['description'] as String).substring(0, 100)}...'
                : post['description'] ?? '',
            style: const TextStyle(fontSize: 13, color: _kInkLight, height: 1.45),
          ),

          const SizedBox(height: 10),

          // ── Bottom chips + actions ──
          Row(children: [
            _chip(
              isHelpReq ? Icons.help_outline_rounded : Icons.lightbulb_outline_rounded,
              post['postType'],
              isHelpReq ? _kSkySoft : _kMintSoft,
              isHelpReq ? _kSky : _kMint,
            ),
            const SizedBox(width: 6),
            _chip(Icons.label_outline_rounded, post['category'],
                _kVioletSoft, _kVioletLight),
            const SizedBox(width: 6),
            // Comment / reply button
            GestureDetector(
              onTap: () => CommentsModal.show(context,
                  postId: post['id'], localUserId: widget.localUserId,
                  postTitle: post['title'] ?? ''),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kViolet.withOpacity(0.25), width: 1),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.comment_outlined, color: _kViolet, size: 13),
                  SizedBox(width: 4),
                  Text("Reply", style: TextStyle(fontSize: 11,
                      color: _kViolet, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const Spacer(),
            if (isOwner) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CreatePostScreen(
                        localUserId: widget.localUserId, existingPost: post)))
                    .then((_) => _loadPosts()),
                child: _iconBtn(Icons.edit_rounded, _kSkySoft, _kSky),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deletePost(post['id']),
                child: _iconBtn(Icons.delete_rounded, _kBlushSoft, _kBlush),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5,
            fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: bg, shape: BoxShape.circle,
          border: Border.all(color: fg.withOpacity(0.30), width: 1)),
      child: Icon(icon, color: fg, size: 15),
    );
  }
}