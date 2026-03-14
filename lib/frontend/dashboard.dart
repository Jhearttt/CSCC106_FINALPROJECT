import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const kBase        = Color(0xFFF0EEFF);
const kInk         = Color(0xFF1E1B4B);
const kInkMid      = Color(0xFF4338CA);
const kInkLight    = Color(0xFF818CF8);
const kViolet      = Color(0xFF7B6CF6);
const kVioletLight = Color(0xFFA78BFA);
const kBlush       = Color(0xFFF472B6);
const kMint        = Color(0xFF34D399);
const kSky         = Color(0xFF60A5FA);
const kAmber       = Color(0xFFFCD34D);
const kBorderGlass = Color(0xFFE0D9FF);

const kHeroGrad = LinearGradient(
  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

// ─── Typography ───────────────────────────────────────────────────────────────
TextStyle get headingXL => GoogleFonts.poppins(
    fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: kInk);
TextStyle get headingLG => GoogleFonts.poppins(
    fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: kInk);
TextStyle get statNumber => GoogleFonts.poppins(
    fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: kInkMid);
TextStyle get labelText => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w600, color: kInkLight);
TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white);

// ─── Dashboard ────────────────────────────────────────────────────────────────
class Dashboard extends StatelessWidget {
  final int? localUserId;
  const Dashboard({super.key, this.localUserId});
  @override
  Widget build(BuildContext context) => DashboardHome(localUserId: localUserId);
}

class DashboardHome extends StatefulWidget {
  final int? localUserId;
  const DashboardHome({super.key, this.localUserId});
  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  // ── Stats from getDashboardStats() — all 4 keys ──
  Map<String, int> _stats = {
    "totalPosts":    0,
    "openRequests":  0,
    "skillOffers":   0,
    "resolvedPosts": 0,
  };

  Map<String, List<Map<String, dynamic>>> _categoryPosts = {
    "Academic":    [],
    "Design":      [],
    "Programming": [],
  };

  List<Map<String, dynamic>> _recentPosts = []; // ← Added: quick navigation per SRS
  bool _loading = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    setState(() => _loading = true);

    final db = DatabaseHelper();
    final stats = await db.getDashboardStats();

    Map<String, List<Map<String, dynamic>>> catPosts = {};
    for (String cat in ["Academic", "Design", "Programming"]) {
      catPosts[cat] = await db.getAllPosts(category: cat, status: null);
    }

    // Recent posts for quick navigation (SRS: "Quick navigation options")
    final recent = await db.getRecentPosts(limit: 5);

    if (!mounted) return;
    setState(() {
      _stats = {
        "totalPosts":    stats["totalPosts"]    ?? 0,
        "openRequests":  stats["openRequests"]  ?? 0,
        "skillOffers":   stats["skillOffers"]   ?? 0,
        "resolvedPosts": stats["resolvedPosts"] ?? 0,
      };
      _categoryPosts = catPosts;
      _recentPosts   = recent;
      _loading = false;
    });
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBase,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kViolet))
            : RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: kViolet,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _buildWelcomeBanner(),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              _buildRecentPosts(),          // ← Added
              const SizedBox(height: 24),
              _buildCategoryPosts(),

            ]),
          ),
        ),
      ),
    );
  }

  // ── Welcome Banner ────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    final name = _user?.displayName?.split(" ").first ?? "Student";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          gradient: kHeroGrad, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("$greeting 👋",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(name, style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 18),
        Text("Student Help & Skills Network",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        Text("Connect · Learn · Grow Together",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  // ── Stats Grid — 4 cards: Total Posts, Open Requests, Skill Offers, Resolved
  Widget _buildStatsGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Overview", style: headingLG),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14, mainAxisSpacing: 14,
        childAspectRatio: 1.55,
        children: [
          _buildStatCard("Total Posts",    _stats["totalPosts"]!,    kViolet,
              Icons.article_rounded),
          _buildStatCard("Open Requests",  _stats["openRequests"]!,  kBlush,
              Icons.help_outline_rounded),
          _buildStatCard("Skill Offers",   _stats["skillOffers"]!,   kMint,
              Icons.lightbulb_outline_rounded),
          _buildStatCard("Resolved",       _stats["resolvedPosts"]!, kAmber,
              Icons.check_circle_outline_rounded),
        ],
      ),
    ]);
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGlass),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("$count", style: statNumber),
              const SizedBox(height: 2),
              Text(label, style: labelText),
            ])),
      ]),
    );
  }

  // ── Recent Posts — quick navigation per SRS ──────────────────────────────
  Widget _buildRecentPosts() {
    if (_recentPosts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text("Recent Activity", style: headingLG),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CommunityFeedScreen(localUserId: widget.localUserId))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                gradient: kHeroGrad, borderRadius: BorderRadius.circular(20)),
            child: Text("See all", style: buttonText.copyWith(fontSize: 11)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      ..._recentPosts.map((post) => _buildRecentPostTile(post)),
    ]);
  }

  Widget _buildRecentPostTile(Map<String, dynamic> post) {
    final isHelpReq = post['postType'] == 'Help Request';
    final isOpen    = post['status']   == 'Open';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGlass, width: 1),
        boxShadow: [BoxShadow(color: kViolet.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (isHelpReq ? kSky : kMint).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isHelpReq ? Icons.help_outline_rounded
              : Icons.lightbulb_outline_rounded,
              color: isHelpReq ? kSky : kMint, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post['title'] ?? 'Untitled',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                  color: kInk, fontSize: 13)),
          Text(post['userFullName'] ?? '',
              style: labelText.copyWith(fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isOpen ? kBlush.withOpacity(0.10) : kMint.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(post['status'] ?? '',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: isOpen ? const Color(0xFF9D174D) : const Color(0xFF065F46))),
        ),
      ]),
    );
  }

  // ── Posts by Category ─────────────────────────────────────────────────────
  Widget _buildCategoryPosts() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Browse by Category", style: headingLG),
      const SizedBox(height: 12),
      ..._categoryPosts.entries.map((entry) {
        final cat   = entry.key;
        final posts = entry.value;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Category header
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: _catColor(cat), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(cat, style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 14, color: kInk)),
            const SizedBox(width: 6),
            Text("(${posts.length})", style: labelText),
          ]),
          const SizedBox(height: 8),
          posts.isEmpty
              ? Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 16),
            child: Text("No posts in this category.", style: labelText),
          )
              : Column(children: List.generate(posts.length, (i) {
            final post = posts[i];
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CommunityFeedScreen(
                      localUserId: widget.localUserId))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorderGlass, width: 1),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _catColor(cat).withOpacity(0.15),
                    child: Text("${i + 1}",
                        style: TextStyle(color: _catColor(cat),
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(post["title"] ?? "Untitled",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, color: kInk, fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _catColor(cat).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(post["postType"] ?? "",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: _catColor(cat))),
                  ),
                ]),
              ),
            );
          })),
          const SizedBox(height: 8),
        ]);
      }),
    ]);
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Academic':    return kSky;
      case 'Design':      return kBlush;
      case 'Programming': return kMint;
      default:            return kViolet;
    }
  }



  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            gradient: kHeroGrad, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(label, style: buttonText),
        ]),
      ),
    );
  }
}