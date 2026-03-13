import 'dart:math';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
const _kAmberSoft   = Color(0xFFFEF3C7);
const _kBorderGlass = Color(0xFFE0D9FF);
const _kBase        = Color(0xFFF0EEFF);

class _AuroraMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)));
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

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final int? localUserId;
  const ProfileScreen({super.key, this.localUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ── Original state ──
  final User? _firebaseUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _localUser;
  List<Map<String, dynamic>> _myPosts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  // ── Original data loading ──
  Future<void> _loadData() async {
    if (widget.localUserId != null) {
      _localUser = await DatabaseHelper().getUserById(widget.localUserId!);
      _myPosts   = await DatabaseHelper().getPostsByUser(widget.localUserId!);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Original helpers ──
  String get _displayName =>
      _firebaseUser?.displayName ?? _localUser?['fullName'] ?? 'Guest User';
  String get _displayEmail =>
      _firebaseUser?.email ?? _localUser?['email'] ?? 'Local Account';
  String? get _photoUrl => _firebaseUser?.photoURL ?? _localUser?['profilePic'];
  String get _initials =>
      _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';

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
    return Scaffold(
      body: Stack(children: [
        // Aurora bg
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kViolet))
              : Column(children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _kBorderGlass, width: 1.2),
                      boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _kViolet, size: 17),
                  ),
                ),
                const SizedBox(width: 14),
                const Text("My Profile",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: _kInk, letterSpacing: -0.4)),
              ]),
            ),

            // ── Profile hero card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: _kViolet.withOpacity(0.30),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  BoxShadow(color: _kBlush.withOpacity(0.15),
                      blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                // Avatar
                Container(
                  width: 66, height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2.5),
                    color: Colors.white.withOpacity(0.20),
                    image: _photoUrl != null
                        ? DecorationImage(
                        image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoUrl == null
                      ? Center(child: Text(_initials,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 26, fontWeight: FontWeight.w900)))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_displayName,
                      style: const TextStyle(fontSize: 17,
                          fontWeight: FontWeight.w900, color: Colors.white,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(_displayEmail,
                      style: TextStyle(fontSize: 12,
                          color: Colors.white.withOpacity(0.70))),
                  const SizedBox(height: 10),
                  // Post count pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 1),
                    ),
                    child: Text(
                        '${_myPosts.length} post${_myPosts.length != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ])),
              ]),
            ),

            // Gradient divider
            Container(
              height: 2.5, margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
              ),
            ),

            // ── My posts header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                const Text("My Posts",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: _kInk, letterSpacing: -0.3)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CreatePostScreen(localUserId: widget.localUserId)))
                      .then((_) => _loadData()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kViolet, _kVioletLight],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.32),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text("New Post", style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Posts list ──
            Expanded(
              child: _myPosts.isEmpty
                  ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.post_add_rounded, color: _kInkMuted, size: 52),
                    const SizedBox(height: 10),
                    const Text("No posts yet",
                        style: TextStyle(color: _kInkLight, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ]))
                  : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _myPosts.length,
                  itemBuilder: (context, index) {
                    final post    = _myPosts[index];
                    final isOpen  = post['status'] == 'Open';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorderGlass, width: 1.2),
                        boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.08),
                            blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(post['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w800,
                                      fontSize: 14, color: _kInk))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: isOpen
                                      ? const LinearGradient(
                                      colors: [Color(0xFFFCE7F3), Color(0xFFFBCFE8)])
                                      : const LinearGradient(
                                      colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)]),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isOpen
                                          ? _kBlush.withOpacity(0.40)
                                          : _kMint.withOpacity(0.40),
                                      width: 1),
                                ),
                                child: Text(post['status'],
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                        color: isOpen
                                            ? const Color(0xFF9D174D)
                                            : const Color(0xFF065F46))),
                              ),
                            ]),
                            const SizedBox(height: 5),
                            Text(
                                (post['description'] ?? '').length > 80
                                    ? '${(post['description'] as String).substring(0, 80)}...'
                                    : post['description'] ?? '',
                                style: const TextStyle(fontSize: 12.5,
                                    color: _kInkLight, height: 1.4)),
                            const SizedBox(height: 10),
                            Row(children: [
                              _chip(post['postType'], _kVioletSoft, _kVioletLight),
                              const SizedBox(width: 6),
                              _chip(post['category'], _kSkySoft, _kSky),
                              const Spacer(),
                              Text(_timeAgo(post['datePosted'] ?? ''),
                                  style: const TextStyle(fontSize: 11, color: _kInkMuted)),
                            ]),
                          ]),
                    );
                  }),
            ),

            // ── Log out button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kBlushSoft,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _kBlush.withOpacity(0.35), width: 1.5),
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (r) => false);
                    },
                    icon: const Icon(Icons.logout_rounded, color: _kBlush, size: 18),
                    label: const Text("Log Out",
                        style: TextStyle(color: _kBlush,
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28))),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(label, style: TextStyle(fontSize: 10.5,
          fontWeight: FontWeight.w700, color: fg)),
    );
  }
}