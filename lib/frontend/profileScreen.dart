import 'dart:convert';
import 'dart:typed_data';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:final_project/services/syncService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
const _kSky         = Color(0xFF60A5FA);
const _kSkySoft     = Color(0xFFDBEAFE);
const _kAmber       = Color(0xFFFCD34D);
const _kBorderGlass = Color(0xFFE0D9FF);

class _AuroraMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(
            colors: [color.withOpacity(opacity), color.withOpacity(0)])
            .createShader(Rect.fromCircle(center: c, radius: r)));
    }
    orb(Offset(size.width * 0.10, size.height * 0.05), size.width * 0.52, _kViolet, 0.18);
    orb(Offset(size.width * 0.90, size.height * 0.12), size.width * 0.40, const Color(0xFFC084FC), 0.15);
    orb(Offset(size.width * 0.06, size.height * 0.80), size.width * 0.38, _kMint, 0.12);
    orb(Offset(size.width * 0.88, size.height * 0.88), size.width * 0.38, _kSky, 0.11);
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

String _badgeLabel(int pts) {
  if (pts >= 500) return '🏆 Legend';
  if (pts >= 200) return '💎 Expert';
  if (pts >= 100) return '⭐ Helper';
  if (pts >= 40)  return '🌱 Rising Star';
  return '🆕 Newcomer';
}

Color _badgeColor(int pts) {
  if (pts >= 500) return const Color(0xFFFFD700);
  if (pts >= 200) return const Color(0xFF60A5FA);
  if (pts >= 100) return _kVioletLight;
  if (pts >= 40)  return _kMint;
  return _kInkMuted;
}

Color _catColor(String cat) {
  switch (cat) {
    case 'Programming': return _kMint;
    case 'Design':      return _kBlush;
    case 'Academic':    return _kSky;
    default:            return _kViolet;
  }
}

IconData _catIcon(String cat) {
  switch (cat) {
    case 'Programming': return Icons.code_rounded;
    case 'Design':      return Icons.palette_rounded;
    case 'Academic':    return Icons.school_rounded;
    default:            return Icons.category_rounded;
  }
}

class ProfileScreen extends StatefulWidget {
  final int?  localUserId;
  final bool  embeddedMode;
  /// Pass false when viewing someone else's profile (e.g. from post detail).
  /// Defaults to true so existing tab/home usage is unchanged.
  final bool  isOwnProfile;

