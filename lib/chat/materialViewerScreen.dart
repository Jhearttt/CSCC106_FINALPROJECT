import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk    = Color(0xFF1E1B4B);
const _kBg     = Color(0xFFF8FAFC);

class MaterialViewerScreen extends StatefulWidget {
  final String docId;
  final String title;
  final String type;
  final String fileUrl;
  final String uploaderName;
  final String currentUserId;
  final String uploaderUserId; // ← ADD THIS

  const MaterialViewerScreen({
    super.key,
    required this.docId,
    required this.title,
    required this.type,
    required this.fileUrl,
    required this.uploaderName,
    required this.currentUserId,
    required this.uploaderUserId, // ← ADD THIS
  });

  @override
  State<MaterialViewerScreen> createState() => _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends State<MaterialViewerScreen> {
  String? _localPdfPath;
  bool    _loading    = true;
  String? _error;
  int     _totalPages = 0;
  int     _currentPage = 0;
  String  _externalLink = '';
  final   _linkController = TextEditingController();
  bool    _savingLink = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Load external link from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('knowledge')
          .doc(widget.docId)
          .get();
      if (doc.exists) {
        setState(() {
          _externalLink = doc.data()?['externalLink'] ?? '';
          _linkController.text = _externalLink;
        });
      }
    } catch (_) {}

    // If PDF — decode base64 and write to temp file
    if (widget.type == 'PDF' && widget.fileUrl.startsWith('data:')) {
      await _preparePdf();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _preparePdf() async {
    try {
      final base64Str =
      widget.fileUrl.substring(widget.fileUrl.indexOf(',') + 1);
      final bytes  = base64Decode(base64Str);
      final dir    = await getTemporaryDirectory();
      final file   = File('${dir.path}/${widget.title}.pdf');
      await file.writeAsBytes(bytes);
      setState(() {
        _localPdfPath = file.path;
        _loading      = false;
      });
    } catch (e) {
      setState(() {
        _error   = 'Could not load PDF: $e';
        _loading = false;
      });
    }
  }

  // ── Save external link ─────────────────────────────────────────────────────
  Future<void> _saveExternalLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;
    setState(() => _savingLink = true);
    try {
      await FirebaseFirestore.instance
          .collection('knowledge')
          .doc(widget.docId)
          .update({'externalLink': link});
      setState(() => _externalLink = link);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Link saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingLink = false);
    }
  }

  // ── Open external link ─────────────────────────────────────────────────────
  Future<void> _openExternalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(children: [
        // ── External link banner ───────────────────────────────────────────
        _buildExternalLinkSection(),

        // ── Main content ───────────────────────────────────────────────────
        Expanded(child: _buildContent()),
      ]),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _kInk,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis),
          Text('by ${widget.uploaderName}',
              style: const TextStyle(
                  fontSize: 11, color: Colors.grey)),
        ],
      ),
      actions: [
        // Page count for PDFs
        if (widget.type == 'PDF' && _totalPages > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  // ── External link section ──────────────────────────────────────────────────
  Widget _buildExternalLinkSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show existing link if available
          if (_externalLink.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openExternalLink(_externalLink),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _kAccent.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.download_rounded,
                      color: _kAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _externalLink,
                      style: const TextStyle(
                          color: _kAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded,
                      color: _kAccent, size: 14),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Add/update link field — only for uploader
          if (widget.currentUserId == widget.uploaderUserId)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _linkController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: _externalLink.isEmpty
                        ? 'Add download link (Google Drive, GitHub...)'
                        : 'Update download link...',
                    hintStyle: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.link_rounded,
                        color: Colors.grey, size: 18),
                    filled: true,
                    fillColor: _kBg,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _savingLink ? null : _saveExternalLink,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _savingLink
                      ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white),
                  )
                      : const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    // ── PDF viewer ─────────────────────────────────────────────────────────
    if (widget.type == 'PDF' && _localPdfPath != null) {
      return PDFView(
        filePath: _localPdfPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageSnap: false,
        onRender: (pages) => setState(() => _totalPages = pages ?? 0),
        onPageChanged: (page, total) =>
            setState(() => _currentPage = page ?? 0),
        onError: (e) => setState(() => _error = e.toString()),
      );
    }

    // ── Link type ──────────────────────────────────────────────────────────
    if (widget.type == 'Link') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link_rounded,
                  color: Color(0xFF10B981), size: 32),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kInk)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => _openExternalLink(widget.fileUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open Link',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );
    }

    // ── Other file types ───────────────────────────────────────────────────
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insert_drive_file_rounded,
                color: _kAccent, size: 32),
          ),
          const SizedBox(height: 16),
          Text(widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kInk)),
          const SizedBox(height: 8),
          Text('${widget.type} file',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          if (_externalLink.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => _openExternalLink(_externalLink),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download File',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No download link added yet. The uploader can add a Google Drive or GitHub link above.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}