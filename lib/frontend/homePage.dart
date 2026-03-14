import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/dashboard.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const kBase        = Color(0xFFF0EEFF);
const kBaseAlt     = Color(0xFFFAF8FF);
const kInk         = Color(0xFF1E1B4B);
const kInkMid      = Color(0xFF4338CA);
const kInkLight    = Color(0xFF818CF8);
const kInkMuted    = Color(0xFFA5B4FC);
const kViolet      = Color(0xFF7B6CF6);
const kVioletLight = Color(0xFFA78BFA);
const kVioletSoft  = Color(0xFFEDE9FE);
const kVioletPale  = Color(0xFFF5F3FF);
const kBlush       = Color(0xFFF472B6);
const kBlushSoft   = Color(0xFFFCE7F3);
const kMint        = Color(0xFF34D399);
const kMintSoft    = Color(0xFFD1FAE5);
const kSky         = Color(0xFF60A5FA);
const kSkySoft     = Color(0xFFDBEAFE);
const kAmber       = Color(0xFFFCD34D);
const kAmberSoft   = Color(0xFFFEF3C7);
const kBorderGlass = Color(0xFFE0D9FF);

const kHeroGrad = LinearGradient(
  colors: [Color(0xFFE8E4FF), Color(0xFFF0DEFF), Color(0xFFFFE4F0)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
const kVioletGrad = LinearGradient(
  colors: [kViolet, kVioletLight],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

// ─── Nav tab index constants (per SRS: Dashboard, Community, Create Post, Profile)
const _tabDashboard  = 0;
const _tabCommunity  = 1;
const _tabCreate     = 2;
const _tabProfile    = 3;

class Homepage extends StatelessWidget {
  final int? localUserId;
  const Homepage({super.key, this.localUserId});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(scaffoldBackgroundColor: kBase),
    home: HomePageHome(localUserId: localUserId),
  );
}

class HomePageHome extends StatefulWidget {
  final int? localUserId;
  const HomePageHome({super.key, this.localUserId});

  @override
  State<HomePageHome> createState() => _HomePageHomeState();
}

class _HomePageHomeState extends State<HomePageHome>
    with SingleTickerProviderStateMixin {
  // SRS navigation: Dashboard | Community Feed | Create Post | Profile
  int _tab = _tabDashboard;
  User? _user;

  // Screens for tab indices 0, 1, 3 — Create Post (index 2) is launched modally
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _screens = [
      DashboardHome(localUserId: widget.localUserId),           // 0 Dashboard
      CommunityFeedScreen(localUserId: widget.localUserId),     // 1 Community
      null,                                                      // 2 Create Post — modal
      ProfileScreen(localUserId: widget.localUserId,            // 3 Profile
          embeddedMode: true),
    ];
  }

  // ── Create Post tab launches as a full screen then returns to Community ──
  void _handleTabTap(int index) {
    if (index == _tabCreate) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreatePostScreen(localUserId: widget.localUserId),
      )).then((_) {
        // After returning from create, switch to Community Feed
        setState(() => _tab = _tabCommunity);
      });
      return;
    }
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBase,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_tab),
          child: _screens[_tab] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(66),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEDE9FE), Color(0xFFFAF5FF)],
            begin: Alignment.centerLeft, end: Alignment.centerRight,
          ),
          boxShadow: [BoxShadow(color: kViolet.withOpacity(0.12),
              blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Builder(builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: _glassBtn(icon: Icons.menu_rounded),
              )),
              const SizedBox(width: 12),
              ShaderMask(
                shaderCallback: (b) => kVioletGrad.createShader(b),
                child: const Text("PeerAid", style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.8)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kViolet.withOpacity(0.25), width: 1),
                ),
                child: Text(_tabLabel(_tab), style: const TextStyle(
                    color: kViolet, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2)),
              ),
              const SizedBox(width: 8),
              _glassBtn(icon: Icons.notifications_outlined,
                  bg: kAmberSoft, iconColor: const Color(0xFFD97706), badge: true),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false,
                    );
                  }
                },
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: kVioletGrad,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: kViolet.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: _user?.photoURL != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(11),
                      child: Image.network(_user!.photoURL!, fit: BoxFit.cover))
                      : const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _tabLabel(int tab) {
    switch (tab) {
      case _tabDashboard: return '✦  Dashboard';
      case _tabCommunity: return '✦  Community';
      case _tabCreate:    return '✦  Create Post';
      case _tabProfile:   return '✦  Profile';
      default:            return '✦  PeerAid';
    }
  }

  Widget _glassBtn({
    required IconData icon,
    Color? bg,
    Color iconColor = kViolet,
    bool badge = false,
  }) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderGlass, width: 1.2),
        boxShadow: [BoxShadow(color: kViolet.withOpacity(0.07),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(icon, color: iconColor, size: 19),
        if (badge)
          Positioned(top: 8, right: 8,
            child: Container(width: 7, height: 7,
                decoration: BoxDecoration(color: kBlush, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2))),
          ),
      ]),
    );
  }

  // ── Bottom Nav — 4 tabs per SRS ────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAF8FF), Color(0xFFEEEBFF)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: kBorderGlass, width: 1.2)),
        boxShadow: [BoxShadow(color: kViolet.withOpacity(0.08),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navPill(_tabDashboard,  Icons.dashboard_rounded,    "Dashboard"),
              _navPill(_tabCommunity,  Icons.people_alt_rounded,   "Community"),
              _navPill(_tabProfile,    Icons.person_rounded,       "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navPill(int index, IconData icon, String label) {
    final active = _tab == index;
    // Create Post pill uses a distinct blush accent to stand out
    final isCreate = index == _tabCreate;
    final activeGrad = isCreate
        ? const LinearGradient(colors: [Color(0xFFEC4899), kBlush],
        begin: Alignment.topLeft, end: Alignment.bottomRight)
        : kVioletGrad;
    final activeShadow = isCreate
        ? kBlush.withOpacity(0.30)
        : kViolet.withOpacity(0.30);

    return GestureDetector(
      onTap: () => _handleTabTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: active ? 18 : 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? activeGrad : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [BoxShadow(color: activeShadow, blurRadius: 14, offset: const Offset(0, 5))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? Colors.white : kInkMuted, size: 20),
          if (active) ...[
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 12, letterSpacing: -0.2)),
          ],
        ]),
      ),
    );
  }

  // ── Side Drawer ────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kBaseAlt, width: 292,
      child: Column(children: [
        // Header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFE879F9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
          child: SafeArea(bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 66, height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2.5),
                    color: Colors.white.withOpacity(0.20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: _user?.photoURL != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(17),
                      child: Image.network(_user!.photoURL!, fit: BoxFit.cover))
                      : const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 14),
                Text(_user?.displayName ?? 'Campus Student',
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text(_user?.email ?? 'Local Account',
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.40), width: 1),
                  ),
                  child: const Text("✦  Active Member",
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _drawerTile(Icons.home_rounded,       "Home",
                kVioletSoft, kViolet, () => Navigator.pop(context)),
            _drawerTile(Icons.dashboard_rounded,  "Dashboard",
                kSkySoft, kSky, () {
                  Navigator.pop(context); setState(() => _tab = _tabDashboard);
                }),
            _drawerTile(Icons.people_alt_rounded, "Community Feed",
                kMintSoft, kMint, () {
                  Navigator.pop(context); setState(() => _tab = _tabCommunity);
                }),
            _drawerTile(Icons.edit_note_rounded,  "Create Post",
                kAmberSoft, const Color(0xFFD97706), () {
                  Navigator.pop(context); _handleTabTap(_tabCreate);
                }),
            _drawerTile(Icons.person_rounded,     "My Profile",
                kBlushSoft, kBlush, () {
                  Navigator.pop(context); setState(() => _tab = _tabProfile);
                }),
            const SizedBox(height: 8),
            Divider(color: kBorderGlass, thickness: 1.2),
            const SizedBox(height: 4),
            _drawerTile(Icons.logout_rounded, "Sign Out",
                kBlushSoft, kBlush, () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (r) => false);
                  }
                }),
          ],
        )),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => kVioletGrad.createShader(b),
              child: const Text("PeerAid", style: TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ),
            const Spacer(),
            Text("© 2025", style: TextStyle(
                color: kInkMuted.withOpacity(0.60), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _drawerTile(IconData icon, String title, Color bg, Color fg,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withOpacity(0.20), width: 1.2),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: fg, fontSize: 14,
              fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: fg.withOpacity(0.40), size: 12),
        ]),
      ),
    );
  }
}