  const ProfileScreen({
    super.key,
    this.localUserId,
    this.embeddedMode = false,
    this.isOwnProfile = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final User? _firebaseUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>?      _localUser;
  List<Map<String, dynamic>> _myPosts    = [];
  List<Map<String, dynamic>> _skillCards = [];
  bool _loading = true;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    if (widget.localUserId != null) {
      final db  = DatabaseHelper();
      _localUser  = await db.getUserById(widget.localUserId!);
      final raw   = await db.getPostsByUser(widget.localUserId!);
      _skillCards = await db.getSkillCards(widget.localUserId!);

      // Sort: High urgency first, then Medium, then Low; resolved sink to bottom
      int _urgencyRank(String u) => u == 'High' ? 0 : u == 'Medium' ? 1 : 2;

      final open = raw.where((p) => p['status'] != 'Resolved').toList()
        ..sort((a, b) {
          final uA = _urgencyRank(a['urgencyLevel'] as String? ?? 'Low');
          final uB = _urgencyRank(b['urgencyLevel'] as String? ?? 'Low');
          if (uA != uB) return uA.compareTo(uB);
          return (b['datePosted'] as String? ?? '')
              .compareTo(a['datePosted'] as String? ?? '');
        });
      final resolved = raw.where((p) => p['status'] == 'Resolved').toList()
        ..sort((a, b) => (b['datePosted'] as String? ?? '')
            .compareTo(a['datePosted'] as String? ?? ''));

      _myPosts = [...open, ...resolved];
    }
    if (mounted) setState(() => _loading = false);
  }

  // Only use Firebase user data when viewing our OWN profile.
  // When viewing someone else's profile, always use SQLite _localUser only.
  String get _displayName =>
      widget.isOwnProfile
          ? (_firebaseUser?.displayName ?? _localUser?['fullName'] ?? 'Guest User')
          : (_localUser?['fullName'] ?? 'Unknown User');

  String get _displayEmail =>
      widget.isOwnProfile
          ? (_firebaseUser?.email ?? _localUser?['email'] ?? 'Local Account')
          : (_localUser?['email'] ?? '');

  String? get _photoUrl =>
      widget.isOwnProfile
          ? (_firebaseUser?.photoURL ?? _localUser?['profilePic'])
          : (_localUser?['profilePic'] as String?);
  String get _initials     =>
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  int get _points    => (_localUser?['points']    as int? ?? 0);
  int get _helpCount => (_localUser?['helpCount'] as int? ?? 0);
  int get _streak    => (_localUser?['streak']    as int? ?? 0);

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

  // ── Navigate to edit post ─────────────────────────────────────────────────
  void _goToEdit(Map<String, dynamic> post) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => CreatePostScreen(
          localUserId: widget.localUserId, existingPost: post),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 380),
    )).then((_) => _loadData());
  }

  // ── Show three-dot options as centered dialog ────────────────────────────
  void _showPostOptions(BuildContext context, Map<String, dynamic> post) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PostOptions',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curve),
            child: FadeTransition(opacity: curve, child: child));
      },
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: _kViolet.withOpacity(0.18),
                  blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Post title header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Text(post['title'] ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(height: 8),
            // Options
            _optionTile(ctx, Icons.edit_rounded, 'Edit Post', _kSky,
                    () { Navigator.pop(ctx); _goToEdit(post); }),
            // Resolving is done via Accept Solution in comments — only allow Reopen
            if (post['status'] == 'Resolved')
              _optionTile(ctx, Icons.restart_alt_rounded, 'Reopen Post',
                  _kMint, () async {
                    Navigator.pop(ctx);
                    await SyncService.instance.updatePostStatus(
                        post['id'], 'Open');
                    _loadData();
                  }),
            _optionTile(ctx, Icons.delete_outline_rounded,
                'Delete Post', _kBlush, () {
                  Navigator.pop(ctx);
                  AwesomeDialog(
                    context: context, dialogType: DialogType.warning,
                    title: 'Delete Post',
                    desc: 'Are you sure you want to delete this post?',
                    btnOkOnPress: () async {
                      await SyncService.instance.deletePost(post['id']);
                      _loadData();
                    },
                    btnCancelOnPress: () {},
                  ).show();
                }),
            const SizedBox(height: 8),
            // Cancel
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F2FF),
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(
                  child: Text("Cancel", style: TextStyle(
                      color: _kViolet, fontWeight: FontWeight.w700,
                      fontSize: 14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _optionTile(BuildContext ctx, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20), width: 1)),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: _kInk,
              fontWeight: FontWeight.w600, fontSize: 13.5)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(children: [
      Container(decoration: const BoxDecoration(gradient: LinearGradient(
        colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
          Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        stops: [0.0, 0.35, 0.68, 1.0],
      ))),
      CustomPaint(painter: _AuroraMeshPainter(), child: const SizedBox.expand()),
      IgnorePointer(child: CustomPaint(painter: _DotGridPainter(),
          child: const SizedBox.expand())),

      SafeArea(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _kViolet))
          : Column(children: [

        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            if (!widget.embeddedMode) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
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
            ],
            Text(
                widget.isOwnProfile ? "My Profile" : _displayName,
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.4)),
          ]),
        ),

        // ── Hero card ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: _kViolet.withOpacity(0.28),
                  blurRadius: 22, offset: const Offset(0, 8)),
              BoxShadow(color: _kBlush.withOpacity(0.14),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2.5),
                  color: Colors.white.withOpacity(0.20),
                  image: _photoUrl != null ? DecorationImage(
                      image: NetworkImage(_photoUrl!), fit: BoxFit.cover) : null,
                ),
                child: _photoUrl == null
                    ? Center(child: Text(_initials, style: const TextStyle(
                    color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w900))) : null,
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_displayName, style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w900, color: Colors.white,
                    letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(_displayEmail, style: TextStyle(fontSize: 11.5,
                    color: Colors.white.withOpacity(0.70))),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _badgeColor(_points).withOpacity(0.20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _badgeColor(_points).withOpacity(0.50))),
                    child: Text(_badgeLabel(_points), style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: _badgeColor(_points)))),
              ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _reputationStat('⭐', '$_points',          'Points'),
              _divider(),
              _reputationStat('🤝', '$_helpCount',       'Helped'),
              _divider(),
              _reputationStat('🔥', '$_streak',          'Day Streak'),
              _divider(),
              _reputationStat('📝', '${_myPosts.length}','Posts'),
            ]),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Tabs ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorderGlass)),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Colors.white,
            unselectedLabelColor: _kInkLight,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            indicator: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kViolet, _kVioletLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12)),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: "My Posts"), Tab(text: "Skill Cards")],
          ),
        ),

        const SizedBox(height: 4),

        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [_buildPostsTab(), _buildSkillCardsTab()],
        )),

        // ── Log out (only on own profile) ──
        if (widget.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(width: double.infinity, height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: _kBlushSoft, borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: _kBlush.withOpacity(0.35), width: 1.5)),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (r) => false);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: _kBlush, size: 18),
                  label: const Text("Log Out", style: TextStyle(
                      color: _kBlush, fontWeight: FontWeight.w800, fontSize: 14)),
                  style: OutlinedButton.styleFrom(side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28))),
                ),
              ),
            ),
          ),
      ])),
    ]);

    return widget.embeddedMode ? body : Scaffold(body: body);
  }

  Widget _reputationStat(String emoji, String value, String label) =>
      Expanded(child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800, fontSize: 15)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.70),
            fontSize: 10.5, fontWeight: FontWeight.w500)),
      ]));

  Widget _divider() => Container(width: 1, height: 36,
      color: Colors.white.withOpacity(0.25));

  // ── Open post detail as centered floating card (same as community feed) ──
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
        post:        post,
        localUserId: widget.localUserId,
        onToggleStatus: (id, current) {
          Navigator.pop(ctx);
          final next = current == 'Open' ? 'Resolved' : 'Open';
          SyncService.instance.updatePostStatus(id, next).then((_) => _loadData());
        },
        onDelete: (id) {
          Navigator.pop(ctx);
          AwesomeDialog(
            context: context, dialogType: DialogType.warning,
            title: 'Delete Post',
            desc: 'Are you sure you want to delete this post?',
            btnOkOnPress: () async {
              await SyncService.instance.deletePost(id);
              _loadData();
            },
            btnCancelOnPress: () {},
          ).show();
        },
        onEdit: (p) {
          Navigator.pop(ctx);
          _goToEdit(p);
        },
      ),
    );
  }

  // ── Posts tab ──────────────────────────────────────────────────────────────
  Widget _buildPostsTab() {
    return Stack(children: [
      _myPosts.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.post_add_rounded, color: _kInkMuted, size: 50),
            const SizedBox(height: 10),
            const Text("No posts yet", style: TextStyle(color: _kInkLight,
                fontSize: 14, fontWeight: FontWeight.w600)),
          ]))
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _myPosts.length,
        itemBuilder: (_, i) => _buildPostCard(_myPosts[i]),
      ),
      // FAB — only on own profile
      if (widget.isOwnProfile)
        Positioned(bottom: 20, right: 20,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (_, anim, __) => CreatePostScreen(
                  localUserId: widget.localUserId),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              transitionDuration: const Duration(milliseconds: 380),
            )).then((_) => _loadData()),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(color: _kViolet.withOpacity(0.38),
                        blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Image widget: handles base64 data URIs and network URLs ─────────────
  // ignore: non_constant_identifier_names
  Widget _ProfilePostImage({
    required String src,
    double? size,
    BoxFit fit = BoxFit.cover,
  }) {
    final isBase64 = src.startsWith('data:image');
    Widget img;
    if (isBase64) {
      try {
        final comma = src.indexOf(',');
        final bytes = base64Decode(src.substring(comma + 1));
        img = Image.memory(bytes,
            width: size, height: size, fit: fit,
            errorBuilder: (_, __, ___) => _brokenImg(size));
      } catch (_) {
        img = _brokenImg(size);
      }
    } else {
      img = Image.network(src,
          width: size, height: size, fit: fit,
          errorBuilder: (_, __, ___) => _brokenImg(size));
    }
    return SizedBox(width: size, height: size, child: img);
  }

  Widget _brokenImg(double? size) => Container(
      width: size, height: size,
      color: _kVioletSoft,
      child: const Center(child: Icon(
          Icons.broken_image_outlined, color: _kVioletLight)));

  // ── Post card with three-dot menu + tap to open detail ───────────────────
  Widget _buildPostCard(Map<String, dynamic> post) {
    final isOpen    = post['status']    == 'Open';
    final urgency   = post['urgencyLevel'] as String? ?? 'Low';
    final isBoosted = (post['isBoosted']   as int?    ?? 0) == 1;
    final urgencyColor = urgency == 'High' ? _kBlush
        : urgency == 'Medium' ? _kAmber : _kMint;
    final imgUrl    = post['imageUrl'] as String?;
    final hasImage  = imgUrl != null && imgUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _openPostDetail(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isBoosted ? _kAmber.withOpacity(0.40) : _kBorderGlass,
              width: 1.2),
          boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.07),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top row: title badges three-dot ──
          Row(children: [
            Expanded(child: Text(post['title'] ?? '', style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13.5, color: _kInk))),
            // Urgency badge
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(urgency == 'High'   ? Icons.arrow_upward_rounded
                      : urgency == 'Medium' ? Icons.remove_rounded
                      : Icons.arrow_downward_rounded,
                      size: 9, color: urgencyColor),
                  const SizedBox(width: 3),
                  Text(urgency, style: TextStyle(fontSize: 9.5,
                      fontWeight: FontWeight.w700, color: urgencyColor)),
                ])),
            const SizedBox(width: 6),
            // Status badge
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    gradient: isOpen
                        ? const LinearGradient(
                        colors: [Color(0xFFFCE7F3), Color(0xFFFBCFE8)])
                        : const LinearGradient(
                        colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(post['status'] as String? ?? 'Open',
                    style: TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w800,
                        color: isOpen ? const Color(0xFF9D174D)
                            : const Color(0xFF065F46)))),
            const SizedBox(width: 4),
            // Three-dot menu — only on own profile
            if (widget.isOwnProfile)
              GestureDetector(
                onTap: () => _showPostOptions(context, post),
                child: Container(width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: _kVioletSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: _kViolet, size: 16)),
              ),
          ]),

          const SizedBox(height: 8),

          // ── Description + thumbnail row ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Description text
            Expanded(
              child: Text(
                  (post['description'] as String? ?? '').length > (hasImage ? 60 : 80)
                      ? '${(post['description'] as String? ?? '').substring(0, hasImage ? 60 : 80)}...'
                      : post['description'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 12.5, color: _kInkLight, height: 1.4)),
            ),

            // ── Side thumbnail ──
            if (hasImage) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _openImageFullScreen(context, imgUrl),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _ProfilePostImage(src: imgUrl, size: 68),
                  ),
                  // Expand hint
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.transparent,
                                Colors.black.withOpacity(0.35)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter),
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: const Icon(Icons.fullscreen_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ),
                  ),
                  // Border
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorderGlass, width: 1.2)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),

          const SizedBox(height: 8),

          // ── Chips + date ──
          Row(children: [
            _chip(post['postType'] as String? ?? 'Post', _kVioletSoft, _kVioletLight),
            const SizedBox(width: 6),
            _chip(post['category'] as String? ?? 'Others', _kSkySoft, _kSky),
            if (isBoosted) ...[
              const SizedBox(width: 6),
              _chip('🚀 Boosted', _kAmber.withOpacity(0.12), _kAmber),
            ],
            const Spacer(),
            Text(_timeAgo(post['datePosted'] ?? ''),
                style: const TextStyle(fontSize: 10.5, color: _kInkMuted)),
          ]),
        ]),
      ),
    );
  }

  // ── Full-screen image viewer (base64 + network) ───────────────────────────
  void _openImageFullScreen(BuildContext context, String src) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, anim, __) => FadeTransition(
        opacity: anim,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(color: Colors.black87)),
            Center(child: InteractiveViewer(
              minScale: 0.5, maxScale: 4.0,
              child: _ProfilePostImage(src: src, fit: BoxFit.contain),
            )),
            Positioned(top: 48, right: 16,
                child: GestureDetector(onTap: () => Navigator.pop(context),
                    child: Container(width: 38, height: 38,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.30), width: 1)),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20)))),
          ]),
        ),
      ),
    ));
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.w700, color: fg)));

  // ── Skill Cards tab ────────────────────────────────────────────────────────
  Widget _buildSkillCardsTab() {
    if (_skillCards.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _kInkMuted, size: 50),
            const SizedBox(height: 12),
            const Text("No skill cards yet", style: TextStyle(color: _kInkLight,
                fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text("Reply to posts to earn skill points",
                style: TextStyle(color: _kInkMuted, fontSize: 12.5)),
          ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12,
          mainAxisSpacing: 12, childAspectRatio: 1.15),
      itemCount: _skillCards.length,
      itemBuilder: (_, i) => _buildSkillCard(_skillCards[i]),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> card) {
    final cat   = card['skillCategory'] as String? ?? 'Others';
    final pts   = (card['skillPoints']  as int? ?? 0);
    final color = _catColor(cat);
    final icon  = _catIcon(cat);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 42, height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat, style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 13, color: _kInk)),
              const SizedBox(height: 4),
              Row(children: [
                const Text("⭐ ", style: TextStyle(fontSize: 11)),
                Text("$pts points", style: TextStyle(fontSize: 11.5,
                    fontWeight: FontWeight.w700, color: color)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pts / 200).clamp(0.0, 1.0),
                  backgroundColor: color.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
            ]),
          ]),
    );
  }
}