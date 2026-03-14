import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';

// ─── Aurora Palette ───────────────────────────────────────────────────────────
const _kInk         = Color(0xFF1E1B4B);
const _kInkMid      = Color(0xFF4338CA);
const _kInkMuted    = Color(0xFFA5B4FC);
const _kViolet      = Color(0xFF7B6CF6);
const _kVioletLight = Color(0xFFA78BFA);
const _kBlush       = Color(0xFFF472B6);
const _kMint        = Color(0xFF34D399);
const _kSky         = Color(0xFF60A5FA);
const _kBorderGlass = Color(0xFFE0D9FF);
const _kBase        = Color(0xFFF0EEFF);

class _AuroraMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void orb(Offset c, double r, Color color, double opacity) {
      canvas.drawCircle(c, r, Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)));
    }
    orb(Offset(size.width * 0.10, size.height * 0.04), size.width * 0.50, _kViolet, 0.18);
    orb(Offset(size.width * 0.90, size.height * 0.10), size.width * 0.38, const Color(0xFFC084FC), 0.15);
    orb(Offset(size.width * 0.85, size.height * 0.88), size.width * 0.38, _kMint, 0.12);
    orb(Offset(size.width * 0.06, size.height * 0.82), size.width * 0.35, _kSky, 0.11);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Create / Edit Post Screen ────────────────────────────────────────────────
class CreatePostScreen extends StatefulWidget {
  final int? localUserId;
  final Map<String, dynamic>? existingPost;

