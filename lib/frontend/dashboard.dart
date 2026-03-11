import 'dart:math';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/createPostScreen.dart';
import 'package:final_project/frontend/communityFeedScreen.dart';
import 'package:flutter/material.dart';

// ─── Painters ─────────────────────────────────────────────────────────────────
class DashboardGeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p0 = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.18);
    final p1 = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.22);
    final p2 = Paint()..color = const Color(0xFF1E88E5).withOpacity(0.10);
    final p3 = Paint()..color = const Color(0xFFBBDEFB).withOpacity(0.30);
    final p4 = Paint()..color = const Color(0xFF42A5F5).withOpacity(0.15);

    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width * 0.45, 0)
      ..lineTo(0, size.height * 0.22)..close(), p0);
    canvas.drawPath(Path()..moveTo(size.width, 0)..lineTo(size.width, size.height * 0.18)
      ..lineTo(size.width * 0.58, 0)..close(), p1);
    canvas.drawPath(Path()..moveTo(size.width * 0.30, 0)..lineTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.55, size.height * 0.08)..lineTo(size.width * 0.13, size.height * 0.08)..close(), p3);
    _drawHexagon(canvas, Offset(size.width * 0.88, size.height * 0.10), size.width * 0.07, p4);
    _drawDiamond(canvas, Offset(size.width * 0.04, size.height * 0.42), size.width * 0.06, p3);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.50)..lineTo(size.width * 0.65, size.height * 0.38)
      ..lineTo(size.width * 0.65, size.height * 0.41)..lineTo(0, size.height * 0.53)..close(), p1);
    canvas.drawPath(Path()..moveTo(size.width, size.height * 0.70)..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.38, size.height)..close(), p0);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.82)..lineTo(0, size.height)
      ..lineTo(size.width * 0.32, size.height)..close(), p1);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.92)..lineTo(0, size.height)
      ..lineTo(size.width * 0.14, size.height)..close(), p2);
    _drawHexagon(canvas, Offset(size.width * 0.85, size.height * 0.88), size.width * 0.08, p4);
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width * 0.50, size.height), radius: size.width * 0.35),
        pi, pi, true, Paint()..color = const Color(0xFF64B5F6).withOpacity(0.12));
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final x = center.dx + radius * cos(angle); final y = center.dy + radius * sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close(); canvas.drawPath(path, paint);
  }

  void _drawDiamond(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawPath(Path()..moveTo(c.dx, c.dy - r)..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)..lineTo(c.dx - r, c.dy)..close(), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E88E5).withOpacity(0.08)..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = spacing; x < size.width; x += spacing)
      for (double y = spacing; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.4, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

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
  Map<String, int> _stats = {'totalPosts': 0, 'openRequests': 0, 'skillOffers': 0, 'totalUsers': 0};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // ── NEW: getDashboardStats() fetches all counts in one call ──
    final stats = await DatabaseHelper().getDashboardStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final width  = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0.0, 0.35, 0.68, 1.0],
          ),
        ),
      ),
      CustomPaint(painter: DashboardGeometricPainter(), child: const SizedBox.expand()),
      IgnorePointer(child: CustomPaint(painter: _DotGridPainter(), child: const SizedBox.expand())),

      SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
            : RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(children: [

              // ── Welcome banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50), width: 1.2),
                  boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.12),
                      blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1565C0)]),
                      boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.35),
                          blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text("CampusAid", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: Color(0xFF0D47A1))),
                    Text("Student Help & Skills Network", style: TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
                  ]),
                ]),
              ),

              // ── Stats grid ──
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14, mainAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _buildStatCard(icon: Icons.article_rounded, label: "Total Posts",
                      count: '${_stats['totalPosts']}',
                      gradientColors: [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                      glowColor: const Color(0xFF1E88E5)),
                  _buildStatCard(icon: Icons.help_outline_rounded, label: "Open Requests",
                      count: '${_stats['openRequests']}',
                      gradientColors: [const Color(0xFFEF5350), const Color(0xFFB71C1C)],
                      glowColor: const Color(0xFFEF5350)),
                  _buildStatCard(icon: Icons.lightbulb_outline_rounded, label: "Skill Offers",
                      count: '${_stats['skillOffers']}',
                      gradientColors: [const Color(0xFF66BB6A), const Color(0xFF1B5E20)],
                      glowColor: const Color(0xFF43A047)),
                  _buildStatCard(icon: Icons.people_outline_rounded, label: "Total Users",
                      count: '${_stats['totalUsers']}',
                      gradientColors: [const Color(0xFFAB47BC), const Color(0xFF4A148C)],
                      glowColor: const Color(0xFF8E24AA)),
                ],
              ),

              const SizedBox(height: 24),



              // ── Category breakdown ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50), width: 1.2),
                  boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.10),
                      blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Activity Overview", style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                  const SizedBox(height: 14),
                  _buildProgressRow("Help Requests", _stats['openRequests']!, _stats['totalPosts']!,
                      const Color(0xFFEF5350)),
                  const SizedBox(height: 10),
                  _buildProgressRow("Skill Offers", _stats['skillOffers']!, _stats['totalPosts']!,
                      const Color(0xFF43A047)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildStatCard({required IconData icon, required String label, required String count,
    required List<Color> gradientColors, required Color glowColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82), borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50), width: 1.2),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.white.withOpacity(0.80), blurRadius: 8, offset: const Offset(-3, -3)),
        ],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          height: 50, width: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: glowColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),
        Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFF1976D2).withOpacity(0.85),
            fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label,
    required List<Color> colors, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildProgressRow(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1976D2), fontWeight: FontWeight.w500)),
        Text('$value / $total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: pct, minHeight: 7,
            backgroundColor: const Color(0xFFBBDEFB),
            valueColor: AlwaysStoppedAnimation<Color>(color)),
      ),
    ]);
  }
}