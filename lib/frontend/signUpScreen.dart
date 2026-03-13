import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:flutter/material.dart';

// ─── Brand Colors (matches PeerAid loginScreen) ───────────────────────────────
const _amber     = Color(0xFFFF8C42);
const _amberDeep = Color(0xFFE65100);
const _teal      = Color(0xFF00695C);
const _tealLight = Color(0xFF4DB6AC);
const _cream     = Color(0xFFFFF8F0);
const _surface   = Color(0xFFFFFFFF);
const _inkDark   = Color(0xFF1A1A2E);
const _inkMid    = Color(0xFF4A4A6A);
const _inkLight  = Color(0xFF9E9EBE);

// ─── Background Painter ───────────────────────────────────────────────────────
class _SignUpBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-left warm blob
    final p1 = Paint()..color = _amber.withOpacity(0.15);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..cubicTo(size.width * 0.30, 0, size.width * 0.40, size.height * 0.08,
            size.width * 0.18, size.height * 0.16)
        ..lineTo(0, size.height * 0.20)
        ..close(),
      p1,
    );

    // Smaller inner top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.22, 0)
        ..lineTo(0, size.height * 0.09)
        ..close(),
      Paint()..color = _amber.withOpacity(0.09),
    );

    // Top-right teal arc
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width, 0), radius: size.width * 0.55),
      pi / 2,
      pi / 2,
      true,
      Paint()..color = _teal.withOpacity(0.10),
    );

    // Bottom-right amber blob
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height * 0.78)
        ..cubicTo(size.width * 0.85, size.height * 0.84,
            size.width * 0.72, size.height * 0.92, size.width * 0.68, size.height)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = _amber.withOpacity(0.13),
    );

    // Bottom-left teal blob
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.88)
        ..cubicTo(size.width * 0.12, size.height * 0.84,
            size.width * 0.22, size.height * 0.92, size.width * 0.18, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = _teal.withOpacity(0.10),
    );

    // Dot grid — top right area
    final dotPaint = Paint()..color = _tealLight.withOpacity(0.20);
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        canvas.drawCircle(
          Offset(size.width - 24.0 - col * 16, 24.0 + row * 16),
          2.0,
          dotPaint,
        );
      }
    }

    // Dot grid — left mid
    final dotPaint2 = Paint()..color = _amber.withOpacity(0.14);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(18.0 + col * 16, size.height * 0.42 + row * 16),
          1.8,
          dotPaint2,
        );
      }
    }

    // Subtle diagonal stripe
    final stripePaint = Paint()
      ..color = _amber.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawLine(
      Offset(size.width * 0.0, size.height * 0.30),
      Offset(size.width * 0.55, size.height * 0.0),
      stripePaint,
    );

    // Large soft circle (center-ish)
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.48),
      size.width * 0.30,
      Paint()..color = _teal.withOpacity(0.04),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Step Indicator Painter ───────────────────────────────────────────────────
// Draws a small decorative "community ring" in the header
class _CommunityRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Outer ring
    canvas.drawCircle(
        Offset(cx, cy),
        size.width / 2 - 1,
        Paint()
          ..color = _amber.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // Inner filled circle
    canvas.drawCircle(
        Offset(cx, cy), size.width / 2 - 9, Paint()..color = _amber.withOpacity(0.10));
    // Small accent dots around the ring
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i;
      final x = cx + (size.width / 2 - 1) * cos(angle);
      final y = cy + (size.width / 2 - 1) * sin(angle);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = _amber.withOpacity(0.55));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Sign Up Screen ───────────────────────────────────────────────────────────
class SignUpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false, home: SignUpScreenHome());
  }
}

class SignUpScreenHome extends StatefulWidget {
  @override
  State<SignUpScreenHome> createState() => _SignUpScreenHomeState();
}

