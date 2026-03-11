import 'dart:math';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:flutter/material.dart';

// ─── Painter ──────────────────────────────────────────────────────────────────
class _CreatePostGeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p0 = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.18);
    final p1 = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.22);
    final p3 = Paint()..color = const Color(0xFFBBDEFB).withOpacity(0.28);

    canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width * 0.55, 0)
      ..lineTo(0, size.height * 0.14)..close(), p0);
    canvas.drawPath(Path()..moveTo(size.width, 0)..lineTo(size.width, size.height * 0.10)
      ..lineTo(size.width * 0.62, 0)..close(), p1);
    canvas.drawPath(Path()..moveTo(size.width, size.height * 0.82)..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.45, size.height)..close(), p0);
    canvas.drawPath(Path()..moveTo(0, size.height * 0.90)..lineTo(0, size.height)
      ..lineTo(size.width * 0.32, size.height)..close(), p3);

    _drawHexagon(canvas, Offset(size.width * 0.91, size.height * 0.18), size.width * 0.06, p1);
    _drawHexagon(canvas, Offset(size.width * 0.05, size.height * 0.55), size.width * 0.04, p3);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      i == 0 ? path.moveTo(center.dx + radius * cos(angle), center.dy + radius * sin(angle))
          : path.lineTo(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
    }
    path.close(); canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1E88E5).withOpacity(0.07)..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = spacing; x < size.width; x += spacing)
      for (double y = spacing; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), 1.4, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Create / Edit Post Screen ────────────────────────────────────────────────
class CreatePostScreen extends StatefulWidget {
  final int? localUserId;
  final Map<String, dynamic>? existingPost; // if set → edit mode

