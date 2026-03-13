import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ───────────────── COLORS ─────────────────
const kBase = Color(0xFFF0EEFF);
const kInk = Color(0xFF1E1B4B);
const kInkMid = Color(0xFF4338CA);
const kInkLight = Color(0xFF818CF8);

const kViolet = Color(0xFF7B6CF6);
const kVioletLight = Color(0xFFA78BFA);
const kBlush = Color(0xFFF472B6);
const kMint = Color(0xFF34D399);
const kAmber = Color(0xFFFCD34D);

const kBorderGlass = Color(0xFFE0D9FF);

const kHeroGrad = LinearGradient(
  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// ───────────────── TYPOGRAPHY ─────────────────
TextStyle headingXL = GoogleFonts.poppins(
  fontSize: 26,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.6,
  color: kInk,
);

TextStyle headingLG = GoogleFonts.poppins(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.4,
  color: kInk,
);

TextStyle statNumber = GoogleFonts.poppins(
  fontSize: 30,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.8,
  color: kInkMid,
);

TextStyle bodyText = GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kInkLight,
);

TextStyle labelText = GoogleFonts.inter(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: kInkLight,
);

TextStyle buttonText = GoogleFonts.inter(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
  color: Colors.white,
);

/// ───────────────── DASHBOARD ─────────────────
class Dashboard extends StatelessWidget {
  final int? localUserId;

  const Dashboard({super.key, this.localUserId});

  @override
  Widget build(BuildContext context) {
    return DashboardHome(localUserId: localUserId);
  }
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
    "totalUsers": 0
  };

  bool _loading = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper().getDashboardStats();

    setState(() {
      _stats = stats;
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
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [

              _buildWelcomeBanner(),

              const SizedBox(height: 24),

              _buildStatsGrid(),

              const SizedBox(height: 24),

              _buildCommunitySnapshot(),

              const SizedBox(height: 24),

              _buildQuickActions(),

              const SizedBox(height: 24),

              _buildInsightCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// ───────── WELCOME BANNER ─────────
  Widget _buildWelcomeBanner() {
    final name = _user?.displayName?.split(" ").first ?? "Student";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: kHeroGrad,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            "$greeting 👋",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
            ),
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

          const SizedBox(height: 18),

          Text(
            "Student Help & Skills Network",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Connect · Learn · Grow Together",
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// ───────── STATS GRID ─────────
  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [

        _buildStatCard(Icons.article_rounded, "Total Posts",
            _stats["totalPosts"].toString()),

        _buildStatCard(Icons.help_outline_rounded, "Open Requests",
            _stats["openRequests"].toString()),

        _buildStatCard(Icons.lightbulb_outline_rounded, "Skill Offers",
            _stats["skillOffers"].toString()),

        _buildStatCard(Icons.people_outline_rounded, "Total Users",
            _stats["totalUsers"].toString()),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String label, String count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderGlass),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(icon, color: kViolet, size: 28),

          const SizedBox(height: 10),

          Text(count, style: statNumber),

          const SizedBox(height: 4),

          Text(label, style: labelText),
        ],
      ),
    );
  }

  /// ───────── SNAPSHOT ─────────
  Widget _buildCommunitySnapshot() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [

          Expanded(
            child: _miniStat("Help Requests", _stats["openRequests"]!, kBlush),
          ),

          Expanded(
            child: _miniStat("Skill Offers", _stats["skillOffers"]!, kMint),
          ),

          Expanded(
            child: _miniStat("Total Posts", _stats["totalPosts"]!, kViolet),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Column(
      children: [

        Icon(Icons.circle, color: color, size: 16),

        const SizedBox(height: 6),

        Text("$value", style: headingLG),

        Text(label, style: labelText),
      ],
    );
  }

  /// ───────── QUICK ACTIONS ─────────
  Widget _buildQuickActions() {
    return Row(
      children: [

        Expanded(
          child: _actionBtn(
            icon: Icons.add,
            label: "Create Post",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CreatePostScreen(localUserId: widget.localUserId),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _actionBtn(
            icon: Icons.explore,
            label: "Browse Feed",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommunityFeedScreen(localUserId: widget.localUserId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: kHeroGrad,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [

            Icon(icon, color: Colors.white),

            const SizedBox(height: 6),

            Text(label, style: buttonText),
          ],
        ),
      ),
    );
  }

  /// ───────── INSIGHT CARD ─────────
  Widget _buildInsightCard() {
    final open = _stats["openRequests"]!;
    final skills = _stats["skillOffers"]!;

    String message;

    if (open > skills) {
      message =
      "Many students need help right now. Consider offering a skill.";
    } else if (skills > open) {
      message =
      "Lots of skill offers are available. Explore the community feed.";
    } else {
      message =
      "The community has a balanced mix of help and skills.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kHeroGrad,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [

          const Icon(Icons.auto_awesome, color: Colors.white),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}