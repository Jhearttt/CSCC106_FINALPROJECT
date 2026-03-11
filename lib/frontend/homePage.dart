import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:final_project/frontend/dashboard.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:final_project/frontend/profileScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Homepage extends StatelessWidget {
  final int? localUserId;
  const Homepage({super.key, this.localUserId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePageHome(localUserId: localUserId),
    );
  }
}

class HomePageHome extends StatefulWidget {
  final int? localUserId;
  const HomePageHome({super.key, this.localUserId});

  @override
  State<HomePageHome> createState() => _HomePageHomeState();
}

class _HomePageHomeState extends State<HomePageHome> {
  late List<Widget> screens;
  var selectedIndex = 0;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    // ── CHANGED: NotesScreen → CommunityFeedScreen, added correct params ──
    screens = [
      DashboardHome(localUserId: widget.localUserId),
      CommunityFeedScreen(localUserId: widget.localUserId),
    ];
  }

  void _getCurrentUser() {
    setState(() => _currentUser = FirebaseAuth.instance.currentUser);
  }

  String _getAppBarTitle() {
    switch (selectedIndex) {
      case 0: return "Dashboard";
      case 1: return "Community Feed";
      default: return "CampusAid";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_getAppBarTitle(), style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800,
            color: Color(0xFF0D47A1), letterSpacing: -0.3)),
        leading: Builder(
          builder: (context) => GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55), shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.18),
                    blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.menu_rounded, color: Color(0xFF1E88E5), size: 20),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                await AuthService().signOut();
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.55), shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF90CAF9), width: 1.5),
                  boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.18),
                      blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFF1E88E5), size: 20),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: screens[selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFBBDEFB), width: 1))),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (int index) => setState(() => selectedIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E88E5),
          unselectedItemColor: const Color(0xFF90CAF9),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard, color: Color(0xFF1E88E5)),
                label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.dynamic_feed_outlined),
                activeIcon: Icon(Icons.dynamic_feed, color: Color(0xFF1E88E5)),
                label: 'Feed'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFBBDEFB), Color(0xFF90CAF9)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Drawer header ──
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      backgroundImage: _currentUser?.photoURL != null
                          ? NetworkImage(_currentUser!.photoURL!) : null,
                      child: _currentUser?.photoURL == null
                          ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 14),
                    Text(_currentUser?.displayName ?? 'Guest User',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_currentUser?.email ?? 'Local Account',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),

            // ── Drawer items ──
            _drawerItem(Icons.home_rounded, 'Home', () => Navigator.pop(context)),
            _drawerItem(Icons.person_rounded, 'My Profile', () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileScreen(localUserId: widget.localUserId)));
            }),
            _drawerItem(Icons.dynamic_feed_rounded, 'Community Feed', () {
              Navigator.pop(context);
              setState(() => selectedIndex = 1);
            }),
            _drawerItem(Icons.add_circle_outline_rounded, 'Create Post', () {
              Navigator.pop(context);
              setState(() => selectedIndex = 1);
            }),
            const Divider(color: Color(0xFFBBDEFB)),
            _drawerItem(Icons.logout_rounded, 'Log Out', () async {
              Navigator.pop(context);
              await AuthService().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            }, color: const Color(0xFFEF5350)),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0D47A1)),
      title: Text(title, style: TextStyle(color: color ?? const Color(0xFF0D47A1), fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}// TODO Implement this library.