import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/frontend/loginScreen.dart';
import 'package:flutter/material.dart';

// ─── Palette (matches loginScreen) ───────────────────────────────────────────
const _bg         = Color(0xFF0D0F14);
const _bgCard     = Color(0xFF161B24);
const _violet     = Color(0xFF7C3AED);
const _violetLit  = Color(0xFF9F67FF);
const _cyan       = Color(0xFF06B6D4);
const _cyanLit    = Color(0xFF67E8F9);
const _amber      = Color(0xFFFBBF24);
const _surface    = Color(0xFF1E2433);
const _surfaceLit = Color(0xFF252D3D);
const _border     = Color(0xFF2E3A4E);
const _borderFoc  = Color(0xFF7C3AED);
const _textHigh   = Color(0xFFF0F4FF);
const _textMid    = Color(0xFF8B96A8);
const _textDim    = Color(0xFF4A5568);

const _gradVioletCyan = LinearGradient(
  colors: [_violet, _cyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Background Painter ───────────────────────────────────────────────────────
class _SignUpBgPainter extends CustomPainter {
  final double animValue;
  const _SignUpBgPainter({this.animValue = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.8;
    const sp = 36.0;
    for (double x = 0; x < size.width; x += sp)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += sp)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    // Violet orb — top center-right
    final r1 = size.width * 0.48 + sin(animValue * 2 * pi) * 10;
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.08),
      r1,
      Paint()..shader = RadialGradient(
          colors: [_violet.withOpacity(0.20), Colors.transparent])
          .createShader(Rect.fromCircle(
          center: Offset(size.width * 0.75, size.height * 0.08),
          radius: r1)),
    );

    // Cyan orb — bottom left
    final r2 = size.width * 0.40 + cos(animValue * 2 * pi) * 8;
    canvas.drawCircle(
      Offset(size.width * 0.10, size.height * 0.85),
      r2,
      Paint()..shader = RadialGradient(
          colors: [_cyan.withOpacity(0.16), Colors.transparent])
          .createShader(Rect.fromCircle(
          center: Offset(size.width * 0.10, size.height * 0.85),
          radius: r2)),
    );

    // Dot cluster — bottom right
    final dotPaint = Paint()
      ..color = _cyan.withOpacity(0.16)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        final dist = sqrt(pow(i - 2, 2) + pow(j - 2, 2));
        if (dist < 2.6) {
          canvas.drawCircle(
            Offset(size.width - 28 + i * 12.0, size.height - 60 + j * 12.0),
            dist < 1.5 ? 2.2 : 1.3,
            dotPaint,
          );
        }
      }
    }

    // Diagonal accent line
    canvas.drawLine(
      Offset(0, size.height * 0.46),
      Offset(size.width * 0.30, size.height * 0.30),
      Paint()
        ..color = _violetLit.withOpacity(0.06)
        ..strokeWidth = 40
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SignUpBgPainter old) =>
      old.animValue != animValue;
}

class _GradLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..shader = _gradVioletCyan
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Sign Up Screen ───────────────────────────────────────────────────────────
class SignUpScreen extends StatelessWidget {
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
  bool hideNewPassword     = true;
  bool hideConfirmPassword = true;
  bool _isLoading          = false;

  final fullNameController        = TextEditingController();
  final userNameController        = TextEditingController();
  final newPasswordController     = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final _nameFocus    = FocusNode();
  final _userFocus    = FocusNode();
  final _passFocus    = FocusNode();
  final _confirmFocus = FocusNode();

