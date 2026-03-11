import 'dart:math';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Painter ──────────────────────────────────────────────────────────────────
class _ProfileGeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p0 = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.18);
    final p1 = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.22);
    final p3 = Paint()..color = const Color(0xFFBBDEFB).withOpacity(0.28);

    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width * 0.60, 0)
      ..lineTo(0, size.height * 0.22)..close(), p0);
    canvas.drawPath(Path()..moveTo(size.width, 0)..lineTo(size.width, size.height * 0.16)
      ..lineTo(size.width * 0.55, 0)..close(), p1);
    canvas.drawPath(Path()..moveTo(size.width, size.height * 0.75)..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.40, size.height)..close(), p0);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.85)..lineTo(0, size.height)
      ..lineTo(size.width * 0.35, size.height)..close(), p3);
    _drawHex(canvas, Offset(size.width * 0.91, size.height * 0.08), size.width * 0.06, p1);
    _drawHex(canvas, Offset(size.width * 0.88, size.height * 0.85), size.width * 0.05, p3);
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (pi / 3) * i - pi / 6;
      i == 0 ? path.moveTo(center.dx + r * cos(a), center.dy + r * sin(a))
          : path.lineTo(center.dx + r * cos(a), center.dy + r * sin(a));
    }
    path.close(); canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E88E5).withOpacity(0.07)..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = spacing; x < size.width; x += spacing)
      for (double y = spacing; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.4, paint);
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
  final User? _firebaseUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _localUser;
  List<Map<String, dynamic>> _myPosts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    if (widget.localUserId != null) {
      _localUser = await DatabaseHelper().getUserById(widget.localUserId!);
      _myPosts   = await DatabaseHelper().getPostsByUser(widget.localUserId!);
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _displayName =>
      _firebaseUser?.displayName ?? _localUser?['fullName'] ?? 'Guest User';
  String get _displayEmail =>
      _firebaseUser?.email ?? _localUser?['email'] ?? 'Local Account';
  String? get _photoUrl => _firebaseUser?.photoURL ?? _localUser?['profilePic'];
  String get _initials => _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';

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
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0.0, 0.35, 0.68, 1.0],
          ),
        )),
        CustomPaint(painter: _ProfileGeometricPainter(), child: const SizedBox.expand()),
        IgnorePointer(child: CustomPaint(painter: _DotGridPainter(), child: const SizedBox.expand())),

        SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
              : Column(children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.65), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF90CAF9), width: 1.5)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1565C0), size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                const Text("My Profile", style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
              ]),
            ),

            // ── Profile card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50), width: 1.2),
                boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.12),
                    blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                // Avatar
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))],
                    image: _photoUrl != null
                        ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoUrl == null
                      ? Center(child: Text(_initials, style: const TextStyle(color: Colors.white,
                      fontSize: 24, fontWeight: FontWeight.w800)))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_displayName, style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 3),
                  Text(_displayEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_myPosts.length} post${_myPosts.length != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600)),
                  ),
                ])),
              ]),
            ),

            // ── Divider ──
            Container(height: 2, margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFFBBDEFB)]))),

            // ── My posts label ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("My Posts", style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CreatePostScreen(localUserId: widget.localUserId)))
                      .then((_) => _loadData()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.30),
                          blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text("New Post", style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 12)),
                    ]),
                  ),
                ),
              ]),
            ),

            // ── Posts list ──
            Expanded(
              child: _myPosts.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.post_add_rounded, color: const Color(0xFF90CAF9), size: 50),
                const SizedBox(height: 10),
                const Text("No posts yet", style: TextStyle(color: Color(0xFF1976D2),
                    fontSize: 14, fontWeight: FontWeight.w600)),
              ]))
                  : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _myPosts.length,
                  itemBuilder: (context, index) {
                    final post = _myPosts[index];
                    final isOpen   = post['status'] == 'Open';
                    final isHelpReq = post['postType'] == 'Help Request';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.40), width: 1.2),
                        boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.08),
                            blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(post['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                                  color: Color(0xFF0D47A1)))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: isOpen ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isOpen ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7))),
                            child: Text(post['status'], style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isOpen ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32))),
                          ),
                        ]),
                        const SizedBox(height: 5),
                        Text((post['description'] ?? '').length > 80
                            ? '${(post['description'] as String).substring(0, 80)}...'
                            : post['description'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(post['postType'], style: const TextStyle(fontSize: 10,
                                  color: Color(0xFF1565C0), fontWeight: FontWeight.w600))),
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(post['category'], style: const TextStyle(fontSize: 10,
                                  color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600))),
                          const Spacer(),
                          Text(_timeAgo(post['datePosted'] ?? ''),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF90CAF9))),
                        ]),
                      ]),
                    );
                  }),
            ),

            // ── Log out button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService().signOut();
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 18),
                  label: const Text("Log Out", style: TextStyle(color: Color(0xFFEF5350),
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF9A9A), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}