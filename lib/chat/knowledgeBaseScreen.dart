import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/chat/materialViewerScreen.dart';
import 'package:flutter/material.dart';
import 'uploadMaterialScreen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

const _kAccent = Color(0xFF6366F1);
const _kInk = Color(0xFF1E1B4B);
const _kBg = Color(0xFFF8FAFC);
const _kBorder = Color(0xFFE8E8F0);

class KnowledgeBaseScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const KnowledgeBaseScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'PDF', 'Doc', 'Link', 'Video', 'Mine'
  ];

  // Material type → icon + color
  final Map<String, Map<String, dynamic>> _typeMeta = {
    'PDF':   {'icon': Icons.picture_as_pdf_rounded, 'color': Color(0xFFEF4444)},
    'Doc':   {'icon': Icons.description_rounded,    'color': Color(0xFF3B82F6)},
    'Link':  {'icon': Icons.link_rounded,           'color': Color(0xFF10B981)},
    'Video': {'icon': Icons.play_circle_rounded,    'color': Color(0xFFEC4899)},
    'Other': {'icon': Icons.insert_drive_file_rounded,'color': Color(0xFF9CA3AF)},
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getStream() {
    return FirebaseFirestore.instance
        .collection('knowledge')
        .snapshots();
  }


  // ── Client-side filter ─────────────────────────────────────────────────────
  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toLowerCase();
      final type = (data['type'] ?? '').toString();
      final uploaderId = data['uploadedBy'] ?? '';

      // Search filter
      if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) {
        return false;
      }

      // Type filter
      if (_selectedFilter == 'Mine') {
        return uploaderId == widget.currentUserId;
      }
      if (_selectedFilter != 'All' && type != _selectedFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(child: _buildMaterialList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccent,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UploadMaterialScreen(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
            ),
          ),
        ),
        child: const Icon(Icons.upload_file_rounded),
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
        "Knowledge Base",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search materials...",
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close_rounded,
                color: Colors.grey, size: 18),
          )
              : null,
          filled: true,
          fillColor: _kBg,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final filter = _filters[i];
          final selected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? _kAccent : _kBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _kAccent : _kBorder,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Material list ──────────────────────────────────────────────────────────
  Widget _buildMaterialList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return _buildEmptyState();
        }

        final filtered = _applyFilters(snapshot.data!.docs);

        if (filtered.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final data = filtered[i].data() as Map<String, dynamic>;
            final docId = filtered[i].id;
            final type = data['type'] ?? 'Other';
            final meta = _typeMeta[type] ?? _typeMeta['Other']!;

            return _MaterialCard(
              docId: docId,
              title: data['title'] ?? 'Untitled',
              type: type,
              uploaderName: data['uploaderName'] ?? 'Unknown',
              uploadedBy: data['uploadedBy'] ?? '',
              timeLabel: _formatTime(data['createdAt'] as Timestamp?),
              description: data['description'] ?? '',
              fileUrl: data['fileUrl'] ?? '',
              icon: meta['icon'] as IconData,
              color: meta['color'] as Color,
              currentUserId: widget.currentUserId,
            );
          },
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book_rounded,
                size: 36, color: _kAccent),
          ),
          const SizedBox(height: 16),
          const Text(
            "No materials yet",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap the upload button to share\nsomething with the community",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Material Card ──────────────────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  final String docId;
  final String title;
  final String type;
  final String uploaderName;
  final String uploadedBy;
  final String timeLabel;
  final String description;
  final String fileUrl;
  final IconData icon;
  final Color color;
  final String currentUserId;

  const _MaterialCard({
    required this.docId,
    required this.title,
    required this.type,
    required this.uploaderName,
    required this.uploadedBy,
    required this.timeLabel,
    required this.description,
    required this.fileUrl,
    required this.icon,
    required this.color,
    required this.currentUserId,
  });

  Future<void> _deleteMaterial(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete material?",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            "This will permanently remove this material."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('knowledge')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = uploadedBy == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8F0)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialViewerScreen(
              docId:          docId,
              title:          title,
              type:           type,
              fileUrl:        fileUrl,
              uploaderName:   uploaderName,
              currentUserId:  currentUserId,
              uploaderUserId: uploadedBy, // ← use the existing parameter
            ),
          ),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _kInk),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  description,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  uploaderName,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  timeLabel,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (fileUrl.isNotEmpty)
              IconButton(
                icon: Icon(
                  type == 'Link'
                      ? Icons.open_in_new_rounded
                      : Icons.download_rounded,
                  color: _kAccent,
                  size: 20,
                ),
                onPressed: () async {
                  if (type == 'Link') {
                    final uri = Uri.tryParse(fileUrl);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else if (fileUrl.startsWith('data:')) {
                    try {
                      final base64Str = fileUrl.substring(fileUrl.indexOf(',') + 1);
                      final bytes = base64Decode(base64Str);

                      final ext = type == 'PDF'   ? 'pdf'
                          : type == 'Doc'   ? 'docx'
                          : type == 'Video' ? 'mp4'
                          : 'bin';

                      // Use app documents directory — no permission needed
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File('${dir.path}/$title.$ext');
                      await file.writeAsBytes(bytes);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ "$title.$ext" saved! Find it in your file manager under Android/data'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                onPressed: () => _deleteMaterial(context),
              ),
          ],
        ),
      ),
    );
  }
}