class _SignUpScreenHomeState extends State<SignUpScreenHome>
    with SingleTickerProviderStateMixin {
  bool hideNewPassword = true;
  bool hideConfirmPassword = true;
  bool _isLoading = false;

  final fullNameController        = TextEditingController();
  final userNameController        = TextEditingController();
  final newPasswordController     = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Focus nodes for animated fields
  final _nameFocus    = FocusNode();
  final _userFocus    = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _animCtrl, curve: Curves.easeOutCubic));

    for (final fn in [_nameFocus, _userFocus, _passFocus, _confirmFocus]) {
      fn.addListener(() => setState(() {}));
    }
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final fn in [_nameFocus, _userFocus, _passFocus, _confirmFocus]) {
      fn.dispose();
    }
    super.dispose();
  }

  void inputValidations() async {
    if (fullNameController.text.isEmpty) {
      _showError("Full name is required");
      return;
    }
    if (userNameController.text.isEmpty) {
      _showError("Username is required");
      return;
    }
    if (newPasswordController.text.isEmpty) {
      _showError("Password is required");
      return;
    }
    if (confirmPasswordController.text.isEmpty) {
      _showError("Please confirm your password");
      return;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);
    final result = await DatabaseHelper().insertUser(
      fullName: fullNameController.text,
      userName: userNameController.text,
      password: newPasswordController.text,
    );
    setState(() => _isLoading = false);

    if (result > 0) {
      AwesomeDialog(
        width: 300,
        context: context,
        title: 'You\'re in! 🎉',
        desc: 'Account created successfully. Welcome to PeerAid!',
        dialogType: DialogType.success,
        btnOkColor: _amber,
        btnOkOnPress: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen())),
      ).show();
    } else {
      _showError("Username may already be taken. Try another.");
    }
  }

  void _showError(String message) {
    AwesomeDialog(
      width: 300,
      context: context,
      title: 'Oops!',
      desc: message,
      dialogType: DialogType.error,
      btnOkColor: _amber,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Stack(children: [
        CustomPaint(painter: _SignUpBlobPainter(), child: const SizedBox.expand()),
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back button ──
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _amber.withOpacity(0.35), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: _amber.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: _amber, size: 17),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Header ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Join\n",
                                      style: TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: _inkDark,
                                        height: 1.1,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "Peer",
                                      style: TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: _inkDark,
                                        height: 1.1,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "Aid",
                                      style: TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: _amber,
                                        height: 1.1,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _teal.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "✨  Your campus community awaits",
                                    style: TextStyle(
                                      color: _teal,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        // Decorative ring
                        CustomPaint(
                          painter: _CommunityRingPainter(),
                          size: const Size(64, 64),
                          child: const SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(
                              child: Text("🤝",
                                  style: TextStyle(fontSize: 26)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Amber accent bar
                    Container(
                      height: 3,
                      width: 52,
                      margin: const EdgeInsets.only(top: 14, bottom: 28),
                      decoration: BoxDecoration(
                        color: _amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),

                    // ── Form card ──
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: const Color(0xFFF0E8DC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: _amber.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 12)),
                          const BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(children: [
                        // Section label
                        Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text("Personal Info",
                              style: TextStyle(
                                  color: _inkDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2)),
                        ]),
                        const SizedBox(height: 16),
                        _buildField(
                          controller: fullNameController,
                          focusNode: _nameFocus,
                          hint: "e.g. Maria Santos",
                          label: "Full Name",
                          icon: Icons.badge_rounded,
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: userNameController,
                          focusNode: _userFocus,
                          hint: "e.g. maria_s",
                          label: "Username",
                          icon: Icons.alternate_email_rounded,
                        ),

                        const SizedBox(height: 22),

                        // Divider with label
                        Row(children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _teal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text("Security",
                              style: TextStyle(
                                  color: _inkDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2)),
                        ]),
                        const SizedBox(height: 16),

                        _buildField(
                          controller: newPasswordController,
                          focusNode: _passFocus,
                          hint: "Create a strong password",
                          label: "Password",
                          icon: Icons.lock_rounded,
                          obscure: hideNewPassword,
                          suffix: GestureDetector(
                            onTap: () => setState(
                                    () => hideNewPassword = !hideNewPassword),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                hideNewPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _inkLight,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: confirmPasswordController,
                          focusNode: _confirmFocus,
                          hint: "Repeat your password",
                          label: "Confirm Password",
                          icon: Icons.lock_outline_rounded,
                          obscure: hideConfirmPassword,
                          suffix: GestureDetector(
                            onTap: () => setState(() =>
                            hideConfirmPassword = !hideConfirmPassword),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                hideConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: _inkLight,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    // ── Create account button ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_amber, _amberDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: _amber.withOpacity(0.42),
                                blurRadius: 22,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : inputValidations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.rocket_launch_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 10),
                              Text("Create My Account",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                      letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Already have account ──
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => LoginScreen())),
                        child: RichText(
                          text: const TextSpan(
                            text: "Already have an account?  ",
                            style:
                            TextStyle(color: _inkMid, fontSize: 13.5),
                            children: [
                              TextSpan(
                                text: "Sign in",
                                style: TextStyle(
                                  color: _amber,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        "PeerAid © 2025 · Campus Peer Support",
                        style: TextStyle(
                          color: _inkLight.withOpacity(0.7),
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    final isFocused = focusNode.hasFocus;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        label,
        style: TextStyle(
          color: isFocused ? _amber : _inkMid,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : const Color(0xFFF7F5F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFocused ? _amber : const Color(0xFFEAE0D8),
            width: isFocused ? 1.8 : 1.2,
          ),
          boxShadow: isFocused
              ? [
            BoxShadow(
                color: _amber.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]
              : [],
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child:
            Icon(icon, color: isFocused ? _amber : _inkLight, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              style: const TextStyle(
                  color: _inkDark, fontSize: 14.5, height: 1.4),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                const TextStyle(color: _inkLight, fontSize: 13.5),
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