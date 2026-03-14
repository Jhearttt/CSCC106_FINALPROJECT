import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // ─── DB Config ───────────────────────────────────────────────────────────
  static const _dbName = 'campusaid.db';
  static const _dbVersion = 1;

  Database? _db;

  // ─── Open / Init DB ──────────────────────────────────────────────────────
  /// Public accessor for SyncService and other classes that need raw DB access.
  Future<Database> getDatabase() => _database();

  Future<Database> _database() async {
    if (_db != null) return _db!;

    final path = await getDatabasesPath();

    _db = await openDatabase(
      '$path/$_dbName',
      version: _dbVersion,
      onCreate: (db, version) async {
        // ── Users table ────────────────────────────────────────────────────
        await db.execute("""
          CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName      TEXT    NOT NULL,
            userName      TEXT    NOT NULL UNIQUE,
            password      TEXT    NOT NULL,
            email         TEXT,
            profilePic    TEXT,
            dateAdded     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        """);

        // ── Posts table ────────────────────────────────────────────────────
        // postType  : 'Help Request' | 'Skill Offer'
        // category  : 'Programming' | 'Academic' | 'Design' | 'Others'
        // status    : 'Open' | 'Resolved'
        // synced    : 0 = local only, 1 = synced with Firebase
        await db.execute("""
          CREATE TABLE IF NOT EXISTS posts (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            userId        INTEGER NOT NULL,
            title         TEXT    NOT NULL,
            description   TEXT    NOT NULL,
            postType      TEXT    NOT NULL DEFAULT 'Help Request',
            category      TEXT    NOT NULL DEFAULT 'Others',
            status        TEXT    NOT NULL DEFAULT 'Open',
            synced        INTEGER NOT NULL DEFAULT 0,
            datePosted    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
          )
        """);

        // ── Comments table ─────────────────────────────────────────────────
        await db.execute("""
          CREATE TABLE IF NOT EXISTS comments (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            postId        INTEGER NOT NULL,
            userId        INTEGER NOT NULL,
            comment       TEXT    NOT NULL,
            synced        INTEGER NOT NULL DEFAULT 0,
            dateCommented DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (postId) REFERENCES posts(id) ON DELETE CASCADE,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
          )
        """);
      },
    );

    return _db!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USER CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// INSERT a new user — returns the new row id, or -1 on failure
  Future<int> insertUser({
    required String fullName,
    required String userName,
    required String password,
    String? email,
    String? profilePic,
  }) async {
    final db = await _database();
    final data = {
      'fullName': fullName,
      'userName': userName,
      'password': password,
      if (email != null) 'email': email,
      if (profilePic != null) 'profilePic': profilePic,
    };
    return await db.insert('users', data,
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// READ all users ordered by name
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await _database();
    return await db.query('users', orderBy: 'fullName ASC');
  }

  /// READ a single user by id
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await _database();
    final result =
    await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return result.isNotEmpty ? result.first : null;
  }

  /// UPDATE user info
  Future<int> updateUser({
    required int userId,
    required String fullName,
    required String userName,
    required String password,
    String? email,
    String? profilePic,
  }) async {
    final db = await _database();
    final data = {
      'fullName': fullName,
      'userName': userName,
      'password': password,
      if (email != null) 'email': email,
      if (profilePic != null) 'profilePic': profilePic,
    };
    return await db
        .update('users', data, where: 'id = ?', whereArgs: [userId]);
  }

  /// DELETE a user (also deletes their posts/comments via CASCADE)
  Future<int> deleteUser(int userId) async {
    final db = await _database();
    return await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  /// LOGIN — returns the user row if credentials match, or null
  Future<Map<String, dynamic>?> loginUser(
      String userName, String password) async {
    final db = await _database();
    final result = await db.query(
      'users',
      where: 'userName = ? AND password = ?',
      whereArgs: [userName, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POST CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// INSERT a new post
  Future<int> insertPost({
    required int userId,
    required String title,
    required String description,
    required String postType, // 'Help Request' | 'Skill Offer'
    required String category, // 'Programming' | 'Academic' | 'Design' | 'Others'
    String status = 'Open',
  }) async {
    final db = await _database();
    final data = {
      'userId': userId,
      'title': title,
      'description': description,
      'postType': postType,
      'category': category,
      'status': status,
      'synced': 0,
    };
    return await db.insert('posts', data);
  }

  /// READ all posts (with optional filters), joined with user info
  Future<List<Map<String, dynamic>>> getAllPosts({
    String? postType,
    String? category,
    String? status,
  }) async {
    final db = await _database();

    final conditions = <String>[];
    final args = <dynamic>[];

    if (postType != null) {
      conditions.add('p.postType = ?');
      args.add(postType);
    }
    if (category != null) {
      conditions.add('p.category = ?');
      args.add(category);
    }
    if (status != null) {
      conditions.add('p.status = ?');
      args.add(status);
    }

    final whereClause =
    conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    return await db.rawQuery("""
      SELECT
        p.id,
        p.title,
        p.description,
        p.postType,
        p.category,
        p.status,
        p.synced,
        p.datePosted,
        u.id         AS userId,
        u.fullName   AS userFullName,
        u.userName   AS userUserName,
        u.profilePic AS userProfilePic
      FROM posts p
      JOIN users u ON p.userId = u.id
      $whereClause
      ORDER BY p.datePosted DESC
    """, args);
  }

  /// READ posts by a specific user
  Future<List<Map<String, dynamic>>> getPostsByUser(int userId) async {
    final db = await _database();
    return await db.query(
      'posts',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'datePosted DESC',
    );
  }

  /// SEARCH posts by keyword (title or description)
  Future<List<Map<String, dynamic>>> searchPosts(String keyword) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT
        p.*,
        u.fullName AS userFullName,
        u.userName AS userUserName
      FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.title LIKE ? OR p.description LIKE ?
      ORDER BY p.datePosted DESC
    """, ['%$keyword%', '%$keyword%']);
  }

  /// UPDATE a post
  Future<int> updatePost({
    required int postId,
    required String title,
    required String description,
    required String postType,
    required String category,
    required String status,
  }) async {
    final db = await _database();
    final data = {
      'title': title,
      'description': description,
      'postType': postType,
      'category': category,
      'status': status,
      'synced': 0, // mark as unsynced after edit
    };
    return await db
        .update('posts', data, where: 'id = ?', whereArgs: [postId]);
  }

  /// UPDATE post status only (quick toggle Open ↔ Resolved)
  Future<int> updatePostStatus(int postId, String status) async {
    final db = await _database();
    return await db.update(
      'posts',
      {'status': status, 'synced': 0},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  /// DELETE a post
  Future<int> deletePost(int postId) async {
    final db = await _database();
    return await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMMENT CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// INSERT a comment
  Future<int> insertComment({
    required int postId,
    required int userId,
    required String comment,
  }) async {
    final db = await _database();
    return await db.insert('comments', {
      'postId': postId,
      'userId': userId,
      'comment': comment,
      'synced': 0,
    });
  }

  /// READ all comments for a post, joined with user info
  Future<List<Map<String, dynamic>>> getCommentsByPost(int postId) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT
        c.id,
        c.comment,
        c.synced,
        c.dateCommented,
        u.id       AS userId,
        u.fullName AS userFullName,
        u.userName AS userUserName
      FROM comments c
      JOIN users u ON c.userId = u.id
      WHERE c.postId = ?
      ORDER BY c.dateCommented ASC
    """, [postId]);
  }

  /// UPDATE a comment's text (marks as unsynced)
  Future<int> updateComment({
    required int commentId,
    required String comment,
  }) async {
    final db = await _database();
    return await db.update(
      'comments',
      {'comment': comment, 'synced': 0},
      where: 'id = ?',
      whereArgs: [commentId],
    );
  }

  /// DELETE a comment
  Future<int> deleteComment(int commentId) async {
    final db = await _database();
    return await db
        .delete('comments', where: 'id = ?', whereArgs: [commentId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNC HELPERS  (for Firebase offline support)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all unsynced posts (synced = 0)
  Future<List<Map<String, dynamic>>> getUnsyncedPosts() async {
    final db = await _database();
    return await db.query('posts', where: 'synced = ?', whereArgs: [0]);
  }

  /// Mark a post as synced
  Future<int> markPostSynced(int postId) async {
    final db = await _database();
    return await db.update(
      'posts',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  /// Get all unsynced comments (synced = 0)
  Future<List<Map<String, dynamic>>> getUnsyncedComments() async {
    final db = await _database();
    return await db.query('comments', where: 'synced = ?', whereArgs: [0]);
  }

  /// Mark a comment as synced
  Future<int> markCommentSynced(int commentId) async {
    final db = await _database();
    return await db.update(
      'comments',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [commentId],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DASHBOARD STATS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, int>> getDashboardStats() async {
    final db = await _database();

    final totalPostsResult =
    await db.rawQuery("SELECT COUNT(*) as count FROM posts");

    final helpRequestsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM posts WHERE postType = 'Help Request' AND status = 'Open'");

    final skillOffersResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM posts WHERE postType = 'Skill Offer'");

    final resolvedResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM posts WHERE status = 'Resolved'");

    return {
      "totalPosts":    totalPostsResult.first["count"]  as int,
      "openRequests":  helpRequestsResult.first["count"] as int,
      "skillOffers":   skillOffersResult.first["count"]  as int,
      "resolvedPosts": resolvedResult.first["count"]     as int,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RECENT POSTS
  // ══════════════════════════════════════════════════════════════════════════

  /// GET recent posts — fixed column name (datePosted, not createdAt)
  Future<List<Map<String, dynamic>>> getRecentPosts({int limit = 5}) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT
        p.id,
        p.title,
        p.description,
        p.postType,
        p.category,
        p.status,
        p.synced,
        p.datePosted,
        u.id       AS userId,
        u.fullName AS userFullName,
        u.userName AS userUserName
      FROM posts p
      JOIN users u ON p.userId = u.id
      ORDER BY p.datePosted DESC
      LIMIT ?
    """, [limit]);
  }
}