import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/backend/commentsModal.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/notificationsScreen.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:final_project/services/connectivityService.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kInk = Color(0xFF1E1B4B);
const _kInkMid = Color(0xFF4338CA);
const _kInkLight = Color(0xFF818CF8);
const _kInkMuted = Color(0xFFA5B4FC);
const _kViolet = Color(0xFF7B6CF6);
const _kVioletLight = Color(0xFFA78BFA);
const _kVioletSoft = Color(0xFFEDE9FE);
const _kBlush = Color(0xFFF472B6);
const _kBlushSoft = Color(0xFFFCE7F3);
const _kMint = Color(0xFF34D399);
const _kMintSoft = Color(0xFFD1FAE5);
const _kSky = Color(0xFF60A5FA);
const _kSkySoft = Color(0xFFDBEAFE);
const _kBorderGlass = Color(0xFFE0D9FF);

// ─── Background painters ──────────────────────────────────────────────────────
class _AuroraMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    orb(
      Offset(size.width * 0.10, size.height * 0.05),
      size.width * 0.5,
      _kViolet,
      0.18,
    );
    orb(
      Offset(size.width * 0.92, size.height * 0.12),
      size.width * 0.4,
      const Color(0xFFC084FC),
      0.15,
    );
    orb(
      Offset(size.width * 0.88, size.height * 0.55),
      size.width * 0.35,
      _kBlush,
      0.12,
    );
    orb(
      Offset(size.width * 0.05, size.height * 0.82),
      size.width * 0.38,
      _kMint,
      0.11,
    );
    orb(
      Offset(size.width * 0.82, size.height * 0.90),
      size.width * 0.35,
      _kSky,
      0.11,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _kViolet.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    const s = 26.0;
    for (double x = s; x < size.width; x += s)
      for (double y = s; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.3, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Staggered entrance animation ────────────────────────────────────────────
class _AnimatedPostCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedPostCard({required this.child, required this.index});
  @override
  State<_AnimatedPostCard> createState() => _AnimatedPostCardState();
}

class _AnimatedPostCardState extends State<_AnimatedPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 55 * (widget.index % 8)), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ─── Image widget: handles base64 data URIs and network URLs ─────────────────
// Same pattern as profileScreen._ProfilePostImage — safe, no null crashes.
class _PostImage extends StatelessWidget {
  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _PostImage({
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return _broken();
    if (src.startsWith('data:image')) {
      try {
        final comma = src.indexOf(',');
        if (comma == -1) return _broken();
        final bytes = base64Decode(src.substring(comma + 1));
        return Image.memory(
          bytes,
          width: width ?? double.infinity,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _broken(),
        );
      } catch (_) {
        return _broken();
      }
    }
    return Image.network(
      src,
      width: width ?? double.infinity,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => _broken(),
    );
  }

  Widget _broken() => Container(
    width: width,
    height: height ?? 60,
    color: _kVioletSoft,
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: _kVioletLight, size: 22),
    ),
  );
}

// ─── Community Feed Screen ────────────────────────────────────────────────────
class CommunityFeedScreen extends StatefulWidget {
  final int? localUserId;
  final int? initialPostId;
  const CommunityFeedScreen({super.key, this.localUserId, this.initialPostId});
  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _isOnline = true;
  String _typeFilter = 'All';
  String? _catFilter;
  int _unreadCount = 0;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final _categories = ['All', 'Programming', 'Academic', 'Design', 'Others'];
  final _typeFilters = ['All', 'Help Request', 'Skill Offer'];

  StreamSubscription<QuerySnapshot>? _firestoreSub;
  StreamSubscription<bool>? _connectivitySub;

  int _pendingNewPosts = 0;
  bool _showNewBanner = false;

  late AnimationController _bannerCtrl;
  late Animation<Offset> _bannerSlide;