  const CreatePostScreen({super.key, this.localUserId, this.existingPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl       = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _postType = 'Help Request';
  String _category = 'Others';
  String _status   = 'Open';
  bool   _isLoading = false;

  bool get _isEditMode => widget.existingPost != null;

  final _postTypes  = ['Help Request', 'Skill Offer'];
  final _categories = ['Programming', 'Academic', 'Design', 'Others'];
  final _statuses   = ['Open', 'Resolved'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.existingPost!;
      _titleCtrl.text       = p['title'] ?? '';
      _descriptionCtrl.text = p['description'] ?? '';
      _postType = p['postType'] ?? 'Help Request';
      _category = p['category'] ?? 'Others';
      _status   = p['status']   ?? 'Open';
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError("Title is required."); return;
    }
    if (_descriptionCtrl.text.trim().isEmpty) {
      _showError("Description is required."); return;
    }
    if (widget.localUserId == null && !_isEditMode) {
      _showError("You must be logged in to create a post."); return;
    }

    setState(() => _isLoading = true);

    int result;
    if (_isEditMode) {
      result = await DatabaseHelper().updatePost(
        postId:      widget.existingPost!['id'],
        title:       _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        postType:    _postType,
        category:    _category,
        status:      _status,
      );
    } else {
      result = await DatabaseHelper().insertPost(
        userId:      widget.localUserId!,
        title:       _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        postType:    _postType,
        category:    _category,
        status:      _status,
      );
    }

    setState(() => _isLoading = false);

    if (result > 0) {
      AwesomeDialog(
        context: context, dialogType: DialogType.success,
        title: _isEditMode ? 'Post Updated' : 'Post Created',
        desc: _isEditMode ? 'Your post has been updated.' : 'Your post has been published.',
        btnOkOnPress: () => Navigator.of(context).pop(),
      ).show();
    } else {
      _showError("Something went wrong. Please try again.");
    }
  }

  void _showError(String msg) {
    AwesomeDialog(context: context, dialogType: DialogType.error,
        title: 'Error', desc: msg, btnOkOnPress: () {}).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFBBDEFB), Color(0xFF90CAF9), Color(0xFF64B5F6)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0.0, 0.35, 0.68, 1.0],
          ),
        )),
        CustomPaint(painter: _CreatePostGeometricPainter(), child: const SizedBox.expand()),
        IgnorePointer(child: CustomPaint(painter: _DotGridPainter(), child: const SizedBox.expand())),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Back + title row
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.65), shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.55), width: 1.5),
                      boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.15),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1565C0), size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isEditMode ? "Edit Post" : "New Post",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
                  Text(_isEditMode ? "Update your post details" : "Share a question or skill",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2))),
                ]),
              ]),

              // Divider
              Container(height: 2.5, margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFFBBDEFB)]))),

              // ── Form card ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82), borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.50), width: 1.2),
                  boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.10),
                      blurRadius: 18, offset: const Offset(0, 6))],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Title field
                  _sectionLabel("Title"),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _titleCtrl, hint: "e.g. Need help with Flutter layouts",
                      icon: Icons.title_rounded),
                  const SizedBox(height: 16),

                  // Description
                  _sectionLabel("Description"),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _descriptionCtrl, hint: "Describe your request or skill in detail...",
                      icon: Icons.description_outlined, maxLines: 5),
                  const SizedBox(height: 16),

                  // Post type selector
                  _sectionLabel("Post Type"),
                  const SizedBox(height: 8),
                  Row(children: _postTypes.map((t) {
                    final active = _postType == t;
                    final isHelp = t == 'Help Request';
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: isHelp ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _postType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active ? (isHelp ? const Color(0xFF1E88E5) : const Color(0xFF43A047)) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active
                                ? (isHelp ? const Color(0xFF1E88E5) : const Color(0xFF43A047))
                                : const Color(0xFF90CAF9)),
                            boxShadow: active ? [BoxShadow(
                                color: (isHelp ? const Color(0xFF1E88E5) : const Color(0xFF43A047)).withOpacity(0.25),
                                blurRadius: 8, offset: const Offset(0, 3))] : [],
                          ),
                          child: Column(children: [
                            Icon(isHelp ? Icons.help_outline_rounded : Icons.lightbulb_outline_rounded,
                                color: active ? Colors.white : const Color(0xFF1976D2), size: 20),
                            const SizedBox(height: 4),
                            Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: active ? Colors.white : const Color(0xFF1976D2))),
                          ]),
                        ),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 16),

                  // Category selector
                  _sectionLabel("Category"),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
                    final active = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF0D47A1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? const Color(0xFF0D47A1) : const Color(0xFF90CAF9)),
                          boxShadow: active ? [BoxShadow(color: const Color(0xFF0D47A1).withOpacity(0.25),
                              blurRadius: 6, offset: const Offset(0, 2))] : [],
                        ),
                        child: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: active ? Colors.white : const Color(0xFF1976D2))),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 16),

                  // Status (edit mode only or always show)
                  _sectionLabel("Status"),
                  const SizedBox(height: 8),
                  Row(children: _statuses.map((s) {
                    final active = _status == s;
                    final isOpen = s == 'Open';
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: isOpen ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _status = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active ? (isOpen ? const Color(0xFFEF5350) : const Color(0xFF43A047)) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active
                                ? (isOpen ? const Color(0xFFEF5350) : const Color(0xFF43A047))
                                : const Color(0xFF90CAF9)),
                          ),
                          child: Center(child: Text(s, style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : const Color(0xFF1976D2)))),
                        ),
                      ),
                    ));
                  }).toList()),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Submit button ──
              SizedBox(
                width: double.infinity, height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: const Color(0xFF1E88E5).withOpacity(0.40),
                        blurRadius: 18, offset: const Offset(0, 7))],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_isEditMode ? "UPDATE POST" : "PUBLISH POST",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                            fontSize: 15, letterSpacing: 1.5)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              SizedBox(
                width: double.infinity, height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF90CAF9), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text("CANCEL", style: TextStyle(color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.2)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)));
  }

  Widget _buildTextField({required TextEditingController controller, required String hint,
    required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF64B5F6).withOpacity(0.07),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 14),
        decoration: InputDecoration(
            prefixIcon: Padding(padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
                child: Icon(icon, color: const Color(0xFF1E88E5), size: 20)),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF90CAF9), fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4)),
      ),
    );
  }
}