import 'dart:developer' as developer;
import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/homePage.dart';
import 'package:final_project/frontend/signUpScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kV1 = Color(0xFF7B6CF6);
const _kV2 = Color(0xFFA78BFA);
const _kV3 = Color(0xFFEC4899);
const _kV4 = Color(0xFF4F46E5);
const _kMint   = Color(0xFF34D399);
const _kSky    = Color(0xFF60A5FA);
const _kAmber  = Color(0xFFFCD34D);
const _kInk    = Color(0xFF1E1B4B);
const _kMuted  = Color(0xFFA5B4FC);
const _kBorder = Color(0xFFE0D9FF);

const _grad = LinearGradient(
  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA), Color(0xFFEC4899)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);

// ─── Animated background ──────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  final double t; // animation time 0..1
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final W = s.width, H = s.height;

    // ── 1. Deep gradient base ──────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A1040), Color(0xFF2D1B69), Color(0xFF1E1B4B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, W, H)));

    // ── 2. Pulsing aurora orbs ─────────────────────────────────────────────
    void orb(double cx, double cy, double r, Color c, double op) {
      canvas.drawCircle(Offset(cx, cy), r, Paint()
        ..shader = RadialGradient(
            colors: [c.withOpacity(op), c.withOpacity(0)])
            .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    }

    final pulse1 = 1.0 + 0.08 * sin(t * 2 * pi);
    final pulse2 = 1.0 + 0.06 * cos(t * 2 * pi + 1.0);
    final pulse3 = 1.0 + 0.07 * sin(t * 2 * pi + 2.0);

    orb(W * 0.0,  H * 0.0,  W * 0.85 * pulse1, _kV1,  0.55);
    orb(W * 1.0,  H * 0.08, W * 0.70 * pulse2, _kV3,  0.40);
    orb(W * 0.5,  H * 0.35, W * 0.55 * pulse3, _kV2,  0.28);
    orb(W * 0.0,  H * 1.0,  W * 0.65 * pulse1, _kMint,0.30);
    orb(W * 1.0,  H * 0.85, W * 0.55 * pulse2, _kSky, 0.25);
    orb(W * 0.85, H * 0.35, W * 0.35 * pulse3, _kAmber.withOpacity(0.6), 0.15);

    // ── 3. Mesh gradient overlay (noise-like feel) ─────────────────────────
    final meshPaint = Paint()
      ..shader = RadialGradient(
        colors: [_kV4.withOpacity(0.25), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, H * 0.3, W, H * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, H * 0.3, W, H * 0.4), meshPaint);

    // ── 4. Rotating ring system ────────────────────────────────────────────
    final ringAngle = t * 2 * pi * 0.15;
    canvas.save();
    canvas.translate(W * 0.5, H * 0.22);
    canvas.rotate(ringAngle);

    for (int i = 0; i < 3; i++) {
      final r = W * (0.35 + i * 0.12);
      final alpha = 0.18 - i * 0.04;
      canvas.drawCircle(Offset.zero, r, Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = SweepGradient(
          colors: [
            _kV1.withOpacity(alpha * 2), _kV2.withOpacity(alpha),
            _kV3.withOpacity(alpha * 1.5), Colors.transparent,
          ],
          stops: const [0.0, 0.33, 0.66, 1.0],
          startAngle: 0, endAngle: 2 * pi,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    }
    canvas.restore();

    // ── 5. Floating star / sparkle shapes ─────────────────────────────────
    final sparkle = Paint()..style = PaintingStyle.fill;
    final starPositions = [
      [0.12, 0.15, 4.0, _kAmber], [0.88, 0.20, 3.0, _kV2],
      [0.05, 0.50, 2.5, _kMint],  [0.95, 0.55, 3.5, _kSky],
      [0.20, 0.80, 3.0, _kV3],   [0.78, 0.78, 2.5, _kV1],
      [0.50, 0.10, 2.0, _kAmber],[0.65, 0.45, 3.0, _kMint],
      [0.35, 0.65, 2.0, _kV2],   [0.90, 0.42, 4.0, _kV3],
    ];
    for (final sp in starPositions) {
      final px = W * (sp[0] as double);
      final py = H * (sp[1] as double);
      final pr = sp[2] as double;
      final pc = (sp[3] as Color).withOpacity(
          0.55 + 0.35 * sin(t * 2 * pi + px));
      sparkle.color = pc;
      // 4-point star
      final path = Path();
      for (int j = 0; j < 8; j++) {
        final a = j * pi / 4;
        final r = j.isEven ? pr : pr * 0.4;
        final x = px + r * cos(a - pi / 8);
        final y = py + r * sin(a - pi / 8);
        j == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, sparkle);
    }

    // ── 6. Hexagonal grid pattern ──────────────────────────────────────────
    final hexPaint = Paint()
      ..color = _kV2.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const hexSize = 28.0;
    const hexH = hexSize * 1.732;
    for (double row = -1; row < H / hexH + 1; row++) {
      for (double col = -1; col < W / hexSize * 0.75 + 1; col++) {
        final cx = col * hexSize * 1.5;
        final cy = row * hexH + (col.toInt().isOdd ? hexH / 2 : 0);
        final hexPath = Path();
        for (int i = 0; i < 6; i++) {
          final a = i * pi / 3 + pi / 6;
          final x = cx + hexSize * cos(a);
          final y = cy + hexSize * sin(a);
          i == 0 ? hexPath.moveTo(x, y) : hexPath.lineTo(x, y);
        }
        hexPath.close();
        canvas.drawPath(hexPath, hexPaint);
      }
    }

    // ── 7. Animated layered sine waves ────────────────────────────────────
    final waveConfigs = [
      // [baseY_frac, amplitude, frequency, speed_mult, strokeW, color, opacity]
      [0.32, 28.0, 2.2, 1.0,  36.0, _kV2,  0.22],
      [0.38, 20.0, 3.0, 1.4,  18.0, _kV3,  0.18],
      [0.44, 14.0, 4.0, 0.8,  10.0, _kMint,0.14],
      [0.50, 32.0, 1.8, 1.8,  28.0, _kV1,  0.16],
      [0.56, 18.0, 2.8, 1.2,  12.0, _kSky, 0.12],
      [0.62, 10.0, 5.0, 2.0,   6.0, _kV2,  0.10],
    ];

    for (final wc in waveConfigs) {
      final baseY  = H * (wc[0] as double);
      final amp    = wc[1] as double;
      final freq   = wc[2] as double;
      final speed  = wc[3] as double;
      final sw     = wc[4] as double;
      final wColor = wc[5] as Color;
      final wOp    = wc[6] as double;
      final phase  = t * 2 * pi * speed;

      final wavePath = Path();
      wavePath.moveTo(0, baseY + amp * sin(phase));
      for (double x = 1; x <= W; x += 2) {
        final y = baseY + amp * sin(freq * pi * x / W + phase);
        wavePath.lineTo(x, y);
      }

      canvas.drawPath(wavePath, Paint()
        ..shader = LinearGradient(colors: [
          Colors.transparent,
          wColor.withOpacity(wOp),
          wColor.withOpacity(wOp * 1.3),
          wColor.withOpacity(wOp),
          Colors.transparent,
        ], stops: const [0.0, 0.20, 0.50, 0.80, 1.0])
            .createShader(Rect.fromLTWH(0, baseY - amp, W, amp * 2))
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
    }

    // ── 8. Particle dots grid ──────────────────────────────────────────────
    final pDot = Paint()..color = _kV2.withOpacity(0.15);
    for (double x = 16; x < W; x += 22)
      for (double y = 16; y < H; y += 22) {
        final brightness = 0.5 + 0.5 * sin(t * 2 * pi + x * 0.05 + y * 0.03);
        pDot.color = _kV2.withOpacity(0.06 + 0.10 * brightness);
        canvas.drawCircle(Offset(x, y), 1.0, pDot);
      }

    // ── 9. Corner accent arcs ──────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: Offset(W, 0), radius: W * 0.38),
      pi / 2, pi / 2, false,
      Paint()
        ..color = _kV3.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, H), radius: W * 0.45),
      -pi / 2, pi / 2, false,
      Paint()
        ..color = _kMint.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.t != t;
}

// ─── Google logo painter ──────────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = size.width * 0.42;
    canvas.drawCircle(Offset(cx, cy), size.width / 2,
        Paint()..color = const Color(0xFF1E1535));
    for (final d in [
      [pi * 0.55, pi * 1.15, const Color(0xFF4285F4)],
      [pi * -0.18, pi * 0.42, const Color(0xFFEA4335)],
      [pi * 0.24, pi * 0.38, const Color(0xFFFBBC05)],
      [pi * 0.62, pi * -0.18, const Color(0xFF34A853)],
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        d[0] as double, d[1] as double, false,
        Paint()..color = d[2] as Color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.25
          ..strokeCap = StrokeCap.butt,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(cx - 1, cy + r * 0.04 - size.width * 0.12,
          cx + r * 0.80, cy + r * 0.04 + size.width * 0.12),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawCircle(Offset(cx, cy), size.width / 2 - 0.5,
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
      debugShowCheckedModeBanner: false, home: LoginScreenHome());
}

class LoginScreenHome extends StatefulWidget {
  const LoginScreenHome({super.key});
  @override
  State<LoginScreenHome> createState() => _LoginScreenHomeState();
}

class _LoginScreenHomeState extends State<LoginScreenHome>
    with TickerProviderStateMixin {
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _hidePass  = true;
  bool _isLoading = false;

  late AnimationController _bgCtrl;   // continuous bg animation
  late AnimationController _inCtrl;   // entrance animation
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 8))..repeat();
    _inCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _fadeAnim  = CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutCubic));
    _userFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    _inCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _inCtrl.dispose();
    _userFocus.dispose(); _passFocus.dispose();
    _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_userCtrl.text.trim().isEmpty) { _err("Please enter your username."); return; }
    if (_passCtrl.text.trim().isEmpty) { _err("Please enter your password."); return; }
    setState(() => _isLoading = true);
    final user = await DatabaseHelper()
        .loginUser(_userCtrl.text.trim(), _passCtrl.text.trim());
    setState(() => _isLoading = false);
    if (user == null) {
      _err("Invalid username or password.");
    } else if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => Homepage(localUserId: user['id'])));
    }
  }

  Future<void> _googleLogin() async {
    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null && mounted) {
        developer.log('Google: ${user.email}', name: 'Login');
        final db  = DatabaseHelper();
        final all = await db.getAllUsers();
        final ex  = all.firstWhere((u) => u['email'] == user.email, orElse: () => {});
        final localId = ex.isNotEmpty ? ex['id'] as int
            : await db.insertUser(
            fullName: user.displayName ?? 'Google User',
            userName: user.email?.split('@')[0] ??
                'user_${DateTime.now().millisecondsSinceEpoch}',
            password: '', email: user.email, profilePic: user.photoURL);
        if (mounted) Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => Homepage(localUserId: localId)));
      }
    } catch (e) {
      if (mounted) _err('Google sign-in failed. Please try again.');
    }
  }

  void _err(String msg) {
    AwesomeDialog(context: context, dialogType: DialogType.error,
        title: 'Oops!', desc: msg,
        btnOkColor: _kV1, btnOkOnPress: () {}).show();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1040),
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) => Stack(children: [

          // ── Animated background ──
          CustomPaint(
              painter: _BgPainter(_bgCtrl.value),
              child: const SizedBox.expand()),

          // ── Frosted glass panel ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: screenH * 0.64,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(44),
                    topRight: Radius.circular(44)),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12), width: 1.5),
                boxShadow: [
                  BoxShadow(color: _kV1.withOpacity(0.18),
                      blurRadius: 50, offset: const Offset(0, -10)),
                ],
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenH),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          SizedBox(height: screenH * 0.08),

                          // ── App icon ──
                          Container(
                            width: 92, height: 92,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF7B6CF6), Color(0xFFA78BFA),
                                    Color(0xFFEC4899)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: _kV1.withOpacity(0.55),
                                    blurRadius: 30, offset: const Offset(0, 10)),
                                BoxShadow(color: _kV3.withOpacity(0.30),
                                    blurRadius: 18, offset: const Offset(6, 8)),
                              ],
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.20),
                                  width: 1.5),
                            ),
                            child: Stack(alignment: Alignment.center, children: [
                              const Icon(Icons.school_rounded,
                                  color: Colors.white, size: 40),
                              Positioned(bottom: 14, right: 14,
                                  child: Container(width: 14, height: 14,
                                      decoration: BoxDecoration(
                                          color: _kMint, shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2.5),
                                          boxShadow: [BoxShadow(
                                              color: _kMint.withOpacity(0.70),
                                              blurRadius: 8)]))),
                            ]),
                          ),

                          const SizedBox(height: 18),

                          // ── App name ──
                          // ── App name ──
                          Text(
                            "CampusAid",
                            style: TextStyle(
                              fontSize: 38,
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
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 5, height: 5,
                                    decoration: BoxDecoration(
                                        color: _kMint, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text("Connect · Learn · Grow Together",
                                    style: TextStyle(fontSize: 12.5,
                                        color: Colors.white.withOpacity(0.55),
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.3)),
                                const SizedBox(width: 8),
                                Container(width: 5, height: 5,
                                    decoration: BoxDecoration(
                                        color: _kV3, shape: BoxShape.circle)),
                              ]),

                          SizedBox(height: screenH * 0.055),

                          // ── Glass form card ──
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 30, offset: const Offset(0, 12)),
                                BoxShadow(color: _kV1.withOpacity(0.20),
                                    blurRadius: 20, offset: const Offset(0, 6)),
                              ],
                            ),
                            padding: const EdgeInsets.all(50),
                            child: Column(children: [

                              // Card header
                              Row(children: [
                                Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                            colors: [_kV1, _kV3],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.lock_open_rounded,
                                        color: Colors.white, size: 17)),
                                const SizedBox(width: 10),
                                const Text("Sign In", style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                                const Spacer(),
                                Text("Welcome back!",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white
                                    )
                                ),
                              ]),

                              const SizedBox(height: 22),

                              _field(ctrl: _userCtrl, focus: _userFocus,
                                  label: "Username",
                                  hint: "Enter your username",
                                  icon: Icons.alternate_email_rounded),
                              const SizedBox(height: 14),
                              _field(ctrl: _passCtrl, focus: _passFocus,
                                  label: "Password",
                                  hint: "Enter your password",
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _hidePass,
                                  suffix: GestureDetector(
                                    onTap: () => setState(
                                            () => _hidePass = !_hidePass),
                                    child: Padding(
                                        padding: const EdgeInsets.only(right: 14),
                                        child: Icon(
                                            _hidePass
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.white.withOpacity(0.40),
                                            size: 20)),
                                  )),

                              const SizedBox(height: 24),

                              // Sign In button
                              SizedBox(width: double.infinity, height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: _grad,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(color: _kV1.withOpacity(0.55),
                                          blurRadius: 24,
                                          offset: const Offset(0, 9)),
                                      BoxShadow(color: _kV3.withOpacity(0.28),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(18))),
                                    child: _isLoading
                                        ? const SizedBox(width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                        : const Text("Sign In",
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: 0.4)),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Divider
                              Row(children: [
                                Expanded(child: Divider(
                                    color: Colors.white.withOpacity(0.15))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Text("OR",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.35),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5)),
                                ),
                                Expanded(child: Divider(
                                    color: Colors.white.withOpacity(0.15))),
                              ]),

                              const SizedBox(height: 18),

                              // Google
                              SizedBox(width: double.infinity, height: 50,
                                child: OutlinedButton(
                                  onPressed: _googleLogin,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor:
                                    Colors.white.withOpacity(0.06),
                                    side: BorderSide(
                                        color: Colors.white.withOpacity(0.20),
                                        width: 1.3),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(16)),
                                  ),
                                  child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        CustomPaint(
                                            painter: _GoogleLogoPainter(),
                                            size: const Size(22, 22)),
                                        const SizedBox(width: 10),
                                        Text("Continue with Google",
                                            style: TextStyle(
                                                color: Colors.white.withOpacity(0.80),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                      ]),
                                ),
                              ),
                            ]),
                          ),

                          SizedBox(height: screenH * 0.055),

                          // ── Sign up link ──
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                  width: 1)),
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Don't have an account?  ",
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.50),
                                          fontSize: 13.5)),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => SignUpScreen())),
                                    child: const Text("Sign up",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13.5)),
                                    ),
                                ]),
                          ),
                          const SizedBox(height: 8),
                          Text("CampusAid © 2025",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 11)),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final focused = focus.hasFocus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: focused ? _kV2 : Colors.white.withOpacity(0.50),
          fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: focused
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: focused ? _kV2.withOpacity(0.70) : Colors.white.withOpacity(0.12),
              width: focused ? 1.8 : 1.1),
          boxShadow: focused ? [
            BoxShadow(color: _kV1.withOpacity(0.25),
                blurRadius: 14, offset: const Offset(0, 4)),
          ] : [],
        ),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(left: 14),
              child: Icon(icon,
                  color: focused ? _kV2 : Colors.white.withOpacity(0.35),
                  size: 20)),
          Expanded(child: TextField(
            controller: ctrl, focusNode: focus, obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28), fontSize: 13.5),
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