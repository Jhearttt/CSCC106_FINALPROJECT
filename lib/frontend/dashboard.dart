import 'dart:convert';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBase = Color(0xFFF0EEFF);
const kInk = Color(0xFF1E1B4B);
const kInkMid = Color(0xFF4338CA);
const kInkLight = Color(0xFF818CF8);
const kViolet = Color(0xFF7B6CF6);
const kVioletLight = Color(0xFFA78BFA);
const kBlush = Color(0xFFF472B6);
const kMint = Color(0xFF34D399);
const kSky = Color(0xFF60A5FA);
const kAmber = Color(0xFFFCD34D);
const kBorderGlass = Color(0xFFE0D9FF);

const kHeroGrad = LinearGradient(
  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

TextStyle get headingLG => GoogleFonts.poppins(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.3,
  color: kInk,
);
TextStyle get statNumber => GoogleFonts.poppins(
  fontSize: 26,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.8,
  color: kInkMid,
);
TextStyle get labelText => GoogleFonts.inter(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: kInkLight,
);
TextStyle get buttonText => GoogleFonts.inter(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
  color: Colors.white,
);

String _badgeForPoints(int pts) {
  if (pts >= 500) return '🏆 Legend';
  if (pts >= 200) return '💎 Expert';
  if (pts >= 100) return '⭐ Helper';
  if (pts >= 40) return '🌱 Rising';
  return '🆕 Newcomer';
}

Color _badgeColor(int pts) {
  if (pts >= 500) return const Color(0xFFFFD700);
  if (pts >= 200) return const Color(0xFF60A5FA);
  if (pts >= 100) return const Color(0xFFA78BFA);
  if (pts >= 40) return const Color(0xFF34D399);
  return const Color(0xFFA5B4FC);
}

// ── Reusable avatar widget: photo → initial fallback ─────────────────────────
Widget _buildAvatar({
  required String? photoUrl,
  required String initial,
  required double size,
  List<Color> gradientColors = const [kViolet, kVioletLight],
  Color? borderColor,
}) {
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
      gradient: img == null
          ? LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: img != null ? Colors.transparent : null,
      border: borderColor != null
          ? Border.all(color: borderColor, width: 2)
          : null,
      boxShadow: [
        BoxShadow(
          color: kViolet.withOpacity(0.18),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
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
  Map<String, int> _stats = {
    "totalPosts": 0,
    "openRequests": 0,
    "skillOffers": 0,
    "resolvedPosts": 0,
  };
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _topHelpers = [];
  List<Map<String, dynamic>> _smartMatches = [];
  bool _loading = true;
  String? _matchCategory;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    DatabaseHelper.profilePicVersion.addListener(_refreshDashboard);
  }

  @override
  void dispose() {
    DatabaseHelper.profilePicVersion.removeListener(_refreshDashboard);
    super.dispose();
  }

  Future<void> _refreshDashboard() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();

    await db.checkAndBoostExpiredPosts();
    await db.syncCommentCounts();

    final stats = await db.getDashboardStats();
    final recent = await db.getRecentPosts(limit: 5);
    final topHelp = await db.getTopHelpers();

    final openRequests = await db.getAllPosts(
      postType: 'Help Request',
      status: 'Open',
    );
    List<Map<String, dynamic>> matches = [];
    String? matchCat;
    if (openRequests.isNotEmpty) {
      matchCat = openRequests.first['category'] as String?;
      if (matchCat != null) matches = await db.getSuggestedHelpers(matchCat);
    }

    if (!mounted) return;
    setState(() {
      _stats = {
        "totalPosts": stats["totalPosts"] ?? 0,
        "openRequests": stats["openRequests"] ?? 0,
        "skillOffers": stats["skillOffers"] ?? 0,
        "resolvedPosts": stats["resolvedPosts"] ?? 0,
      };
      _recentPosts = recent;
      _topHelpers = topHelp;
      _smartMatches = matches;
      _matchCategory = matchCat;
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  void _goToProfile(BuildContext context, int userId) {
    final isOwn = widget.localUserId == userId;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(localUserId: userId, isOwnProfile: isOwn),
      ),
    );
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
                  child: Column(
                    children: [
                      _buildWelcomeBanner(),
                      const SizedBox(height: 22),
                      _buildStatsGrid(),
                      const SizedBox(height: 22),
                      if (_smartMatches.isNotEmpty) ...[
                        _buildSmartMatch(),
                        const SizedBox(height: 22),
                      ],
                      _buildRecentPosts(),
                      const SizedBox(height: 22),
                      _buildLeaderboard(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Welcome banner ─────────────────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    final name = _user?.displayName?.split(" ").first ?? "Student";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: kHeroGrad,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$_greeting 👋",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Student Help & Skills Network",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Connect · Learn · Grow Together",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Stats grid ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Overview", style: headingLG),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _statCard(
              "Total Posts",
              _stats["totalPosts"]!,
              kViolet,
              Icons.article_rounded,
            ),
            _statCard(
              "Open Requests",
              _stats["openRequests"]!,
              kBlush,
              Icons.help_outline_rounded,
            ),
            _statCard(
              "Skill Offers",
              _stats["skillOffers"]!,
              kMint,
              Icons.lightbulb_outline_rounded,
            ),
            _statCard(
              "Resolved",
              _stats["resolvedPosts"]!,
              kAmber,
              Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderGlass),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("$count", style: statNumber),
                Text(label, style: labelText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Smart Match ────────────────────────────────────────────────────────────
  Widget _buildSmartMatch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Smart Match", style: headingLG),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kViolet, kVioletLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "AI",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Students who can help with $_matchCategory requests",
          style: labelText,
        ),
        const SizedBox(height: 10),
        ..._smartMatches.map((u) => _matchCard(u)),
      ],
    );
  }

  Widget _matchCard(Map<String, dynamic> user) {
    final pts = (user['points'] as int? ?? 0);
    final helped = (user['helpCount'] as int? ?? 0);
    final name = user['fullName'] as String? ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final photo = user['profilePic'] as String?;
    final uid = user['id'] as int?;

    return GestureDetector(
      onTap: uid != null ? () => _goToProfile(context, uid) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderGlass),
          boxShadow: [
            BoxShadow(
              color: kViolet.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(photoUrl: photo, initial: initial, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: kInk,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 11,
                        color: kVioletLight,
                      ),
                    ],
                  ),
                  Text(user['skillTitle'] ?? '', style: labelText),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _badgeColor(pts).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _badgeForPoints(pts),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _badgeColor(pts),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text("Helped $helped", style: labelText),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent activity ────────────────────────────────────────────────────────
  Widget _buildRecentPosts() {
    if (_recentPosts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Recent Activity", style: headingLG),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        ..._recentPosts.map((p) => _recentPostTile(p)),
      ],
    );
  }

  Widget _recentPostTile(Map<String, dynamic> post) {
    final isHelp = post['postType'] == 'Help Request';
    final isOpen = post['status'] == 'Open';
    final isBoosted = (post['isBoosted'] as int? ?? 0) == 1;
    final urgency = post['urgencyLevel'] as String? ?? 'Low';
    final urgencyColor = urgency == 'High'
        ? kBlush
        : urgency == 'Medium'
        ? kAmber
        : kMint;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isBoosted ? kAmber.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBoosted ? kAmber.withOpacity(0.40) : kBorderGlass,
        ),
        boxShadow: [
          BoxShadow(
            color: kViolet.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isHelp ? kSky : kMint).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isHelp
                  ? Icons.help_outline_rounded
                  : Icons.lightbulb_outline_rounded,
              color: isHelp ? kSky : kMint,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isBoosted) ...[
                      const Icon(
                        Icons.rocket_launch_rounded,
                        color: kAmber,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        post['title'] ?? 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: kInk,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  post['userFullName'] ?? '',
                  style: labelText.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  urgency,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: urgencyColor,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen
                      ? kBlush.withOpacity(0.10)
                      : kMint.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  post['status'] ?? '',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isOpen
                        ? const Color(0xFF9D174D)
                        : const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────
  Widget _buildLeaderboard() {
    if (_topHelpers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Top Campus Helpers", style: headingLG),
            const SizedBox(width: 8),
            const Text("🏆", style: TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kBorderGlass),
            boxShadow: [
              BoxShadow(
                color: kViolet.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(_topHelpers.length, (i) {
              final u = _topHelpers[i];
              final pts = (u['points'] as int? ?? 0);
              final helped = (u['helpCount'] as int? ?? 0);
              final streak = (u['streak'] as int? ?? 0);
              final name = u['fullName'] as String? ?? '?';
              final photo = u['profilePic'] as String?;
              final uid = u['id'] as int?;
              final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
              final isTop3 = i < 3;
              final rankColors = [
                const Color(0xFFFFD700),
                const Color(0xFFC0C0C0),
                const Color(0xFFCD7F32),
              ];

              return Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(
                      i == 0 ? 20 : (i == _topHelpers.length - 1 ? 20 : 0),
                    ),
                    onTap: uid != null
                        ? () => _goToProfile(context, uid)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // ── Rank medal / number ──
                          SizedBox(
                            width: 28,
                            child: isTop3
                                ? Text(
                                    ['🥇', '🥈', '🥉'][i],
                                    style: const TextStyle(fontSize: 18),
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kInkLight,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),

                          // ── Avatar: profile photo or initial ──
                          _buildAvatar(
                            photoUrl: photo,
                            initial: initial,
                            size: 38,
                            gradientColors: isTop3
                                ? [
                                    rankColors[i].withOpacity(0.8),
                                    rankColors[i],
                                  ]
                                : [kViolet, kVioletLight],
                          ),
                          const SizedBox(width: 10),

                          // ── Name + badge + streak ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tappable name
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: kInk,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 11,
                                      color: kVioletLight,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _badgeForPoints(pts),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _badgeColor(pts),
                                      ),
                                    ),
                                    if (streak > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '🔥 $streak day',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kBlush,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Points + helped count ──
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$pts pts',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  color: kInkMid,
                                  fontSize: 14,
                                ),
                              ),
                              Text('Helped $helped', style: labelText),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < _topHelpers.length - 1)
                    Divider(height: 1, color: kBorderGlass.withOpacity(0.60)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: kHeroGrad,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(label, style: buttonText),
        ],
      ),
    ),
  );
}
