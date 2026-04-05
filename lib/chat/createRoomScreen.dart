import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:final_project/services/forumService.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk = Color(0xFF1E1B4B);
const _kBg = Color(0xFFF8FAFC);
const _kBorder = Color(0xFFE8E8F0);

class CreateRoomScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const CreateRoomScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();

  String _selectedCategory = 'General';
  bool _isPrivate = false;
  bool _loading = false;
  final List<String> _tags = [];

  final List<String> _categories = [
    'General',
    'Math',
    'Science',
    'Programming',
    'Design',
    'Business',
    'Language',
    'Engineering',
    'Other',
  ];

  // Category → icon + color
  final Map<String, Map<String, dynamic>> _categoryMeta = {
    'General':     {'icon': Icons.forum_rounded,         'color': Color(0xFF6366F1)},
    'Math':        {'icon': Icons.calculate_rounded,     'color': Color(0xFF8B5CF6)},
    'Science':     {'icon': Icons.science_rounded,       'color': Color(0xFF06B6D4)},
    'Programming': {'icon': Icons.code_rounded,          'color': Color(0xFF10B981)},
    'Design':      {'icon': Icons.palette_rounded,       'color': Color(0xFFEC4899)},
    'Business':    {'icon': Icons.business_center_rounded,'color': Color(0xFFF59E0B)},
    'Language':    {'icon': Icons.translate_rounded,     'color': Color(0xFF3B82F6)},
    'Engineering': {'icon': Icons.engineering_rounded,   'color': Color(0xFFEF4444)},
    'Other':       {'icon': Icons.more_horiz_rounded,    'color': Color(0xFF9CA3AF)},
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ── Add tag ────────────────────────────────────────────────────────────────
  void _addTag(String tag) {
    final cleaned = tag.trim().toLowerCase();
    if (cleaned.isEmpty || _tags.contains(cleaned) || _tags.length >= 5) return;
    setState(() => _tags.add(cleaned));
    _tagController.clear();
  }

  // ── Remove tag ─────────────────────────────────────────────────────────────
  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  // ── Create forum ───────────────────────────────────────────────────────────
  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('forums').add({
        'title':       _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category':    _selectedCategory,
        'tags':        _tags,
        'isPrivate':   _isPrivate,
        'createdBy':   widget.currentUserId,
        'createdByName': widget.currentUserName,
        'memberCount': 1,
        'postCount':   0,
        'members':     [widget.currentUserId],
        'createdAt':   FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessAndPop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessAndPop() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: _kAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text("Room Created!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 8),
              Text('"${_titleController.text.trim()}" is ready.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // ← FIXED: just pop dialog then pop screen once
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // back to forum list
                  },
                  child: const Text("Done",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionLabel("Room details"),
            _buildTitleField(),
            const SizedBox(height: 14),
            _buildDescField(),
            const SizedBox(height: 24),
            _buildSectionLabel("Category"),
            _buildCategoryGrid(),
            const SizedBox(height: 24),
            _buildSectionLabel("Tags  (max 5)"),
            _buildTagInput(),
            const SizedBox(height: 10),
            _buildTagChips(),
            const SizedBox(height: 24),
            _buildSectionLabel("Privacy"),
            _buildPrivacyToggle(),
            const SizedBox(height: 32),
            _buildCreateButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _kInk,
      title: const Text(
        "Create Room",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade500,
            letterSpacing: 1.2),
      ),
    );
  }

  // ── Title field ────────────────────────────────────────────────────────────
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        hint: "Room name",
        icon: Icons.meeting_room_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter a room name';
        if (v.trim().length < 3) return 'Name must be at least 3 characters';
        return null;
      },
    );
  }

  // ── Description field ──────────────────────────────────────────────────────
  Widget _buildDescField() {
    return TextFormField(
      controller: _descController,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration(
        hint: "What is this room about? (optional)",
        icon: Icons.description_rounded,
      ),
    );
  }

  // ── Shared input decoration ────────────────────────────────────────────────
  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  // ── Category grid ──────────────────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: _categories.map((cat) {
        final meta = _categoryMeta[cat]!;
        final color = meta['color'] as Color;
        final icon = meta['icon'] as IconData;
        final selected = _selectedCategory == cat;

        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : _kBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? color : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected ? color : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tag input ──────────────────────────────────────────────────────────────
  Widget _buildTagInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _tagController,
            textCapitalization: TextCapitalization.none,
            decoration: _inputDecoration(
              hint: "Add a tag e.g. flutter",
              icon: Icons.tag_rounded,
            ),
            onFieldSubmitted: _addTag,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _addTag(_tagController.text),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  // ── Tag chips ──────────────────────────────────────────────────────────────
  Widget _buildTagChips() {
    if (_tags.isEmpty) {
      return Text(
        "No tags added yet",
        style: TextStyle(
            color: Colors.grey.shade400, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        return Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _kAccent.withOpacity(0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#$tag',
                style: const TextStyle(
                    color: _kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeTag(tag),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: _kAccent),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Privacy toggle ─────────────────────────────────────────────────────────
  Widget _buildPrivacyToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Icon(
            _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            color: _isPrivate ? _kAccent : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? "Private room" : "Public room",
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _kInk),
                ),
                Text(
                  _isPrivate
                      ? "Only invited members can join"
                      : "Anyone can find and join",
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
            activeColor: _kAccent,
          ),
        ],
      ),
    );
  }

  // ── Create button ──────────────────────────────────────────────────────────
  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _loading ? null : _createRoom,
        child: _loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: Colors.white),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              "Create Room",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}