  late AnimationController _bgCtrl;
  late AnimationController _inCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 6))..repeat();
    _inCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 860));
    _fadeAnim = CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutCubic));
    _logoFade = CurvedAnimation(parent: _inCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));

    for (final fn in [_nameFocus, _userFocus, _passFocus, _confirmFocus]) {
      fn.addListener(() => setState(() {}));
    }
    _inCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _inCtrl.dispose();
    for (final fn in [_nameFocus, _userFocus, _passFocus, _confirmFocus]) {
      fn.dispose();
    }
    super.dispose();
  }

  void _inputValidations() async {
    if (fullNameController.text.isEmpty)        { _showError("Full name is required"); return; }
    if (userNameController.text.isEmpty)        { _showError("Username is required"); return; }
    if (newPasswordController.text.isEmpty)     { _showError("Password is required"); return; }
    if (confirmPasswordController.text.isEmpty) { _showError("Please confirm your password"); return; }
    if (newPasswordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match"); return;
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
        width: 300, context: context,
        title: 'Welcome to PeerAid 🎉',
        desc: 'Your account has been created. Let\'s go!',
        dialogType: DialogType.success,
        btnOkColor: _violet,
        btnOkOnPress: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen())),
      ).show();
    } else {
      _showError("Username may already be taken.");
    }
  }

  void _showError(String msg) {
    AwesomeDialog(width: 300, context: context, title: 'Oops!', desc: msg,
        dialogType: DialogType.error, btnOkColor: _violet,
        btnOkOnPress: () {}).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) => Stack(children: [
          CustomPaint(
            painter: _SignUpBgPainter(animValue: _bgCtrl.value),
            child: const SizedBox.expand(),
          ),

          SafeArea(
            child: Column(children: [
              // ── Top bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                child: FadeTransition(
                  opacity: _logoFade,
                  child: Row(children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border, width: 1.2),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: _textMid, size: 15),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Wordmark
                    ShaderMask(
                      shaderCallback: (b) =>
                          _gradVioletCyan.createShader(b),
                      child: const Text("PeerAid",
                          style: TextStyle(fontSize: 20,
                              fontWeight: FontWeight.w900, color: Colors.white,
                              letterSpacing: -0.5)),
                    ),
                    const Spacer(),
                    // Step indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border, width: 1)),
                      child: const Text("Step 1 of 1",
                          style: TextStyle(color: _textDim, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),

              // ── Hero text ────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amber badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: _amber.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _amber.withOpacity(0.30), width: 1)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    color: _amber, shape: BoxShape.circle)),
                            const SizedBox(width: 7),
                            const Text("Free to join",
                                style: TextStyle(color: _amber, fontSize: 11,
                                    fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        const Text("Join the\ncommunity.",
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: _textHigh,
                            height: 1.05,
                            letterSpacing: -2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: CustomPaint(
                              painter: _GradLinePainter(),
                              size: const Size(64, 3)),
                        ),
                        const SizedBox(height: 12),
                        const Text("Create your account and start\ngetting & giving help today.",
                            style: TextStyle(color: _textMid, fontSize: 13,
                                height: 1.6, letterSpacing: 0.1)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Form card ────────────────────────────────────────────
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
                          topRight: Radius.circular(32)),
                      border: const Border(
                        top: BorderSide(color: _border, width: 1),
                        left: BorderSide(color: _border, width: 1),
                        right: BorderSide(color: _border, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(color: _cyan.withOpacity(0.08),
                            blurRadius: 40, offset: const Offset(0, -8)),
                        BoxShadow(color: Colors.black.withOpacity(0.40),
                            blurRadius: 30, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 36, height: 4,
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(color: _border,
                              borderRadius: BorderRadius.circular(2))),

                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
                        child: Column(children: [
                          // Card header
                          Row(children: [
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text("Create account",
                                      style: TextStyle(fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: _textHigh, letterSpacing: -0.4)),
                                  SizedBox(height: 3),
                                  Text("Fill in your details below",
                                      style: TextStyle(color: _textMid, fontSize: 12.5)),
                                ])),
                            Container(width: 40, height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                      colors: [_cyan, _violet],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  boxShadow: [BoxShadow(
                                      color: _cyan.withOpacity(0.45),
                                      blurRadius: 16, offset: const Offset(0, 4))],
                                ),
                                child: const Icon(Icons.person_add_rounded,
                                    color: Colors.white, size: 18)),
                          ]),

                          const SizedBox(height: 20),

                          // Section — Identity
                          _sectionTag("Identity"),
                          const SizedBox(height: 12),
                          _buildField(controller: fullNameController,
                              focusNode: _nameFocus,
                              label: "Full Name", hint: "e.g. Maria Santos",
                              icon: Icons.badge_outlined),
                          const SizedBox(height: 12),
                          _buildField(controller: userNameController,
                              focusNode: _userFocus,
                              label: "Username", hint: "e.g. maria_s",
                              icon: Icons.alternate_email_rounded),

                          const SizedBox(height: 18),

                          // Gradient divider
                          Row(children: [
                            Expanded(child: Divider(color: _border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle, color: _surface,
                                    border: Border.all(color: _border, width: 1)),
                                child: const Icon(Icons.lock_outline_rounded,
                                    color: _textDim, size: 13),
                              ),
                            ),
                            Expanded(child: Divider(color: _border)),
                          ]),

                          const SizedBox(height: 16),

                          // Section — Security
                          _sectionTag("Security"),
                          const SizedBox(height: 12),
                          _buildField(controller: newPasswordController,
                              focusNode: _passFocus,
                              label: "Password", hint: "Create a strong password",
                              icon: Icons.lock_outline_rounded,
                              obscure: hideNewPassword,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                        () => hideNewPassword = !hideNewPassword),
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Icon(hideNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                        color: _textDim, size: 19)),
                              )),
                          const SizedBox(height: 12),
                          _buildField(controller: confirmPasswordController,
                              focusNode: _confirmFocus,
                              label: "Confirm Password", hint: "Repeat your password",
                              icon: Icons.lock_person_outlined,
                              obscure: hideConfirmPassword,
                              suffix: GestureDetector(
                                onTap: () => setState(
                                        () => hideConfirmPassword = !hideConfirmPassword),
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 14),
                                    child: Icon(hideConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                        color: _textDim, size: 19)),
                              )),

                          const SizedBox(height: 22),

                          // ── Create account button ──
                          SizedBox(width: double.infinity, height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: _gradVioletCyan,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: _violet.withOpacity(0.42),
                                      blurRadius: 22, offset: const Offset(0, 8)),
                                  BoxShadow(color: _cyan.withOpacity(0.18),
                                      blurRadius: 12, offset: const Offset(6, 4)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _inputValidations,
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
                                    Icon(Icons.rocket_launch_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 10),
                                    Text("Create My Account",
                                        style: TextStyle(color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15, letterSpacing: 0.2)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Center(child: GestureDetector(
                            onTap: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => LoginScreen())),
                            child: RichText(
                              text: TextSpan(
                                text: "Already have an account?  ",
                                style: const TextStyle(color: _textMid, fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: "Sign in",
                                    style: TextStyle(
                                      foreground: Paint()
                                        ..shader = _gradVioletCyan.createShader(
                                            const Rect.fromLTWH(0, 0, 50, 20)),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
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

  Widget _sectionTag(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _violet.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _violet.withOpacity(0.28), width: 1)),
        child: Text(label,
            style: const TextStyle(color: _violetLit, fontSize: 10.5,
                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
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
          style: TextStyle(color: isFocused ? _violetLit : _textMid,
              fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
            color: isFocused ? _surfaceLit : _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isFocused ? _borderFoc : _border,
                width: isFocused ? 1.6 : 1.1),
            boxShadow: isFocused ? [BoxShadow(color: _violet.withOpacity(0.18),
                blurRadius: 14, offset: const Offset(0, 4))] : []),
        child: Row(children: [
          Padding(padding: const EdgeInsets.only(left: 14),
              child: Icon(icon,
                  color: isFocused ? _violetLit : _textDim, size: 19)),
          Expanded(child: TextField(controller: controller, focusNode: focusNode,
            obscureText: obscure,
            style: const TextStyle(color: _textHigh, fontSize: 14.5, height: 1.4),
            decoration: InputDecoration(hintText: hint,
                hintStyle: const TextStyle(color: _textDim, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 12)),
          )),
          if (suffix != null) suffix,
        ]),
      ),
    ]);
  }
}