  @override
  void initState() {
    super.initState();
    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutCubic));
    _isOnline = ConnectivityService.instance.isOnline;
    _connectivitySub = ConnectivityService.instance.onStatusChange.listen((
      online,
    ) {
      if (mounted) setState(() => _isOnline = online);
    });
    _loadPosts();
    _startRealtimeListener();
    DatabaseHelper.profilePicVersion.addListener(_loadPosts);
  }

  @override
  void dispose() {
    DatabaseHelper.profilePicVersion.removeListener(_loadPosts);
    _firestoreSub?.cancel();
    _connectivitySub?.cancel();
    _bannerCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadPosts() async {
    if (mounted) setState(() => _loading = true);
    try {
      await DatabaseHelper().checkAndBoostExpiredPosts();
      await DatabaseHelper().syncCommentCounts();
      await SyncService.instance.pullPostsFromFirestore();
      await _queryLocal();
      await _loadUnreadCount();
      
      // Scroll to specific post if initialPostId is provided
      if (widget.initialPostId != null) {
        _scrollToPost(widget.initialPostId!);
      }
    } catch (e, stack) {
      debugPrint('[CommunityFeed] _loadPosts error: $e\n$stack');
      try {
        await _queryLocal();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUnreadCount() async {
    if (widget.localUserId == null) return;
    final count = await DatabaseHelper().getUnreadNotificationCount(
      widget.localUserId!,
    );
    if (mounted) setState(() => _unreadCount = count);
  }

  // Scroll to specific post by ID
  void _scrollToPost(int postId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postIndex = _posts.indexWhere((post) => post['id'] == postId);
      if (postIndex != -1 && _scrollCtrl.hasClients) {
        // Calculate approximate position (each post has roughly 200px height)
        final estimatedOffset = postIndex * 200.0;
        _scrollCtrl.animateTo(
          estimatedOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
        
        // Highlight the post (optional visual feedback)
        setState(() {
          // Could add a highlight state here if needed
        });
      }
    });
  }

  Future<void> _queryLocal() async {
    try {
      final raw = await DatabaseHelper().getAllPosts(
        postType: _typeFilter == 'All' ? null : _typeFilter,
        category: (_catFilter == null || _catFilter == 'All')
            ? null
            : _catFilter,
      );
      int urgencyRank(String u) => u == 'High'
          ? 0
          : u == 'Medium'
          ? 1
          : 2;
      final open = raw.where((p) => p['status'] != 'Resolved').toList()
        ..sort((a, b) {
          final uA = urgencyRank(a['urgencyLevel'] as String? ?? 'Low');
          final uB = urgencyRank(b['urgencyLevel'] as String? ?? 'Low');
          if (uA != uB) return uA.compareTo(uB);
          return (b['datePosted'] as String? ?? '').compareTo(
            a['datePosted'] as String? ?? '',
          );
        });
      final resolved = raw.where((p) => p['status'] == 'Resolved').toList()
        ..sort(
          (a, b) => (b['datePosted'] as String? ?? '').compareTo(
            a['datePosted'] as String? ?? '',
          ),
        );
      if (mounted) setState(() => _posts = [...open, ...resolved]);
    } catch (e) {
      debugPrint('[CommunityFeed] _queryLocal error: $e');
      if (mounted) setState(() => _posts = []);
    }
  }

  // ── Real-time Firestore stream ────────────────────────────────────────────
  void _startRealtimeListener() {
    _firestoreSub = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('datePosted', descending: true)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;
          final added = snapshot.docChanges
              .where((c) => c.type == DocumentChangeType.added)
              .length;
          if (added > 0 && !_loading) {
            await SyncService.instance.pullPostsFromFirestore();
            if (mounted) {
              setState(() {
                _pendingNewPosts += added;
                _showNewBanner = true;
              });
              _bannerCtrl.forward();
            }
          }
          final changed = snapshot.docChanges.any(
            (c) =>
                c.type == DocumentChangeType.modified ||
                c.type == DocumentChangeType.removed,
          );
          if (changed && !_loading) await _queryLocal();
        }, onError: (_) {});
  }

  Future<void> _applyNewPosts() async {
    _bannerCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _pendingNewPosts = 0;
      _showNewBanner = false;
    });
    await _queryLocal();
  }

  // ── Search ────────────────────────────────────────────────────────────────
  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) {
      _loadPosts();
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final raw = await DatabaseHelper().searchPosts(kw.trim());
      int urgencyRank(String u) => u == 'High'
          ? 0
          : u == 'Medium'
          ? 1
          : 2;
      final open = raw.where((p) => p['status'] != 'Resolved').toList()
        ..sort((a, b) {
          final uA = urgencyRank(a['urgencyLevel'] as String? ?? 'Low');
          final uB = urgencyRank(b['urgencyLevel'] as String? ?? 'Low');
          if (uA != uB) return uA.compareTo(uB);
          return (b['datePosted'] as String? ?? '').compareTo(
            a['datePosted'] as String? ?? '',
          );
        });
      final resolved = raw.where((p) => p['status'] == 'Resolved').toList();
      if (mounted) setState(() => _posts = [...open, ...resolved]);
    } catch (e) {
      debugPrint('[CommunityFeed] _search error: $e');
      if (mounted) setState(() => _posts = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  void _deletePost(int postId) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      title: 'Delete Post',
      desc: 'Are you sure you want to delete this post?',
      btnOkOnPress: () async {
        await SyncService.instance.deletePost(postId);
        _queryLocal();
      },
      btnCancelOnPress: () {},
    ).show();
  }

  // ── Toggle status ──────────────────────────────────────────────────────────
  void _toggleStatus(int postId, String current) async {
    if (current != 'Resolved') return;
    await SyncService.instance.updatePostStatus(postId, 'Open');
    _queryLocal();
  }

  // ── Navigate to create post ───────────────────────────────────────────────
  void _goToCreate({Map<String, dynamic>? existingPost}) {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) => CreatePostScreen(
              localUserId: widget.localUserId,
              existingPost: existingPost,
            ),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            transitionDuration: const Duration(milliseconds: 380),
          ),
        )
        .then((_) => _loadPosts());
  }

  // ── Open post detail ──────────────────────────────────────────────────────
  void _openPostDetail(Map<String, dynamic> post) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PostDetail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => PostDetailCard(
        post: post,
        localUserId: widget.localUserId,
        onToggleStatus: (id, current) {
          Navigator.pop(ctx);
          _toggleStatus(id, current);
        },
        onDelete: (id) {
          Navigator.pop(ctx);
          _deletePost(id);
        },
        onEdit: (p) {
          Navigator.pop(ctx);
          _goToCreate(existingPost: p);
        },
      ),
    );
  }

  // ── Full screen image viewer ──────────────────────────────────────────────
  void _openFullScreenImage(BuildContext ctx, String src) {
    Navigator.of(ctx).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(color: Colors.black87),
                ),
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _PostImage(src: src, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 48,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.30),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF0EEFF),
                Color(0xFFF5F0FF),
                Color(0xFFFFF0FA),
                Color(0xFFEEFBF5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.35, 0.68, 1.0],
            ),
          ),
        ),
        CustomPaint(
          painter: _AuroraMeshPainter(),
          child: const SizedBox.expand(),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _DotGridPainter(),
            child: const SizedBox.expand(),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      "Community Feed",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    // Bell
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(
                            localUserId: widget.localUserId,
                          ),
                        ),
                      ).then((_) => _loadUnreadCount()),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (_unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 17,
                                height: 17,
                                decoration: const BoxDecoration(
                                  color: _kBlush,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Connectivity badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (_isOnline ? _kMint : Colors.orange).withOpacity(
                          0.12,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (_isOnline ? _kMint : Colors.orange)
                              .withOpacity(0.40),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isOnline ? _kMint : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isOnline ? 'Live' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isOnline
                                  ? const Color(0xFF065F46)
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.80),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _kBorderGlass, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: _kViolet.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _search,
                    style: const TextStyle(color: _kInk, fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _kViolet,
                        size: 20,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _kInkMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadPosts();
                              },
                            )
                          : null,
                      hintText: "Search posts...",
                      hintStyle: const TextStyle(
                        color: _kInkMuted,
                        fontSize: 13.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // ── Type filter tabs ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _typeFilters.map((t) {
                      final active = _typeFilter == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _typeFilter = t);
                            _loadPosts();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(
                                      colors: [_kViolet, _kVioletLight],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: active
                                  ? null
                                  : Colors.white.withOpacity(0.70),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active ? _kViolet : _kBorderGlass,
                                width: 1.2,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: _kViolet.withOpacity(0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : _kInkLight,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // ── Category chips ──
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final active =
                        (_catFilter == null && cat == 'All') ||
                        _catFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(
                            () => _catFilter = cat == 'All' ? null : cat,
                          );
                          _loadPosts();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: active
                                ? const LinearGradient(
                                    colors: [Color(0xFF4338CA), _kViolet],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: active
                                ? null
                                : Colors.white.withOpacity(0.60),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? _kInkMid : _kBorderGlass,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : _kInkMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Post count ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kViolet.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _kViolet,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_posts.length} post${_posts.length != 1 ? 's' : ''}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kInkMid,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Feed ──
              Expanded(
                child: Stack(
                  children: [
                    _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _kViolet),
                          )
                        : _posts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadPosts,
                            color: _kViolet,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _posts.length,
                              itemBuilder: (_, i) => _AnimatedPostCard(
                                index: i,
                                child: _buildPostCard(_posts[i]),
                              ),
                            ),
                          ),
                    // New posts banner
                    if (_showNewBanner)
                      Positioned(
                        top: 8,
                        left: 16,
                        right: 16,
                        child: SlideTransition(
                          position: _bannerSlide,
                          child: GestureDetector(
                            onTap: _applyNewPosts,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_kViolet, _kVioletLight],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kViolet.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_pendingNewPosts new post'
                                    '${_pendingNewPosts != 1 ? 's' : ''} — tap to load',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── FAB ──
        Positioned(
          bottom: 24,
          right: 20,
          child: GestureDetector(
            onTap: () => _goToCreate(),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kViolet.withOpacity(0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                    BoxShadow(
                      color: _kBlush.withOpacity(0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _kViolet.withOpacity(0.15),
                    _kBlush.withOpacity(0.10),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, color: _kViolet, size: 38),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No posts yet",
            style: TextStyle(
              color: _kInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Be the first to post something!",
            style: TextStyle(color: _kInkMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _goToCreate(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kViolet, _kVioletLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kViolet.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Create a post",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Post card ─────────────────────────────────────────────────────────────
  Widget _buildPostCard(Map<String, dynamic> post) {
    // All fields extracted safely up front — same pattern as profileScreen
    final status = post['status'] as String? ?? 'Open';
    final postType = post['postType'] as String? ?? 'Help Request';
    final category = post['category'] as String? ?? 'Others';
    final title = post['title'] as String? ?? '';
    final desc = post['description'] as String? ?? '';
    final fullName = post['userFullName'] as String? ?? 'Unknown';
    final datePosted = post['datePosted'] as String? ?? '';
    final urgency = post['urgencyLevel'] as String? ?? 'Low';
    final isBoosted = (post['isBoosted'] as int? ?? 0) == 1;
    final photoUrl = post['userProfilePic'] as String?;
    final imgUrl = post['imageUrl'] as String?;
    final isOpen = status == 'Open';
    final isHelpReq = postType == 'Help Request';
    final isOwner =
        widget.localUserId != null && post['userId'] == widget.localUserId;
    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final urgencyColor = urgency == 'High'
        ? _kBlush
        : urgency == 'Medium'
        ? const Color(0xFFFCD34D)
        : _kMint;

    return GestureDetector(
      onTap: () => _openPostDetail(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isBoosted
              ? const Color(0xFFFFFBEB).withOpacity(0.95)
              : isOpen
              ? Colors.white.withOpacity(0.82)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isBoosted
                ? const Color(0xFFFCD34D).withOpacity(0.50)
                : !isOpen
                ? _kMint.withOpacity(0.30)
                : _kBorderGlass,
            width: isBoosted ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _kViolet.withOpacity(isOpen ? 0.08 : 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar + author + badges ──
              Row(
                children: [
                  _buildAvatar(photoUrl, initials, 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isBoosted)
                              const Text('🚀 ', style: TextStyle(fontSize: 10)),
                            Flexible(
                              child: Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _kInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _timeAgo(datePosted),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _kInkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Urgency badge
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: urgencyColor.withOpacity(0.40),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          urgency == 'High'
                              ? Icons.arrow_upward_rounded
                              : urgency == 'Medium'
                              ? Icons.remove_rounded
                              : Icons.arrow_downward_rounded,
                          size: 9,
                          color: urgencyColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          urgency,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: urgencyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: isOpen
                          ? const LinearGradient(
                              colors: [Color(0xFFFCE7F3), Color(0xFFFBCFE8)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOpen
                            ? _kBlush.withOpacity(0.40)
                            : _kMint.withOpacity(0.40),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOpen
                            ? const Color(0xFF9D174D)
                            : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              // ── Title + description + thumbnail ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: isOpen ? _kInk : _kInkLight,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc.length > (hasImage ? 60 : 90)
                              ? '${desc.substring(0, hasImage ? 60 : 90)}...'
                              : desc,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isOpen ? _kInkLight : _kInkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Side thumbnail — only if image exists
                  if (hasImage) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openFullScreenImage(context, imgUrl),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _PostImage(
                              src: imgUrl,
                              width: 72,
                              height: 72,
                            ),
                          ),
                          // Gradient + expand icon overlay
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.35),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.only(bottom: 5),
                                child: const Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          // Border
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _kBorderGlass,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              // ── Chips + comment count + owner actions ──
              Row(
                children: [
                  _chip(
                    isHelpReq
                        ? Icons.help_outline_rounded
                        : Icons.lightbulb_outline_rounded,
                    postType,
                    isHelpReq ? _kSkySoft : _kMintSoft,
                    isHelpReq ? _kSky : _kMint,
                  ),
                  const SizedBox(width: 6),
                  _chip(
                    Icons.label_outline_rounded,
                    category,
                    _kVioletSoft,
                    _kVioletLight,
                  ),
                  const SizedBox(width: 6),
                  // Comment count pill
                  Builder(
                    builder: (_) {
                      final count = post['commentCount'] as int? ?? 0;
                      final hasComments = count > 0;
                      return GestureDetector(
                        onTap: () => CommentsModal.show(
                          context,
                          postId: post['id'],
                          localUserId: widget.localUserId,
                          postTitle: title,
                          postOwnerId: post['userId'] as int?,
                          postCategory: category,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: hasComments
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF7B6CF6),
                                      Color(0xFFA78BFA),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: hasComments ? null : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: hasComments
                                  ? _kViolet.withOpacity(0.0)
                                  : _kBorderGlass,
                              width: 1.2,
                            ),
                            boxShadow: hasComments
                                ? [
                                    BoxShadow(
                                      color: _kViolet.withOpacity(0.22),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasComments
                                    ? Icons.chat_bubble_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                color: hasComments ? Colors.white : _kInkMuted,
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasComments
                                    ? '$count ${count == 1 ? 'comment' : 'comments'}'
                                    : 'Comment',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: hasComments
                                      ? Colors.white
                                      : _kInkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String initial, double size) {
    ImageProvider? img;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        img = NetworkImage(photoUrl);
      } else {
        try {
          img = MemoryImage(base64Decode(photoUrl));
        } catch (_) {}
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_kViolet, _kVioletLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: _kViolet.withOpacity(0.28), blurRadius: 6),
        ],
        image: img != null
            ? DecorationImage(image: img, fit: BoxFit.cover)
            : null,
      ),
      child: img == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );

  Widget _iconBtn(IconData icon, Color bg, Color fg) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      border: Border.all(color: fg.withOpacity(0.30), width: 1),
    ),
    child: Icon(icon, color: fg, size: 14),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  Post Detail Floating Card
// ══════════════════════════════════════════════════════════════════════════════
class PostDetailCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int? localUserId;
  final void Function(int id, String current) onToggleStatus;
  final void Function(int id) onDelete;
  final void Function(Map<String, dynamic> post) onEdit;

  const PostDetailCard({
    required this.post,
    required this.localUserId,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Extract all fields safely first — no inline casts
    final status = post['status'] as String? ?? 'Open';
    final postType = post['postType'] as String? ?? 'Help Request';
    final category = post['category'] as String? ?? 'Others';
    final title = post['title'] as String? ?? '';
    final desc = post['description'] as String? ?? '';
    final fullName = post['userFullName'] as String? ?? 'Unknown';
    final imgUrl = post['imageUrl'] as String?;
    final urgency = post['urgencyLevel'] as String? ?? 'Low';
    final photoUrl = post['userProfilePic'] as String?;
    final isOpen = status == 'Open';
    final isHelpReq = postType == 'Help Request';
    final isOwner = localUserId != null && post['userId'] == localUserId;
    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final urgencyColor = urgency == 'High'
        ? _kBlush
        : urgency == 'Medium'
        ? const Color(0xFFFCD34D)
        : _kMint;
    final resolverName = post['resolvedByName'] as String?;
    final resolverId = post['resolvedById'] as int?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F2FF),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _kViolet.withOpacity(0.20),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(photoUrl, initials, 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final authorId = post['userId'] as int?;
                              if (authorId != null) {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      localUserId: authorId,
                                      isOwnProfile: false,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: _kViolet,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 12,
                                  color: _kVioletLight,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          _timeAgoText(post['datePosted'] as String? ?? ''),
                        ],
                      ),
                    ),
                    if (isOwner)
                      OwnerMenu(
                        post: post,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onToggle: onToggleStatus,
                      ),
                    if (!isOwner)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _kVioletSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _kViolet,
                            size: 17,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Badges ──
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(
                      isHelpReq
                          ? Icons.help_outline_rounded
                          : Icons.lightbulb_outline_rounded,
                      postType,
                      isHelpReq ? _kSky : _kMint,
                    ),
                    _badge(
                      Icons.label_outline_rounded,
                      category,
                      _kVioletLight,
                    ),
                    _badge(
                      null,
                      urgency,
                      urgencyColor,
                      bg: urgencyColor.withOpacity(0.12),
                    ),
                    _badge(
                      null,
                      status,
                      isOpen
                          ? const Color(0xFF9D174D)
                          : const Color(0xFF065F46),
                      bg: isOpen
                          ? const Color(0xFFFCE7F3)
                          : const Color(0xFFD1FAE5),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: _kInk,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _kInkLight,
                    height: 1.55,
                  ),
                ),

                // ── Image: tap to expand ──
                if (hasImage) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierColor: Colors.black87,
                          pageBuilder: (ctx, anim, __) => FadeTransition(
                            opacity: anim,
                            child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Container(color: Colors.black87),
                                  ),
                                  Center(
                                    child: InteractiveViewer(
                                      minScale: 0.5,
                                      maxScale: 4.0,
                                      child: _PostImage(
                                        src: imgUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 48,
                                    right: 16,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.30,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _PostImage(src: imgUrl!, fit: BoxFit.cover),
                        ),
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.28),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Expand",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Resolved by ──
                if (!isOpen) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kMint.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _kMint.withOpacity(0.30),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: _kMint,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Resolved",
                          style: TextStyle(
                            color: _kMint,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        if (resolverName != null) ...[
                          const Text(
                            " by ",
                            style: TextStyle(color: _kInkMuted, fontSize: 12.5),
                          ),
                          GestureDetector(
                            onTap: resolverId != null
                                ? () {
                                    Navigator.pop(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          localUserId: resolverId,
                                          isOwnProfile: false,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  resolverName,
                                  style: const TextStyle(
                                    color: _kViolet,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _kViolet,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 11,
                                  color: _kVioletLight,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── Reply button ──
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      CommentsModal.show(
                        context,
                        postId: post['id'],
                        localUserId: localUserId,
                        postTitle: title,
                        postOwnerId: post['userId'] as int?,
                        postCategory: category,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _kViolet.withOpacity(0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "View & Reply",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Owner actions ──
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  if (isOpen)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _kVioletSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kViolet.withOpacity(0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: _kViolet,
                            size: 15,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "To resolve this post, tap \"View & Reply\" and accept the best answer.",
                              style: TextStyle(
                                fontSize: 12,
                                color: _kViolet,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isOpen)
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: () => onToggleStatus(post['id'], status),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _kBlush.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _kBlush.withOpacity(0.40),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restart_alt_rounded,
                                color: _kBlush,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Reopen Post",
                                style: TextStyle(
                                  color: _kBlush,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String initial, double size) {
    ImageProvider? img;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('http')) {
        img = NetworkImage(photoUrl);
      } else {
        try {
          img = MemoryImage(base64Decode(photoUrl));
        } catch (_) {}
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_kViolet, _kVioletLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: img != null
            ? DecorationImage(image: img, fit: BoxFit.cover)
            : null,
      ),
      child: img == null
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }

  Widget _badge(IconData? icon, String label, Color fg, {Color? bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg ?? fg.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withOpacity(0.30), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      );

  Widget _timeAgoText(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      String text;
      if (diff.inMinutes < 1)
        text = 'Just now';
      else if (diff.inHours < 1)
        text = '${diff.inMinutes}m ago';
      else if (diff.inDays < 1)
        text = '${diff.inHours}h ago';
      else if (diff.inDays < 7)
        text = '${diff.inDays}d ago';
      else
        text = '${dt.day}/${dt.month}/${dt.year}';
      return Text(
        text,
        style: const TextStyle(fontSize: 11, color: _kInkMuted),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

// ── Owner three-dot menu ──────────────────────────────────────────────────────
class OwnerMenu extends StatelessWidget {
  final Map<String, dynamic> post;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(int) onDelete;
  final void Function(int, String) onToggle;

  const OwnerMenu({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: _kVioletSoft, shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: _kViolet, size: 18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white,
      offset: const Offset(0, 38),
      itemBuilder: (_) => [
        _menuItem('edit', Icons.edit_rounded, 'Edit Post', _kSky),
        if ((post['status'] as String? ?? '') == 'Resolved')
          _menuItem('toggle', Icons.restart_alt_rounded, 'Reopen Post', _kMint),
        _menuItem(
          'delete',
          Icons.delete_outline_rounded,
          'Delete Post',
          _kBlush,
        ),
      ],
      onSelected: (val) {
        if (val == 'edit') onEdit(post);
        if (val == 'toggle')
          onToggle(post['id'], post['status'] as String? ?? '');
        if (val == 'delete') onDelete(post['id']);
      },
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: _kInk,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