  const CreatePostScreen({super.key, this.localUserId, this.existingPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl       = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _postType  = 'Help Request';
  String _category  = 'Others';
  String _status    = 'Open';
  bool   _isLoading = false;

  bool get _isEditMode => widget.existingPost != null;

  // SRS: Post Type options
  final _postTypes  = ['Help Request', 'Skill Offer'];
  // SRS: Category options
  final _categories = ['Programming', 'Academic', 'Design', 'Others'];
  // SRS: Status options
  final _statuses   = ['Open', 'Resolved'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.existingPost!;
      _titleCtrl.text       = p['title']       ?? '';
      _descriptionCtrl.text = p['description'] ?? '';
      _postType = p['postType'] ?? 'Help Request';
      _category = p['category'] ?? 'Others';
      _status   = p['status']   ?? 'Open';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Submit: insert or update post ────────────────────────────────────────
  // SRS: If online → Firestore via SyncService; if offline → local SQLite (synced=0)
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

    // Fetch local user info so SyncService can store it in Firestore
    final localUser = widget.localUserId != null
        ? await DatabaseHelper().getUserById(widget.localUserId!)
        : null;
    final userFullName = localUser?['fullName'] as String? ?? 'Unknown';
    final userUserName = localUser?['userName'] as String? ?? 'unknown';

    int result;
    if (_isEditMode) {
      result = await SyncService.instance.updatePost(
        postId:      widget.existingPost!['id'],
        title:       _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        postType:    _postType,
        category:    _category,
        status:      _status,
      );
    } else {
      result = await SyncService.instance.savePost(
        userId:       widget.localUserId!,
        userFullName: userFullName,
        userUserName: userUserName,
        title:        _titleCtrl.text.trim(),
        description:  _descriptionCtrl.text.trim(),
        postType:     _postType,
        category:     _category,
        status:       _status,
      );
    }

    setState(() => _isLoading = false);

    if (result > 0) {
    AwesomeDialog(
    context: context, dialogType: DialogType.success,
    title: _isEditMode ? 'Post Updated' : 'Post Created',
    desc: _isEditMode
    ? 'Your post has been updated.'
        : 'Your post has been published.',
    btnOkOnPress: () => Navigator.of(context).pop(true),
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
            colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
              Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: [0.0, 0.35, 0.68, 1.0],
          ),
        )),
        CustomPaint(painter: _AuroraMeshPainter(), child: const SizedBox.expand()),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Back bar ──
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _kBorderGlass, width: 1.2),
                      boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _kViolet, size: 17),
                  ),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isEditMode ? "Edit Post" : "New Post",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                          color: _kInk, letterSpacing: -0.5)),
                  Text(_isEditMode
                      ? "Update your post details"
                      : "Share a question or skill",
                      style: const TextStyle(fontSize: 12, color: _kInkMuted)),
                ]),
              ]),

              Container(
                height: 2.5, margin: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                ),
              ),

              // ── Form card ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.80),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _kBorderGlass, width: 1.2),
                  boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                      blurRadius: 22, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Title field
                  _fieldLabel("Title"),
                  const SizedBox(height: 7),
                  _buildTextField(controller: _titleCtrl,
                      hint: "e.g. Need help with Flutter layouts",
                      icon: Icons.title_rounded),
                  const SizedBox(height: 18),

                  // Description field
                  _fieldLabel("Description"),
                  const SizedBox(height: 7),
                  _buildTextField(controller: _descriptionCtrl,
                      hint: "Describe your request or skill in detail...",
                      icon: Icons.description_outlined, maxLines: 5),
                  const SizedBox(height: 20),

                  // Post type selector (SRS: Help Request | Skill Offer)
                  _fieldLabel("Post Type"),
                  const SizedBox(height: 10),
                  Row(children: _postTypes.map((t) {
                    final active  = _postType == t;
                    final isHelp  = t == 'Help Request';
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: isHelp ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _postType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: active
                                ? (isHelp
                                ? const LinearGradient(
                                colors: [_kSky, Color(0xFF3B82F6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                                : const LinearGradient(
                                colors: [Color(0xFF059669), _kMint],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight))
                                : null,
                            color: active ? null : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: active ? (isHelp ? _kSky : _kMint) : _kBorderGlass,
                                width: 1.2),
                            boxShadow: active ? [BoxShadow(
                                color: (isHelp ? _kSky : _kMint).withOpacity(0.30),
                                blurRadius: 10, offset: const Offset(0, 4))] : [],
                          ),
                          child: Column(children: [
                            Icon(isHelp
                                ? Icons.help_outline_rounded
                                : Icons.lightbulb_outline_rounded,
                                color: active ? Colors.white : _kInkMuted, size: 22),
                            const SizedBox(height: 5),
                            Text(t, style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : _kInkMuted)),
                          ]),
                        ),
                      ),
                    ));
                  }).toList()),

                  const SizedBox(height: 20),

                  // Category selector (SRS: Programming | Academic | Design | Others)
                  _fieldLabel("Category"),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
                    final active = _category == c;
                    return GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: active ? const LinearGradient(
                              colors: [_kViolet, _kVioletLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight) : null,
                          color: active ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: active ? _kViolet : _kBorderGlass, width: 1.2),
                          boxShadow: active ? [BoxShadow(
                              color: _kViolet.withOpacity(0.28),
                              blurRadius: 8, offset: const Offset(0, 3))] : [],
                        ),
                        child: Text(c, style: TextStyle(fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : _kInkMuted)),
                      ),
                    );
                  }).toList()),

                  const SizedBox(height: 20),

                  // Status selector (SRS: Open | Resolved)
                  _fieldLabel("Status"),
                  const SizedBox(height: 10),
                  Row(children: _statuses.map((s) {
                    final active = _status == s;
                    final isOpen = s == 'Open';
                    return Expanded(child: Padding(
                      padding: EdgeInsets.only(right: isOpen ? 10 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _status = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: active
                                ? (isOpen
                                ? const LinearGradient(
                                colors: [Color(0xFFEC4899), _kBlush],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                                : const LinearGradient(
                                colors: [Color(0xFF059669), _kMint],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight))
                                : null,
                            color: active ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: active ? (isOpen ? _kBlush : _kMint)
                                    : _kBorderGlass,
                                width: 1.2),
                            boxShadow: active ? [BoxShadow(
                                color: (isOpen ? _kBlush : _kMint).withOpacity(0.28),
                                blurRadius: 8, offset: const Offset(0, 3))] : [],
                          ),
                          child: Center(child: Text(s, style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : _kInkMuted))),
                        ),
                      ),
                    ));
                  }).toList()),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Submit button ──
              SizedBox(
                width: double.infinity, height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: _kViolet.withOpacity(0.38),
                          blurRadius: 20, offset: const Offset(0, 8)),
                      BoxShadow(color: _kBlush.withOpacity(0.20),
                          blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                        : Text(_isEditMode ? "UPDATE POST" : "PUBLISH POST",
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 15,
                            letterSpacing: 1.2)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              SizedBox(
                width: double.infinity, height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _kBorderGlass, width: 1.5),
                    backgroundColor: Colors.white.withOpacity(0.60),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("CANCEL",
                      style: TextStyle(color: _kInkMuted,
                          fontWeight: FontWeight.w700, fontSize: 14,
                          letterSpacing: 1.2)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.w700, color: _kInkMid, letterSpacing: 0.2));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kBase.withOpacity(0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderGlass, width: 1.2),
        boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controller, maxLines: maxLines,
        style: const TextStyle(color: _kInk, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 60 : 0),
            child: Icon(icon, color: _kVioletLight, size: 20),
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: _kInkMuted, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }
}