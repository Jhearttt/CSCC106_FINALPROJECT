import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:flutter/material.dart';

const _kV1 = Color(0xFF7B6CF6);
const _kV2 = Color(0xFFA78BFA);
const _kV3 = Color(0xFFEC4899);
const _kMint  = Color(0xFF34D399);
const _kSky   = Color(0xFF60A5FA);
const _kAmber = Color(0xFFFCD34D);
const _kInk   = Color(0xFF1E1B4B);
const _kMuted = Color(0xFFA5B4FC);
const _kBorder = Color(0xFFE0D9FF);

const _grad = LinearGradient(
  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

// ─── Animated signup background (different geometry from login) ───────────────
class _SignUpBgPainter extends CustomPainter {
  final double t;
  _SignUpBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final W = s.width, H = s.height;

    // ── Deep base (warmer tint than login) ──────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF200A3E), Color(0xFF1A1060), Color(0xFF0E1A3A)],
        begin: Alignment.topRight, end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, W, H)));

    // ── Orbs ────────────────────────────────────────────────────────────────
    void orb(double cx, double cy, double r, Color c, double op) {
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..shader = RadialGradient(
            colors: [c.withOpacity(op), c.withOpacity(0)])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    }
    final p1 = 1.0 + 0.08 * cos(t * 2 * pi);
    final p2 = 1.0 + 0.07 * sin(t * 2 * pi + 1.5);
    final p3 = 1.0 + 0.06 * cos(t * 2 * pi + 3.0);

    orb(W * 1.0,  H * 0.0,  W * 0.80 * p1, _kV3,  0.50);
    orb(W * 0.0,  H * 0.12, W * 0.65 * p2, _kV1,  0.42);
    orb(W * 0.5,  H * 0.4,  W * 0.50 * p3, _kV2,  0.22);
    orb(W * 1.0,  H * 0.70, W * 0.60 * p1, _kSky, 0.28);
    orb(W * 0.0,  H * 0.90, W * 0.55 * p2, _kMint,0.28);
    orb(W * 0.5,  H * 0.85, W * 0.30 * p3, _kAmber.withOpacity(0.5), 0.14);

    // ── Rotating diamond / square grid ──────────────────────────────────────
    canvas.save();
    canvas.translate(W * 0.5, H * 0.5);
    canvas.rotate(t * 2 * pi * 0.04); // slow rotation
    final gridPaint = Paint()
      ..color = _kV2.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const spacing = 38.0;
    for (double x = -W; x < W; x += spacing)
      for (double y = -H; y < H; y += spacing) {
        canvas.drawRect(Rect.fromCenter(
            center: Offset(x, y), width: spacing * 0.55, height: spacing * 0.55),
            gridPaint);
      }
    canvas.restore();

    // ── Triangle accent top-right ────────────────────────────────────────────
    final triPaint = Paint()
      ..color = _kV3.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final triPath = Path()
      ..moveTo(W * 0.70, -10)
      ..lineTo(W * 1.10, H * 0.22)
      ..lineTo(W * 0.40, H * 0.18)
      ..close();
    canvas.drawPath(triPath, triPaint);
    // inner
    final triPath2 = Path()
      ..moveTo(W * 0.78, H * 0.02)
      ..lineTo(W * 1.00, H * 0.18)
      ..lineTo(W * 0.56, H * 0.15)
      ..close();
    canvas.drawPath(triPath2,
        triPaint..color = _kV2.withOpacity(0.08));

    // ── Wave bands ────────────────────────────────────────────────────────────
    for (int band = 0; band < 3; band++) {
      final wavePath = Path();
      final baseY = H * (0.30 + band * 0.12);
      final amp   = 18.0 + band * 6;
      final freq  = 2.5 + band * 0.5;
      final phase = t * 2 * pi + band * pi / 3;
      wavePath.moveTo(0, baseY);
      for (double x = 0; x <= W; x += 2) {
        final y = baseY + amp * sin(freq * pi * x / W + phase);
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, Paint()
        ..color = [_kV1, _kV2, _kMint][band].withOpacity(0.10 - band * 0.025)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 - band * 0.3);
    }

    // ── Deep animated sine wave bank (replaces flat scan line) ───────────────
    final deepWaves = [
      // [baseY_frac, amp, freq, speed, strokeW, color, opacity]
      [0.58, 26.0, 2.0, 0.9,  30.0, _kV3,   0.20],
      [0.64, 18.0, 3.2, 1.5,  16.0, _kSky,  0.16],
      [0.70, 12.0, 4.5, 1.1,   9.0, _kAmber,0.13],
      [0.76, 22.0, 1.6, 2.0,  20.0, _kV2,   0.15],
      [0.82, 10.0, 5.5, 0.7,   6.0, _kMint, 0.11],
    ];

    for (final dw in deepWaves) {
      final baseY = H * (dw[0] as double);
      final amp   = dw[1] as double;
      final freq  = dw[2] as double;
      final speed = dw[3] as double;
      final sw    = dw[4] as double;
      final wc    = dw[5] as Color;
      final op    = dw[6] as double;
      final phase = t * 2 * pi * speed;

      final wp = Path();
      wp.moveTo(0, baseY + amp * sin(phase));
      for (double x = 1; x <= W; x += 2) {
        final y = baseY + amp * sin(freq * pi * x / W + phase);
        wp.lineTo(x, y);
      }
      canvas.drawPath(wp, Paint()
        ..shader = LinearGradient(colors: [
          Colors.transparent,
          wc.withOpacity(op),
          wc.withOpacity(op * 1.4),
          wc.withOpacity(op),
          Colors.transparent,
        ], stops: const [0.0, 0.20, 0.50, 0.80, 1.0])
            .createShader(Rect.fromLTWH(0, baseY - amp, W, amp * 2))
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // ── Sparkle / star field ──────────────────────────────────────────────────
    final sparkFill = Paint()..style = PaintingStyle.fill;
    final stars = [
      [0.08, 0.10, 3.5, _kAmber], [0.92, 0.16, 2.5, _kV2],
      [0.18, 0.55, 2.0, _kMint],  [0.85, 0.48, 3.0, _kV3],
      [0.28, 0.82, 2.5, _kSky],   [0.72, 0.88, 3.5, _kV1],
      [0.55, 0.06, 2.0, _kV3],    [0.42, 0.50, 3.0, _kAmber],
      [0.95, 0.72, 2.0, _kMint],  [0.05, 0.76, 3.5, _kV2],
    ];
    for (final st in stars) {
      final px = W * (st[0] as double);
      final py = H * (st[1] as double);
      final pr = st[2] as double;
      final pc = (st[3] as Color).withOpacity(
          0.50 + 0.40 * sin(t * 2 * pi + px * 0.07));
      sparkFill.color = pc;
      final path = Path();
      for (int j = 0; j < 8; j++) {
        final a = j * pi / 4;
        final r = j.isEven ? pr : pr * 0.38;
        final x = px + r * cos(a);
        final y = py + r * sin(a);
        j == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, sparkFill);
    }

    // ── Hexagonal rings (large) ────────────────────────────────────────────────
    for (final cfg in [
      [0.18, 0.22, W * 0.22, _kV1, 0.10],
      [0.82, 0.75, W * 0.18, _kV3, 0.10],
    ]) {
      final cx = W * (cfg[0] as double);
      final cy = H * (cfg[1] as double);
      final r  = cfg[2] as double;
      final c  = cfg[3] as Color;
      final op = cfg[4] as double;
      final hexPath = Path();
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3 + t * 2 * pi * 0.06;
        final x = cx + r * cos(a);
        final y = cy + r * sin(a);
        i == 0 ? hexPath.moveTo(x, y) : hexPath.lineTo(x, y);
      }
      hexPath.close();
      canvas.drawPath(hexPath, Paint()
        ..color = c.withOpacity(op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    }

    // ── Particle dot mesh ─────────────────────────────────────────────────────
    final pDot = Paint()..color = _kV2.withOpacity(0.08);
    for (double x = 18; x < W; x += 22)
      for (double y = 18; y < H; y += 22) {
        final b = 0.5 + 0.5 * sin(t * 2 * pi * 1.3 + x * 0.04 + y * 0.04);
        pDot.color = _kV2.withOpacity(0.04 + 0.10 * b);
        canvas.drawCircle(Offset(x, y), 0.9, pDot);
      }

    // ── Corner glows ──────────────────────────────────────────────────────────
    canvas.drawArc(Rect.fromCircle(center: Offset(W, H), radius: W * 0.42),
        pi, pi / 2, false, Paint()
          ..color = _kMint.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawArc(Rect.fromCircle(center: Offset(0, 0), radius: W * 0.38),
        0, pi / 2, false, Paint()
          ..color = _kV1.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _SignUpBgPainter old) => old.t != t;
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(debugShowCheckedModeBanner: false, home: SignUpScreenHome());
}

class SignUpScreenHome extends StatefulWidget {
  @override
  State<SignUpScreenHome> createState() => _SignUpScreenHomeState();
}

class _SignUpScreenHomeState extends State<SignUpScreenHome>
    with TickerProviderStateMixin {
  bool _hidePass = true, _hideConfirm = true, _isLoading = false;

  final _nameCtrl    = TextEditingController();
  final _userCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _nameFocus    = FocusNode();
  final _userFocus    = FocusNode();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  late AnimationController _bgCtrl;
  late AnimationController _inCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 9))..repeat();
    _inCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950));
    _fadeAnim  = CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutCubic));
    for (final fn in [_nameFocus, _userFocus, _emailFocus, _passFocus, _confirmFocus])
      fn.addListener(() => setState(() {}));
    _inCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _inCtrl.dispose();
    for (final fn in [_nameFocus, _userFocus, _emailFocus, _passFocus, _confirmFocus])
      fn.dispose();
    for (final c in [_nameCtrl, _userCtrl, _emailCtrl, _passCtrl, _confirmCtrl])
      c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty)  { _err("Full name is required"); return; }
    if (_userCtrl.text.trim().isEmpty)  { _err("Username is required");  return; }
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _err("Please enter a valid email address"); return;
    }
    if (_passCtrl.text.isEmpty)    { _err("Password is required");         return; }
    if (_confirmCtrl.text.isEmpty) { _err("Please confirm your password"); return; }
    if (_passCtrl.text != _confirmCtrl.text) { _err("Passwords do not match"); return; }

    setState(() => _isLoading = true);
    final result = await DatabaseHelper().insertUser(
      fullName: _nameCtrl.text.trim(), userName: _userCtrl.text.trim(),
      password: _passCtrl.text, email: email.isNotEmpty ? email : null,
    );
    setState(() => _isLoading = false);

    if (result > 0) {
      AwesomeDialog(width: 300, context: context,
          title: "You're in! 🎉",
          desc: "Account created. Welcome to CampusAid!",
          dialogType: DialogType.success, btnOkColor: _kV1,
          btnOkOnPress: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()))).show();
    } else {
      _err("Username already taken. Please try another.");
    }
  }

  void _err(String msg) {
    AwesomeDialog(width: 300, context: context, title: 'Oops!',
        desc: msg, dialogType: DialogType.error,
        btnOkColor: _kV1, btnOkOnPress: () {}).show();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFF200A3E),
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) => Stack(children: [

          CustomPaint(painter: _SignUpBgPainter(_bgCtrl.value),
              child: const SizedBox.expand()),

          // Frosted panel behind form
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: screenH * 0.72,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(44),
                    topRight: Radius.circular(44)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.10), width: 1.5),
                boxShadow: [BoxShadow(color: _kV1.withOpacity(0.15),
                    blurRadius: 50, offset: const Offset(0, -10))],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(children: [

                    const SizedBox(height: 16),

                    // Back button
                    Align(alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                  width: 1.4),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white.withOpacity(0.80), size: 17)),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Brand header
                    Container(
                      width: 78, height: 78,
                      decoration: BoxDecoration(
                        gradient: _grad,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: _kV1.withOpacity(0.55),
                              blurRadius: 28, offset: const Offset(0, 10)),
                          BoxShadow(color: _kV3.withOpacity(0.30),
                              blurRadius: 16, offset: const Offset(5, 7)),
                        ],
                        border: Border.all(
                            color: Colors.white.withOpacity(0.20), width: 1.5),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 34),
                    ),

                    const SizedBox(height: 14),

                    // ── App name ──
                    Text(
                      "CampusAid",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Create your account",
                        style: TextStyle(fontSize: 13,
                            color: Colors.white.withOpacity(0.45),
                            fontWeight: FontWeight.w400)),

                    const SizedBox(height: 24),

                    // Form card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.16), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.22),
                              blurRadius: 28, offset: const Offset(0, 10)),
                          BoxShadow(color: _kV1.withOpacity(0.18),
                              blurRadius: 18, offset: const Offset(0, 6)),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(children: [

                        _sectionHead(Icons.person_rounded,
                            "Personal Info", _kV1, _kV3),
                        const SizedBox(height: 16),

                        _field(ctrl: _nameCtrl, focus: _nameFocus,
                            label: "Full Name", hint: "e.g. Maria Santos",
                            icon: Icons.badge_rounded),
                        const SizedBox(height: 14),
                        _field(ctrl: _userCtrl, focus: _userFocus,
                            label: "Username", hint: "e.g. maria_s",
                            icon: Icons.alternate_email_rounded),
                        const SizedBox(height: 14),
                        _field(ctrl: _emailCtrl, focus: _emailFocus,
                            label: "Email (optional)",
                            hint: "e.g. maria@school.edu",
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress),

                        const SizedBox(height: 22),

                        _sectionHead(Icons.lock_rounded,
                            "Security", _kV3, _kV1),
                        const SizedBox(height: 16),

                        _field(ctrl: _passCtrl, focus: _passFocus,
                            label: "Password",
                            hint: "Create a strong password",
                            icon: Icons.lock_rounded, obscure: _hidePass,
                            suffix: GestureDetector(
                                onTap: () => setState(() => _hidePass = !_hidePass),
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Icon(
                                        _hidePass
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.white.withOpacity(0.35),
                                        size: 20)))),
                        const SizedBox(height: 14),
                        _field(ctrl: _confirmCtrl, focus: _confirmFocus,
                            label: "Confirm Password",
                            hint: "Repeat your password",
                            icon: Icons.lock_outline_rounded,
                            obscure: _hideConfirm,
                            suffix: GestureDetector(
                                onTap: () => setState(
                                        () => _hideConfirm = !_hideConfirm),
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Icon(
                                        _hideConfirm
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: Colors.white.withOpacity(0.35),
                                        size: 20)))),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // Create button
                    SizedBox(width: double.infinity, height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _grad,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(color: _kV1.withOpacity(0.55),
                                blurRadius: 24, offset: const Offset(0, 9)),
                            BoxShadow(color: _kV3.withOpacity(0.28),
                                blurRadius: 14, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18))),
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                              : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Text("Create My Account",
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.5, letterSpacing: 0.2)),
                              ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                          border: Border(top: BorderSide(
                              color: Colors.white.withOpacity(0.10), width: 1))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Already have an account?  ",
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 13.5)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen())),
                              child: const Text("Sign in",
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w800, fontSize: 13.5)),
                              ),

                          ]),
                    ),
                    const SizedBox(height: 6),
                    Text("CampusAid © 2025",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.22), fontSize: 11)),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionHead(IconData icon, String label, Color c1, Color c2) =>
      Row(children: [
        Container(width: 30, height: 30,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c1, c2],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: Colors.white, size: 15)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
      ]);

  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
  }) {
    final focused = focus.hasFocus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: focused ? _kV2 : Colors.white.withOpacity(0.45),
          fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withOpacity(0.13)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: focused ? _kV2.withOpacity(0.65) : Colors.white.withOpacity(0.11),
              width: focused ? 1.8 : 1.0),
          boxShadow: focused ? [BoxShadow(color: _kV1.withOpacity(0.22),
              blurRadius: 14, offset: const Offset(0, 4))] : [],
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(left: 14),
              child: Icon(icon,
                  color: focused ? _kV2 : Colors.white.withOpacity(0.30),
                  size: 20)),
          Expanded(child: TextField(
            controller: ctrl, focusNode: focus,
            obscureText: obscure, keyboardType: keyboard,
            style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.25), fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 12),
            ),
          )),
          if (suffix != null) suffix,
        ]),
      ),
    ]);
  }
}