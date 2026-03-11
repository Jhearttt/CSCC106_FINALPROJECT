import 'dart:developer' as developer;
import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/homePage.dart';
import 'package:final_project/frontend/signUpScreen.dart';
import 'package:final_project/GoogleServices/auth_service.dart';
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg         = Color(0xFF0D0F14);   // Near-black canvas
const _bgCard     = Color(0xFF161B24);   // Slightly lifted card
const _violet     = Color(0xFF7C3AED);   // Primary violet
const _violetLit  = Color(0xFF9F67FF);   // Lighter violet
const _cyan       = Color(0xFF06B6D4);   // Accent cyan
const _cyanLit    = Color(0xFF67E8F9);   // Light cyan
const _amber      = Color(0xFFFBBF24);   // Warm highlight (tags, badge)
const _surface    = Color(0xFF1E2433);   // Input surface
const _surfaceLit = Color(0xFF252D3D);   // Focused input
const _border     = Color(0xFF2E3A4E);   // Resting border
const _borderFoc  = Color(0xFF7C3AED);   // Focused border
const _textHigh   = Color(0xFFF0F4FF);   // Headings
const _textMid    = Color(0xFF8B96A8);   // Body / secondary
const _textDim    = Color(0xFF4A5568);   // Hints / placeholders

// ─── Gradient helpers ─────────────────────────────────────────────────────────
const _gradVioletCyan = LinearGradient(
  colors: [_violet, _cyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _gradVioletDeep = LinearGradient(
  colors: [Color(0xFF5B21B6), _violet],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Background Painter — floating orbs + grid ────────────────────────────────
class _BgPainter extends CustomPainter {
  final double animValue; // 0..1 loop for subtle pulse
  const _BgPainter({this.animValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark base is handled by Scaffold backgroundColor

    // Grid lines — very subtle
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.8;
    const gridSpacing = 36.0;
    for (double x = 0; x < size.width; x += gridSpacing)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += gridSpacing)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    // Orb 1 — violet, top-left
    final orb1Radius = size.width * 0.52 + sin(animValue * 2 * pi) * 12;
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.12),
      orb1Radius,
      Paint()
        ..shader = RadialGradient(
          colors: [_violet.withOpacity(0.22), Colors.transparent],
        ).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.10, size.height * 0.12),
            radius: orb1Radius)),
    );

    // Orb 2 — cyan, bottom-right
    final orb2Radius = size.width * 0.45 + cos(animValue * 2 * pi) * 10;
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.78),
      orb2Radius,
      Paint()
        ..shader = RadialGradient(
          colors: [_cyan.withOpacity(0.18), Colors.transparent],
        ).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.88, size.height * 0.78),
            radius: orb2Radius)),
    );

    // Orb 3 — small violet, mid-right
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.35),
      size.width * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [_violet.withOpacity(0.12), Colors.transparent],
        ).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.92, size.height * 0.35),
            radius: size.width * 0.22)),
    );

    // Horizontal glow line — center
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          _violetLit.withOpacity(0.18),
          _cyan.withOpacity(0.14),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.40, size.width, 1))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.40),
      Offset(size.width, size.height * 0.40),
      glowPaint,
    );

    // Dot ring — top right corner decoration
    final dotPaint = Paint()
      ..color = _violetLit.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        final dist = sqrt(pow(i - 2, 2) + pow(j - 2, 2));
        if (dist < 2.6) {
          canvas.drawCircle(
            Offset(size.width - 28 + i * 12.0, 28 + j * 12.0),
            dist < 1.5 ? 2.2 : 1.4,
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.animValue != animValue;
}

// ─── Neon divider painter ─────────────────────────────────────────────────────
class _GradLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = _gradVioletCyan.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Google icon painter ──────────────────────────────────────────────────────
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1E2433));
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    for (final pair in [
      [pi * 0.62, pi * 1.12, const Color(0xFF4285F4)],
      [pi * -0.17, pi * 0.40, const Color(0xFFEA4335)],
      [pi * 0.23, pi * 0.40, const Color(0xFFFBBC05)],
      [pi * 0.62, -pi * 0.18, const Color(0xFF34A853)],
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.75),
        pair[0] as double, pair[1] as double, false,
        Paint()
          ..color = pair[2] as Color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.26
          ..strokeCap = StrokeCap.butt,
      );
    }
    final barY = center.dy + radius * 0.04;
    canvas.drawRect(
      Rect.fromLTRB(center.dx - radius * 0.02, barY - size.width * 0.13,
          center.dx + radius * 0.75, barY + size.width * 0.13),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.restore();
    canvas.drawCircle(center, radius - 0.5,
        Paint()
          ..color = _border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: LoginScreenHome());
}

