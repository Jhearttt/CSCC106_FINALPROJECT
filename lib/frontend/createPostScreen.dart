import 'dart:io';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:final_project/backend/databaseHelper.dart';
import 'package:final_project/services/syncService.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _kInk         = Color(0xFF1E1B4B);
const _kInkMid      = Color(0xFF4338CA);
const _kInkMuted    = Color(0xFFA5B4FC);
const _kViolet      = Color(0xFF7B6CF6);
const _kVioletLight = Color(0xFFA78BFA);
const _kBlush       = Color(0xFFF472B6);
const _kMint        = Color(0xFF34D399);
const _kSky         = Color(0xFF60A5FA);
const _kAmber       = Color(0xFFFCD34D);
const _kBorderGlass = Color(0xFFE0D9FF);
const _kBase        = Color(0xFFF0EEFF);

// Urgency level colors
const _urgencyColors = {
  'Low':    Color(0xFF34D399), // mint
  'Medium': Color(0xFFFCD34D), // amber
  'High':   Color(0xFFF472B6), // blush/red
};
const _urgencyIcons = {
  'Low':    Icons.arrow_downward_rounded,
  'Medium': Icons.remove_rounded,
  'High':   Icons.arrow_upward_rounded,
};

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

  String  _postType     = 'Help Request';
  String  _category     = 'Others';
  String  _status       = 'Open';
  String  _urgencyLevel = 'Low';
  bool    _isLoading    = false;

  File?   _pickedImage;
  String? _existingImageUrl;
  bool    _removeExistingImage = false;
  final   _picker = ImagePicker();

  bool get _isEditMode => widget.existingPost != null;

  final _postTypes   = ['Help Request', 'Skill Offer'];
  final _categories  = ['Programming', 'Academic', 'Design', 'Others'];
  final _statuses    = ['Open', 'Resolved'];
  final _urgencies   = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.existingPost!;
      _titleCtrl.text       = p['title']        ?? '';
      _descriptionCtrl.text = p['description']  ?? '';
      _postType             = p['postType']      ?? 'Help Request';
      _category             = p['category']      ?? 'Others';
      _status               = p['status']        ?? 'Open';
      _urgencyLevel         = p['urgencyLevel']  ?? 'Low';
      _existingImageUrl     = p['imageUrl']      as String?;
    }

    // Smart title suggestion — listen to description changes
    _descriptionCtrl.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _descriptionCtrl.removeListener(_onDescriptionChanged);
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Smart Title Suggestion ────────────────────────────────────────────────
  void _onDescriptionChanged() {
    if (_titleCtrl.text.isNotEmpty) return; // don't overwrite user's title
    final suggested = _generateTitle(_descriptionCtrl.text);
    if (suggested.isNotEmpty) {
      _titleCtrl.text = suggested;
      _titleCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _titleCtrl.text.length));
    }
  }

  String _generateTitle(String desc) {
    final d = desc.toLowerCase();
    if (d.isEmpty) return '';
    // Category-based smart suggestions
    if (d.contains('flutter'))   return 'Need Help with Flutter';
    if (d.contains('widget'))    return 'Flutter Widget Issue';
    if (d.contains('dart'))      return 'Dart Programming Help Needed';
    if (d.contains('java'))      return 'Java Assistance Needed';
    if (d.contains('python'))    return 'Python Help Request';
    if (d.contains('database') || d.contains('sql')) return 'Database / SQL Help';
    if (d.contains('design') || d.contains('ui') || d.contains('figma'))
      return 'UI/UX Design Assistance';
    if (d.contains('algorithm') || d.contains('data structure'))
      return 'Algorithm / Data Structure Help';
    if (d.contains('debug') || d.contains('error') || d.contains('bug'))
      return 'Debugging Assistance Needed';
    if (d.contains('thesis') || d.contains('research'))
      return 'Thesis / Research Guidance';
    if (d.contains('math') || d.contains('calculus') || d.contains('algebra'))
      return 'Math / Calculus Help';
    // Generic fallback using first 6 words
    final words = desc.trim().split(RegExp(r'\s+')).take(6).join(' ');
    if (words.length > 4) {
      return words[0].toUpperCase() + words.substring(1);
    }
    return '';
  }

  // ── Image Picker ──────────────────────────────────────────────────────────
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.15),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: _kBorderGlass,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text("Add Photo", style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w800, color: _kInk)),
          ),
          const Divider(height: 1),
          _pickerOption(Icons.photo_library_rounded, "Choose from Gallery",
              _kViolet, () async {
                Navigator.pop(context);
                final xf = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (xf != null && mounted) setState(() {
                  _pickedImage = File(xf.path); _removeExistingImage = false;
                });
              }),
          _pickerOption(Icons.camera_alt_rounded, "Take a Photo", _kSky,
                  () async {
                Navigator.pop(context);
                final xf = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (xf != null && mounted) setState(() {
                  _pickedImage = File(xf.path); _removeExistingImage = false;
                });
              }),
          if (_pickedImage != null ||
              (_existingImageUrl != null && !_removeExistingImage))
            _pickerOption(Icons.delete_outline_rounded, "Remove Photo",
                _kBlush, () {
                  Navigator.pop(context);
                  setState(() { _pickedImage = null; _removeExistingImage = true; });
                }),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _pickerOption(IconData icon, String label, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: _kInk)),
        ]),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) { _showError("Title is required."); return; }
    if (_descriptionCtrl.text.trim().isEmpty) { _showError("Description is required."); return; }
    if (widget.localUserId == null && !_isEditMode) {
      _showError("You must be logged in to create a post."); return;
    }
    setState(() => _isLoading = true);

    final localUser = widget.localUserId != null
        ? await DatabaseHelper().getUserById(widget.localUserId!) : null;
    final userFullName = localUser?['fullName'] as String? ?? 'Unknown';
    final userUserName = localUser?['userName'] as String? ?? 'unknown';

    final imageLocalPath = _pickedImage?.path;
    final existingUrl    = _removeExistingImage ? null : _existingImageUrl;

    int result;
    if (_isEditMode) {
      result = await SyncService.instance.updatePost(
        postId:           widget.existingPost!['id'],
        userId:           widget.localUserId ?? widget.existingPost!['userId'],
        title:            _titleCtrl.text.trim(),
        description:      _descriptionCtrl.text.trim(),
        postType:         _postType,
        category:         _category,
        status:           _status,
        urgencyLevel:     _urgencyLevel,
        imageLocalPath:   imageLocalPath,
        existingImageUrl: existingUrl,
      );
    } else {
      result = await SyncService.instance.savePost(
        userId:         widget.localUserId!,
        userFullName:   userFullName,
        userUserName:   userUserName,
        title:          _titleCtrl.text.trim(),
        description:    _descriptionCtrl.text.trim(),
        postType:       _postType,
        category:       _category,
        status:         _status,
        urgencyLevel:   _urgencyLevel,
        imageLocalPath: imageLocalPath,
      );
    }

    setState(() => _isLoading = false);
    if (result > 0) {
      AwesomeDialog(
        context: context, dialogType: DialogType.success,
        title: _isEditMode ? 'Post Updated' : 'Post Created',
        desc:  _isEditMode ? 'Your post has been updated.'
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFFF0EEFF), Color(0xFFF5F0FF),
            Color(0xFFFFF0FA), Color(0xFFEEFBF5)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.68, 1.0],
        ))),
        CustomPaint(painter: _AuroraMeshPainter(), child: const SizedBox.expand()),

        SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Back bar
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
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w900, color: _kInk,
                        letterSpacing: -0.5)),
                Text(_isEditMode ? "Update your post details"
                    : "Share a question or skill",
                    style: const TextStyle(fontSize: 12, color: _kInkMuted)),
              ]),
            ]),

            Container(height: 2.5, margin: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [_kViolet, _kVioletLight, Color(0xFFEC4899)],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  )),
            ),

            // Form card
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.80),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _kBorderGlass, width: 1.2),
                boxShadow: [BoxShadow(color: _kViolet.withOpacity(0.10),
                    blurRadius: 22, offset: const Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Title (auto-filled by smart suggestion)
                    _fieldLabel("Title"),
                    const SizedBox(height: 4),
                    // Smart suggestion hint
                    Row(children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: _kViolet, size: 12),
                      const SizedBox(width: 4),
                      const Text("Title auto-suggests as you type",
                          style: TextStyle(fontSize: 10.5, color: _kInkMuted,
                              fontStyle: FontStyle.italic)),
                      const Spacer(),
                      if (_titleCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _titleCtrl.clear()),
                          child: const Text("Clear",
                              style: TextStyle(fontSize: 10.5, color: _kViolet,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    _buildTextField(controller: _titleCtrl,
                        hint: "e.g. Need help with Flutter layouts",
                        icon: Icons.title_rounded),
                    const SizedBox(height: 18),

                    // Description
                    _fieldLabel("Description"),
                    const SizedBox(height: 7),
                    _buildTextField(controller: _descriptionCtrl,
                        hint: "Describe your request or skill...",
                        icon: Icons.description_outlined, maxLines: 5),
                    const SizedBox(height: 20),

                    // Photo
                    _fieldLabel("Photo"),
                    const SizedBox(height: 7),
                    _buildImagePreview(),
                    const SizedBox(height: 20),

                    // Post type
                    _fieldLabel("Post Type"),
                    const SizedBox(height: 10),
                    Row(children: _postTypes.map((t) {
                      final active = _postType == t;
                      final isHelp = t == 'Help Request';
                      return Expanded(child: Padding(
                        padding: EdgeInsets.only(right: isHelp ? 10 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _postType = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: active ? (isHelp
                                  ? const LinearGradient(
                                  colors: [_kSky, Color(0xFF3B82F6)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : const LinearGradient(
                                  colors: [Color(0xFF059669), _kMint],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight))
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
                              Icon(isHelp ? Icons.help_outline_rounded
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

                    // Category
                    _fieldLabel("Category"),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8,
                        children: _categories.map((c) {
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

                    // ── Urgency Level ──
                    _fieldLabel("Urgency Level"),
                    const SizedBox(height: 10),
                    Row(children: _urgencies.map((u) {
                      final active = _urgencyLevel == u;
                      final color  = _urgencyColors[u]!;
                      final icon   = _urgencyIcons[u]!;
                      return Expanded(child: Padding(
                        padding: EdgeInsets.only(
                            right: u != _urgencies.last ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _urgencyLevel = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: active
                                  ? color.withOpacity(0.15)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: active ? color : _kBorderGlass,
                                  width: active ? 1.8 : 1.2),
                              boxShadow: active ? [BoxShadow(
                                  color: color.withOpacity(0.20),
                                  blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Column(children: [
                              Icon(icon, color: active ? color : _kInkMuted,
                                  size: 18),
                              const SizedBox(height: 4),
                              Text(u, style: TextStyle(fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: active ? color : _kInkMuted)),
                            ]),
                          ),
                        ),
                      ));
                    }).toList()),

                    const SizedBox(height: 20),

                    // Status
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
                              gradient: active ? (isOpen
                                  ? const LinearGradient(
                                  colors: [Color(0xFFEC4899), _kBlush],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight)
                                  : const LinearGradient(
                                  colors: [Color(0xFF059669), _kMint],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight))
                                  : null,
                              color: active ? null : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: active ? (isOpen ? _kBlush : _kMint) : _kBorderGlass,
                                  width: 1.2),
                              boxShadow: active ? [BoxShadow(
                                  color: (isOpen ? _kBlush : _kMint).withOpacity(0.28),
                                  blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Center(child: Text(s, style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: active ? Colors.white : _kInkMuted))),
                          ),
                        ),
                      ));
                    }).toList()),
                  ]),
            ),

            const SizedBox(height: 24),

            // Submit
            SizedBox(width: double.infinity, height: 56,
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
            SizedBox(width: double.infinity, height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kBorderGlass, width: 1.5),
                  backgroundColor: Colors.white.withOpacity(0.60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("CANCEL", style: TextStyle(color: _kInkMuted,
                    fontWeight: FontWeight.w700, fontSize: 14,
                    letterSpacing: 1.2)),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: _kInkMid, letterSpacing: 0.2));

  Widget _buildTextField({
    required TextEditingController controller, required String hint,
    required IconData icon, int maxLines = 1,
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
              child: Icon(icon, color: _kVioletLight, size: 20)),
          hintText: hint,
          hintStyle: const TextStyle(color: _kInkMuted, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final bool hasLocal    = _pickedImage != null;
    final bool hasExisting = _existingImageUrl != null && !_removeExistingImage;
    final bool hasAny      = hasLocal || hasExisting;
    return GestureDetector(
      onTap: _showImagePicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: hasAny ? 200 : 72,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasAny ? Colors.transparent : _kBase.withOpacity(0.70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: hasAny ? _kViolet.withOpacity(0.40) : _kBorderGlass,
              width: hasAny ? 1.5 : 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasAny
            ? Stack(fit: StackFit.expand, children: [
          hasLocal
              ? Image.file(_pickedImage!, fit: BoxFit.cover)
              : Image.network(_existingImageUrl!, fit: BoxFit.cover,
            loadingBuilder: (_, child, p) => p == null ? child
                : Center(child: CircularProgressIndicator(color: _kViolet,
                value: p.expectedTotalBytes != null
                    ? p.cumulativeBytesLoaded / p.expectedTotalBytes! : null)),
          ),
          Positioned(top: 8, right: 8, child: Row(children: [
            _overlayBtn(Icons.edit_rounded, _kViolet, _showImagePicker),
            const SizedBox(width: 6),
            _overlayBtn(Icons.close_rounded, _kBlush, () => setState(() {
              _pickedImage = null; _removeExistingImage = true;
            })),
          ])),
        ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _kViolet.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  color: _kViolet, size: 20)),
          const SizedBox(width: 10),
          const Text("Add a photo (optional)",
              style: TextStyle(fontSize: 13, color: _kInkMuted,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _overlayBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.90),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
                      blurRadius: 6)]),
              child: Icon(icon, color: color, size: 16)));
}