import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:final_project/frontend/dashboard.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  PEERAID — Aurora Pastel Palette                            ║
// ║  Periwinkle · Lilac · Blush · Mint gradient ombre           ║
// ╚══════════════════════════════════════════════════════════════╝
const kBase         = Color(0xFFF0EEFF);
const kBaseAlt      = Color(0xFFFAF8FF);
const kInk          = Color(0xFF1E1B4B);
const kInkMid       = Color(0xFF4338CA);
const kInkLight     = Color(0xFF818CF8);
const kInkMuted     = Color(0xFFA5B4FC);
const kViolet       = Color(0xFF7B6CF6);
const kVioletLight  = Color(0xFFA78BFA);
const kVioletSoft   = Color(0xFFEDE9FE);
const kVioletPale   = Color(0xFFF5F3FF);
const kBlush        = Color(0xFFF472B6);
const kBlushSoft    = Color(0xFFFCE7F3);
const kMint         = Color(0xFF34D399);
const kMintSoft     = Color(0xFFD1FAE5);
const kSky          = Color(0xFF60A5FA);
const kSkySoft      = Color(0xFFDBEAFE);
const kAmber        = Color(0xFFFCD34D);
const kAmberSoft    = Color(0xFFFEF3C7);
const kBorderGlass  = Color(0xFFE0D9FF);

// Gradient helpers
const kHeroGrad = LinearGradient(
  colors: [Color(0xFFE8E4FF), Color(0xFFF0DEFF), Color(0xFFFFE4F0)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
const kVioletGrad = LinearGradient(
  colors: [kViolet, kVioletLight],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

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
  int _tab = 0;
  User? _user;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _screens = [
      DashboardHome(localUserId: widget.localUserId),
      CommunityFeedScreen(localUserId: widget.localUserId),
    ];
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
        child: KeyedSubtree(key: ValueKey(_tab), child: _screens[_tab]),
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
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kViolet.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              // Hamburger
              Builder(builder: (ctx) => GestureDetector(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: _glassBtn(icon: Icons.menu_rounded),
              )),
              const SizedBox(width: 12),

              // Wordmark
              ShaderMask(
                shaderCallback: (b) => kVioletGrad.createShader(b),
                child: const Text("PeerAid",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ),

              const Spacer(),

              // Page chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kViolet.withOpacity(0.25), width: 1),
                ),
                child: Text(
                  _tab == 0 ? "✦  Dashboard" : "✦  Community",
                  style: const TextStyle(
                    color: kViolet, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Notification bell
              _glassBtn(
                icon: Icons.notifications_outlined,
                bg: kAmberSoft,
                iconColor: const Color(0xFFD97706),
                badge: true,
              ),

              const SizedBox(width: 8),

              // Avatar / logout
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
                    boxShadow: [BoxShadow(
                        color: kViolet.withOpacity(0.35),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: _user?.photoURL != null
                      ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(_user!.photoURL!, fit: BoxFit.cover))
                      : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
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
                decoration: BoxDecoration(
                    color: kBlush, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2))),
          ),
      ]),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navPill(0, Icons.dashboard_rounded, "Dashboard"),
              _navPill(1, Icons.people_alt_rounded, "Community"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navPill(int index, IconData icon, String label) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
            horizontal: active ? 22 : 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: active ? kVioletGrad : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [BoxShadow(color: kViolet.withOpacity(0.30),
              blurRadius: 14, offset: const Offset(0, 5))]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? Colors.white : kInkMuted, size: 20),
          if (active) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 13, letterSpacing: -0.2)),
          ],
        ]),
      ),
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: kBaseAlt,
      width: 292,
      child: Column(children: [
        // Header — gradient
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFE879F9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Avatar
                Container(
                  width: 66, height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2.5),
                    color: Colors.white.withOpacity(0.20),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: _user?.photoURL != null
                      ? ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.network(_user!.photoURL!, fit: BoxFit.cover))
                      : const Icon(Icons.person_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 14),
                Text(_user?.displayName ?? 'Campus Student',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.w900,
                        letterSpacing: -0.4)),
                const SizedBox(height: 3),
                Text(_user?.email ?? 'Local Account',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.70), fontSize: 12)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.40), width: 1),
                  ),
                  child: const Text("✦  Active Member",
                      style: TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                ),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Menu items
        Expanded(
          child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _drawerTile(Icons.home_rounded, "Home",
                    kVioletSoft, kViolet,
                        () => Navigator.pop(context)),
                _drawerTile(Icons.person_rounded, "My Profile",
                    kBlushSoft, kBlush, () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(localUserId: widget.localUserId)));
                    }),
                _drawerTile(Icons.people_alt_rounded, "Community Feed",
                    kMintSoft, kMint, () {
                      Navigator.pop(context);
                      setState(() => _tab = 1);
                    }),
                _drawerTile(Icons.edit_note_rounded, "Create Post",
                    kAmberSoft, const Color(0xFFD97706), () {
                      Navigator.pop(context);
                      setState(() => _tab = 1);
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
              ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => kVioletGrad.createShader(b),
              child: const Text("PeerAid",
                  style: TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            ),
            const Spacer(),
            Text("© 2025",
                style: TextStyle(color: kInkMuted.withOpacity(0.60),
                    fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _drawerTile(IconData icon, String title,
      Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withOpacity(0.20), width: 1.2),
        ),
        child: Row(children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: fg, fontSize: 14,
              fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              color: fg.withOpacity(0.40), size: 12),
        ]),
      ),
    );
  }
}