class LoginScreenHome extends StatefulWidget {
  const LoginScreenHome({super.key});
  @override
  State<LoginScreenHome> createState() => _LoginScreenHomeState();
}

class _LoginScreenHomeState extends State<LoginScreenHome>
    with TickerProviderStateMixin {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  bool _isLoading = false;

  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  late AnimationController _bgCtrl;   // slow orb pulse
  late AnimationController _inCtrl;   // page entry
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 6))..repeat();

    _inCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutCubic));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _inCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _logoSlide = Tween<Offset>(
        begin: const Offset(-0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)));

    _userFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    _inCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _validateInputs() async {
    if (usernameController.text.isEmpty) { _showError("Username is empty."); return; }
    if (passwordController.text.isEmpty) { _showError("Password is empty."); return; }
    setState(() => _isLoading = true);
    final user = await DatabaseHelper()
        .loginUser(usernameController.text, passwordController.text);
    setState(() => _isLoading = false);
    if (user == null) {
      _showError("Invalid username or password.");
    } else {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => Homepage(localUserId: user['id'])));
    }
  }

  void _showError(String msg) {
    AwesomeDialog(context: context, dialogType: DialogType.error,
        title: 'Error', desc: msg, btnOkOnPress: () {},
        btnOkColor: _violet).show();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) => Stack(children: [
          // Animated background
          CustomPaint(
            painter: _BgPainter(animValue: _bgCtrl.value),
            child: const SizedBox.expand(),
          ),

          SafeArea(
            child: Column(children: [
              // ── Top section: logo + tagline ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: FadeTransition(
                  opacity: _logoFade,
                  child: SlideTransition(
                    position: _logoSlide,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo mark — gradient ring + icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_violet, _cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: _violet.withOpacity(0.45),
                                  blurRadius: 20, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.people_alt_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Wordmark
                          ShaderMask(
                            shaderCallback: (bounds) => _gradVioletCyan
                                .createShader(bounds),
                            child: const Text("PeerAid",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const Text("Campus peer support",
                              style: TextStyle(color: _textDim, fontSize: 11,
                                  fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                        ]),

                        const Spacer(),

                        // "New?" pill
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SignUpScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _border, width: 1.2),
                              color: _surface,
                            ),
                            child: Row(children: const [
                              Text("Sign up",
                                  style: TextStyle(color: _textMid, fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: _textDim, size: 10),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Hero headline ─────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _amber.withOpacity(0.35), width: 1),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: _amber, shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            const Text("Students helping students",
                                style: TextStyle(color: _amber, fontSize: 11,
                                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        // Big display headline
                        const Text("Learn.\nConnect.\nThrive.",
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: _textHigh,
                            height: 1.05,
                            letterSpacing: -2.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Gradient underline on last word area
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: CustomPaint(
                            painter: _GradLinePainter(),
                            size: const Size(80, 3),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text("Your campus community for\nacademic help & collaboration.",
                            style: TextStyle(color: _textMid, fontSize: 13.5,
                                height: 1.6, letterSpacing: 0.1)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Glassmorphism form card ───────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _bgCard,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      border: const Border(
                        top: BorderSide(color: _border, width: 1),
                        left: BorderSide(color: _border, width: 1),
                        right: BorderSide(color: _border, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(color: _violet.withOpacity(0.10),
                            blurRadius: 40, offset: const Offset(0, -8)),
                        BoxShadow(color: Colors.black.withOpacity(0.40),
                            blurRadius: 30, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Drag handle
                      Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2)),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                        child: Column(children: [
                          // Card header
                          Row(children: [
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Sign in",
                                      style: TextStyle(fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: _textHigh, letterSpacing: -0.5)),
                                  SizedBox(height: 3),
                                  Text("Welcome back 👋",
                                      style: TextStyle(color: _textMid, fontSize: 13)),
                                ])),
                            // Violet glow dot
                            Container(width: 40, height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                      colors: [_violet, _cyan],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  boxShadow: [BoxShadow(
                                      color: _violet.withOpacity(0.50),
                                      blurRadius: 16, offset: const Offset(0, 4))],
                                ),
                                child: const Icon(Icons.lock_open_rounded,
                                    color: Colors.white, size: 18)),
                          ]),

                          const SizedBox(height: 22),

                          _buildField(
                            controller: usernameController,
                            focusNode: _userFocus,
                            label: "Username",
                            hint: "Enter your username",
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: passwordController,
                            focusNode: _passFocus,
                            label: "Password",
                            hint: "Enter your password",
                            icon: Icons.lock_outline_rounded,
                            obscure: hidePassword,
                            suffix: GestureDetector(
                              onTap: () =>
                                  setState(() => hidePassword = !hidePassword),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Icon(
                                    hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textDim, size: 19),
                              ),
                            ),
                          ),

                          // Forgot
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ShaderMask(
                                shaderCallback: (b) =>
                                    _gradVioletCyan.createShader(b),
                                child: const Text("Forgot password?",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Gradient CTA button ──
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _gradVioletCyan,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: _violet.withOpacity(0.45),
                                      blurRadius: 22, offset: const Offset(0, 8)),
                                  BoxShadow(color: _cyan.withOpacity(0.20),
                                      blurRadius: 12, offset: const Offset(6, 4)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _validateInputs,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text("Sign In",
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15.5, letterSpacing: 0.2)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded,
                                        color: Colors.white, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // OR divider
                          Row(children: [
                            Expanded(child: Divider(color: _border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text("or",
                                  style: TextStyle(color: _textDim, fontSize: 12)),
                            ),
                            Expanded(child: Divider(color: _border)),
                          ]),

                          const SizedBox(height: 16),

                          // Google
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () async {
                                try {
                                  final user = await AuthService().signInWithGoogle();
                                  if (user != null) {
                                    developer.log('Google: ${user.email}', name: 'Login');
                                    final db = DatabaseHelper();
                                    final all = await db.getAllUsers();
                                    final ex = all.firstWhere(
                                            (u) => u['email'] == user.email,
                                        orElse: () => {});
                                    int localId;
                                    if (ex.isNotEmpty) {
                                      localId = ex['id'];
                                    } else {
                                      localId = await db.insertUser(
                                        fullName: user.displayName ?? 'Google User',
                                        userName: user.email?.split('@')[0] ??
                                            'user_${DateTime.now().millisecondsSinceEpoch}',
                                        password: '', email: user.email,
                                        profilePic: user.photoURL,
                                      );
                                    }
                                    if (context.mounted) {
                                      await Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(builder: (_) =>
                                              Homepage(localUserId: localId)));
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'),
                                            backgroundColor: Colors.red));
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _surface,
                                side: BorderSide(color: _border, width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomPaint(
                                      painter: _GoogleIconPainter(),
                                      size: const Size(20, 20)),
                                  const SizedBox(width: 10),
                                  const Text("Continue with Google",
                                      style: TextStyle(color: _textMid,
                                          fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Sign up link
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => SignUpScreen())),
                              child: RichText(
                                text: TextSpan(
                                  text: "Don't have an account?  ",
                                  style: const TextStyle(
                                      color: _textMid, fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: "Sign up",
                                      style: TextStyle(
                                        foreground: Paint()
                                          ..shader = _gradVioletCyan
                                              .createShader(
                                            const Rect.fromLTWH(0, 0, 50, 20),
                                          ),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final isFocused = focusNode.hasFocus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: TextStyle(
          color: isFocused ? _violetLit : _textMid,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isFocused ? _surfaceLit : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused ? _borderFoc : _border,
            width: isFocused ? 1.6 : 1.1,
          ),
          boxShadow: isFocused
              ? [BoxShadow(color: _violet.withOpacity(0.18),
              blurRadius: 14, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon,
                color: isFocused ? _violetLit : _textDim, size: 19),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              style: const TextStyle(
                  color: _textHigh, fontSize: 14.5, height: 1.4),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                const TextStyle(color: _textDim, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 12),
              ),
            ),
          ),
          if (suffix != null) suffix,
        ]),
      ),
    ]);
  }
}