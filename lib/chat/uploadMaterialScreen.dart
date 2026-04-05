import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk = Color(0xFF1E1B4B);
const _kBg = Color(0xFFF8FAFC);
const _kBorder = Color(0xFFE8E8F0);

class UploadMaterialScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const UploadMaterialScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<UploadMaterialScreen> createState() => _UploadMaterialScreenState();
}

class _UploadMaterialScreenState extends State<UploadMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _linkController = TextEditingController();

  String _selectedType = 'PDF';
  bool _loading = false;
  double _uploadProgress = 0;
  PlatformFile? _pickedFile;

  final List<String> _types = ['PDF', 'Doc', 'Link', 'Video', 'Other'];

  final Map<String, Map<String, dynamic>> _typeMeta = {
    'PDF':   {'icon': Icons.picture_as_pdf_rounded,    'color': Color(0xFFEF4444)},
    'Doc':   {'icon': Icons.description_rounded,       'color': Color(0xFF3B82F6)},
    'Link':  {'icon': Icons.link_rounded,              'color': Color(0xFF10B981)},
    'Video': {'icon': Icons.play_circle_rounded,       'color': Color(0xFFEC4899)},
    'Other': {'icon': Icons.insert_drive_file_rounded, 'color': Color(0xFF9CA3AF)},
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ── Pick file ──────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _selectedType == 'PDF'
          ? FileType.custom
          : FileType.any,
      allowedExtensions: _selectedType == 'PDF' ? ['pdf'] : null,
      withData: false,
      withReadStream: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  // ── Upload to Firebase Storage ─────────────────────────────────────────────
  Future<String> _toBase64() async {
    final bytes = await File(_pickedFile!.path!).readAsBytes();
    return base64Encode(bytes);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType != 'Link' && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a file to upload'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() { _loading = true; _uploadProgress = 0; });

    try {
      String fileUrl  = '';
      String fileName = '';
      int    fileSize = 0;

      if (_selectedType == 'Link') {
        // Just store the URL directly
        fileUrl  = _linkController.text.trim();
        fileName = fileUrl;
      } else {
        // ── Store file as base64 ONLY if under 500KB ──────────────────────
        final sizeKb = _pickedFile!.size / 1024;

        if (sizeKb > 500) {
          // File too large — tell the user to use a link instead
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'File is too large (${sizeKb.toStringAsFixed(0)}KB). '
                      'Please upload to Google Drive / GitHub and paste the link instead.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }

        // Under 500KB — safe to base64 encode
        setState(() => _uploadProgress = 0.3);
        final bytes  = await File(_pickedFile!.path!).readAsBytes();
        setState(() => _uploadProgress = 0.6);
        fileUrl  = 'data:application/octet-stream;base64,${base64Encode(bytes)}';
        fileName = _pickedFile!.name;
        fileSize = _pickedFile!.size;
        setState(() => _uploadProgress = 0.9);
      }

      // Save to Firestore — no raw file data for large files
      await FirebaseFirestore.instance.collection('knowledge').add({
        'title':        _titleController.text.trim(),
        'description':  _descController.text.trim(),
        'type':         _selectedType,
        'fileUrl':      fileUrl,   // ← renamed from fileData
        'fileName':     fileName,
        'fileSize':     fileSize,
        'uploadedBy':   widget.currentUserId,
        'uploaderName': widget.currentUserName,
        'createdAt':    FieldValue.serverTimestamp(),
        'downloads':    0,
        'helpful':      0,
      });

      setState(() => _uploadProgress = 1.0);
      if (mounted) _showSuccessAndPop();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: Colors.red),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: _kAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "Uploaded!",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kInk),
              ),
              const SizedBox(height: 8),
              Text(
                '"${_titleController.text.trim()}" is now\navailable in the Knowledge Base.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close dialog
                    Navigator.pop(context); // back to knowledge base
                  },
                  child: const Text("Done",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
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
            _buildSectionLabel("Material type"),
            _buildTypeSelector(),
            const SizedBox(height: 24),
            _buildSectionLabel("Details"),
            _buildTitleField(),
            const SizedBox(height: 14),
            _buildDescField(),
            const SizedBox(height: 24),

            // Show link field or file picker depending on type
            if (_selectedType == 'Link') ...[
              _buildSectionLabel("URL"),
              _buildLinkField(),
            ] else ...[
              _buildSectionLabel("File"),
              _buildFilePicker(),
            ],

            const SizedBox(height: 32),

            // Upload progress bar
            if (_loading && _selectedType != 'Link') ...[
              _buildProgressBar(),
              const SizedBox(height: 24),
            ],

            _buildSubmitButton(),
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
        "Upload Material",
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

  // ── Type selector ──────────────────────────────────────────────────────────
  Widget _buildTypeSelector() {
    return Row(
      children: _types.map((type) {
        final meta = _typeMeta[type]!;
        final color = meta['color'] as Color;
        final icon = meta['icon'] as IconData;
        final selected = _selectedType == type;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedType = type;
              _pickedFile = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.10) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : _kBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon,
                      size: 20,
                      color: selected ? color : Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Title field ────────────────────────────────────────────────────────────
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration(
        hint: "Material title",
        icon: Icons.title_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter a title';
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
        hint: "Brief description (optional)",
        icon: Icons.notes_rounded,
      ),
    );
  }

  // ── Link field ─────────────────────────────────────────────────────────────
  Widget _buildLinkField() {
    return TextFormField(
      controller: _linkController,
      keyboardType: TextInputType.url,
      decoration: _inputDecoration(
        hint: "https://...",
        icon: Icons.link_rounded,
      ),
      validator: (v) {
        if (_selectedType == 'Link') {
          if (v == null || v.trim().isEmpty) return 'Please enter a URL';
          if (!v.startsWith('http')) return 'URL must start with http';
        }
        return null;
      },
    );
  }

  // ── File picker ────────────────────────────────────────────────────────────
  Widget _buildFilePicker() {
    return GestureDetector(
      onTap: _loading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pickedFile != null
              ? _kAccent.withOpacity(0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pickedFile != null ? _kAccent : _kBorder,
            width: _pickedFile != null ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: _pickedFile != null
            ? _buildPickedFilePreview()
            : _buildFilePickerPlaceholder(),
      ),
    );
  }

  Widget _buildFilePickerPlaceholder() {
    return Column(
      children: [
        Icon(Icons.cloud_upload_rounded,
            size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text(
          "Tap to pick a file",
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _kInk,
              fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          _selectedType == 'PDF' ? "PDF files only" : "Any file type",
          style: TextStyle(
              color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPickedFilePreview() {
    final meta = _typeMeta[_selectedType] ?? _typeMeta['Other']!;
    final color = meta['color'] as Color;
    final icon = meta['icon'] as IconData;
    final sizeKb = (_pickedFile!.size / 1024).toStringAsFixed(1);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pickedFile!.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kInk),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$sizeKb KB',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _pickedFile = null),
          child: const Icon(Icons.close_rounded,
              color: Colors.grey, size: 18),
        ),
      ],
    );
  }

  // ── Progress bar ───────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final percent = (_uploadProgress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Uploading...",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kInk)),
            Text("$percent%",
                style: const TextStyle(
                    fontSize: 12, color: _kAccent)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: _kBorder,
            color: _kAccent,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Submit button ──────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
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
        onPressed: _loading ? null : _submit,
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
            Icon(Icons.upload_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              "Upload Material",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
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
}