import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _dbName    = 'campusaid.db';
  static const _dbVersion = 4; // v4 → added resolvedByUserId, resolvedCommentId, resolvedDate

  Database? _db;

  Future<Database> getDatabase() => _database();

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final path = await getDatabasesPath();
    _db = await openDatabase(
      '$path/$_dbName',
      version: _dbVersion,
      onCreate: (db, version) async {
        // ── Users ──────────────────────────────────────────────────────────
        await db.execute("""
          CREATE TABLE IF NOT EXISTS users (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName      TEXT    NOT NULL,
            userName      TEXT    NOT NULL UNIQUE,
            password      TEXT    NOT NULL,
            email         TEXT,
            profilePic    TEXT,
            points        INTEGER NOT NULL DEFAULT 0,
            helpCount     INTEGER NOT NULL DEFAULT 0,
            streak        INTEGER NOT NULL DEFAULT 0,
            lastHelpDate  TEXT,
            dateAdded     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        """);

        // ── Posts ──────────────────────────────────────────────────────────
        await db.execute("""
          CREATE TABLE IF NOT EXISTS posts (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            userId        INTEGER NOT NULL,
            title         TEXT    NOT NULL,
            description   TEXT    NOT NULL,
            postType      TEXT    NOT NULL DEFAULT 'Help Request',
            category      TEXT    NOT NULL DEFAULT 'Others',
            status        TEXT    NOT NULL DEFAULT 'Open',
            urgencyLevel  TEXT    NOT NULL DEFAULT 'Low',
            isBoosted     INTEGER NOT NULL DEFAULT 0,
            expiryTime    TEXT,
            imageUrl      TEXT,
            resolvedByUserId INTEGER,
            resolvedCommentId INTEGER,
            resolvedDate  TEXT,
            synced        INTEGER NOT NULL DEFAULT 0,
            datePosted    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
          )
        """);

        // ── Comments ───────────────────────────────────────────────────────
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

        // ── Skill Cards ────────────────────────────────────────────────────
        await db.execute("""
          CREATE TABLE IF NOT EXISTS skill_cards (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            userId        INTEGER NOT NULL,
            skillCategory TEXT    NOT NULL,
            skillPoints   INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(userId, skillCategory)
          )
        """);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE posts ADD COLUMN imageUrl TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN points INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE users ADD COLUMN helpCount INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE users ADD COLUMN streak INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE users ADD COLUMN lastHelpDate TEXT');
          await db.execute("ALTER TABLE posts ADD COLUMN urgencyLevel TEXT NOT NULL DEFAULT 'Low'");
          await db.execute('ALTER TABLE posts ADD COLUMN isBoosted INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE posts ADD COLUMN expiryTime TEXT');
          await db.execute("""
            CREATE TABLE IF NOT EXISTS skill_cards (
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              userId        INTEGER NOT NULL,
              skillCategory TEXT    NOT NULL,
              skillPoints   INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
              UNIQUE(userId, skillCategory)
            )
          """);
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE posts ADD COLUMN resolvedByUserId INTEGER");
          await db.execute("ALTER TABLE posts ADD COLUMN resolvedCommentId INTEGER");
          await db.execute("ALTER TABLE posts ADD COLUMN resolvedDate TEXT");
        }
      },
    );
    return _db!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USER CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertUser({
    required String fullName,
    required String userName,
    required String password,
    String? email,
    String? profilePic,
  }) async {
    final db = await _database();
    return await db.insert('users', {
      'fullName': fullName, 'userName': userName, 'password': password,
      if (email != null) 'email': email,
      if (profilePic != null) 'profilePic': profilePic,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await _database();
    return await db.query('users', orderBy: 'fullName ASC');
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final db = await _database();
    final r = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateUser({
    required int userId, required String fullName,
    required String userName, required String password,
    String? email, String? profilePic,
  }) async {
    final db = await _database();
    return await db.update('users', {
      'fullName': fullName, 'userName': userName, 'password': password,
      if (email != null) 'email': email,
      if (profilePic != null) 'profilePic': profilePic,
    }, where: 'id = ?', whereArgs: [userId]);
  }

  Future<int> deleteUser(int userId) async {
    final db = await _database();
    return await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<Map<String, dynamic>?> loginUser(String userName, String password) async {
    final db = await _database();
    final r = await db.query('users',
        where: 'userName = ? AND password = ?',
        whereArgs: [userName, password]);
    return r.isNotEmpty ? r.first : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REPUTATION & GAMIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addPoints(int userId, int points, String category) async {
    final db   = await _database();
    final user = await getUserById(userId);
    if (user == null) return;

    final today        = DateTime.now();
    final lastHelpStr  = user['lastHelpDate'] as String?;
    int   newStreak    = (user['streak'] as int? ?? 0);

    if (lastHelpStr != null) {
      final last = DateTime.tryParse(lastHelpStr);
      if (last != null) {
        final diff = today.difference(last).inDays;
        if (diff == 1)      newStreak += 1;
        else if (diff > 1)  newStreak  = 1;
      }
    } else {
      newStreak = 1;
    }

    await db.rawUpdate("""
      UPDATE users
      SET points       = points + ?,
          helpCount    = helpCount + 1,
          streak       = ?,
          lastHelpDate = ?
      WHERE id = ?
    """, [points, newStreak, today.toIso8601String(), userId]);

    await db.rawInsert("""
      INSERT INTO skill_cards (userId, skillCategory, skillPoints)
      VALUES (?, ?, ?)
      ON CONFLICT(userId, skillCategory)
      DO UPDATE SET skillPoints = skillPoints + ?
    """, [userId, category, points, points]);
  }

  Future<List<Map<String, dynamic>>> getTopHelpers() async {
    final db = await _database();
    return await db.query('users',
        columns: ['id', 'fullName', 'userName', 'points', 'helpCount',
          'streak', 'profilePic'],
        orderBy: 'points DESC',
        limit: 10);
  }

  Future<List<Map<String, dynamic>>> getSkillCards(int userId) async {
    final db = await _database();
    return await db.query('skill_cards',
        where: 'userId = ?', whereArgs: [userId],
        orderBy: 'skillPoints DESC');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POST CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertPost({
    required int    userId,
    required String title,
    required String description,
    required String postType,
    required String category,
    String  status       = 'Open',
    String  urgencyLevel = 'Low',
    String? imageUrl,
  }) async {
    final db = await _database();
    final expiry = DateTime.now().add(const Duration(hours: 48)).toIso8601String();
    return await db.insert('posts', {
      'userId': userId, 'title': title, 'description': description,
      'postType': postType, 'category': category, 'status': status,
      'urgencyLevel': urgencyLevel, 'isBoosted': 0,
      'expiryTime': expiry, 'synced': 0,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  Future<List<Map<String, dynamic>>> getAllPosts({
    String? postType, String? category, String? status,
  }) async {
    final db         = await _database();
    final conditions = <String>[];
    final args       = <dynamic>[];

    if (postType != null) { conditions.add('p.postType = ?'); args.add(postType); }
    if (category != null) { conditions.add('p.category = ?'); args.add(category); }
    if (status   != null) { conditions.add('p.status = ?');   args.add(status);   }

    final whereClause =
    conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    return await db.rawQuery("""
      SELECT
        p.id, p.title, p.description, p.postType, p.category,
        p.status, p.urgencyLevel, p.isBoosted, p.expiryTime,
        p.imageUrl, p.synced, p.datePosted,
        u.id         AS userId,
        u.fullName   AS userFullName,
        u.userName   AS userUserName,
        u.profilePic AS userProfilePic,
        u.points     AS userPoints
      FROM posts p
      JOIN users u ON p.userId = u.id
      $whereClause
      ORDER BY p.isBoosted DESC, p.datePosted DESC
    """, args);
  }

  Future<List<Map<String, dynamic>>> getPostsByUser(int userId) async {
    final db = await _database();
    return await db.query('posts',
        where: 'userId = ?', whereArgs: [userId],
        orderBy: 'datePosted DESC');
  }

  Future<List<Map<String, dynamic>>> searchPosts(String keyword) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT p.*, u.fullName AS userFullName, u.userName AS userUserName
      FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.title LIKE ? OR p.description LIKE ?
      ORDER BY p.isBoosted DESC, p.datePosted DESC
    """, ['%$keyword%', '%$keyword%']);
  }

  Future<int> updatePost({
    required int    postId,
    required String title,
    required String description,
    required String postType,
    required String category,
    required String status,
    String  urgencyLevel = 'Low',
    String? imageUrl,
  }) async {
    final db = await _database();
    return await db.update('posts', {
      'title': title, 'description': description,
      'postType': postType, 'category': category, 'status': status,
      'urgencyLevel': urgencyLevel, 'synced': 0,
      if (imageUrl != null) 'imageUrl': imageUrl,
    }, where: 'id = ?', whereArgs: [postId]);
  }

  Future<int> updatePostStatus(int postId, String status) async {
    final db = await _database();
    return await db.update('posts',
        {'status': status, 'synced': 0},
        where: 'id = ?', whereArgs: [postId]);
  }

  Future<int> deletePost(int postId) async {
    final db = await _database();
    return await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  }

  // ── Boost helpers ─────────────────────────────────────────────────────────

  Future<void> checkAndBoostExpiredPosts() async {
    final db  = await _database();
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate("""
      UPDATE posts
      SET isBoosted = 1
      WHERE status = 'Open'
        AND isBoosted = 0
        AND expiryTime IS NOT NULL
        AND expiryTime <= ?
    """, [now]);
  }

  Future<List<Map<String, dynamic>>> getBoostedPosts() async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT p.*, u.fullName AS userFullName
      FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.isBoosted = 1 AND p.status = 'Open'
      ORDER BY p.datePosted ASC
    """);
  }

  // ── Smart Match ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSuggestedHelpers(String category) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT DISTINCT
        u.id, u.fullName, u.userName, u.points, u.helpCount, u.profilePic,
        p.title AS skillTitle
      FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.postType = 'Skill Offer'
        AND p.category = ?
        AND p.status   = 'Open'
      ORDER BY u.points DESC
      LIMIT 5
    """, [category]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMMENT CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertComment({
    required int postId, required int userId, required String comment,
  }) async {
    final db = await _database();
    return await db.insert('comments', {
      'postId': postId, 'userId': userId, 'comment': comment, 'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getCommentsByPost(int postId) async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT c.id, c.comment, c.synced, c.dateCommented,
             u.id AS userId, u.fullName AS userFullName,
             u.userName AS userUserName, u.points AS userPoints
      FROM comments c
      JOIN users u ON c.userId = u.id
      WHERE c.postId = ?
      ORDER BY c.dateCommented ASC
    """, [postId]);
  }

  Future<int> updateComment({required int commentId, required String comment}) async {
    final db = await _database();
    return await db.update('comments', {'comment': comment, 'synced': 0},
        where: 'id = ?', whereArgs: [commentId]);
  }

  Future<int> deleteComment(int commentId) async {
    final db = await _database();
    return await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SYNC HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getUnsyncedPosts() async {
    final db = await _database();
    return await db.query('posts', where: 'synced = ?', whereArgs: [0]);
  }

  Future<int> markPostSynced(int postId) async {
    final db = await _database();
    return await db.update('posts', {'synced': 1},
        where: 'id = ?', whereArgs: [postId]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedComments() async {
    final db = await _database();
    return await db.query('comments', where: 'synced = ?', whereArgs: [0]);
  }

  Future<int> markCommentSynced(int commentId) async {
    final db = await _database();
    return await db.update('comments', {'synced': 1},
        where: 'id = ?', whereArgs: [commentId]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DASHBOARD STATS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, int>> getDashboardStats() async {
    final db = await _database();
    final r1 = await db.rawQuery("SELECT COUNT(*) as c FROM posts");
    final r2 = await db.rawQuery(
        "SELECT COUNT(*) as c FROM posts WHERE postType='Help Request' AND status='Open'");
    final r3 = await db.rawQuery(
        "SELECT COUNT(*) as c FROM posts WHERE postType='Skill Offer'");
    final r4 = await db.rawQuery(
        "SELECT COUNT(*) as c FROM posts WHERE status='Resolved'");
    return {
      "totalPosts":    r1.first["c"] as int,
      "openRequests":  r2.first["c"] as int,
      "skillOffers":   r3.first["c"] as int,
      "resolvedPosts": r4.first["c"] as int,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MARK POST AS RESOLVED (NEW)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> markPostResolved({
    required int postId,
    required int helperUserId,
    required int commentId,
    required String category,
  }) async {
    final db = await _database();

    await db.transaction((txn) async {
      await txn.update(
        'posts',
        {
          'status': 'Resolved',
          'resolvedByUserId': helperUserId,
          'resolvedCommentId': commentId,
          'resolvedDate': DateTime.now().toIso8601String(),
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [postId],
      );

      // reward helper
      await addPoints(helperUserId, 10, category);
    });
  }

  Future<Map<String, dynamic>?> getResolvedInfo(int postId) async {
    final db = await _database();

    final r = await db.rawQuery("""
      SELECT p.resolvedDate,
             u.fullName AS helperName,
             u.userName AS helperUsername,
             c.comment AS solution
      FROM posts p
      LEFT JOIN users u ON p.resolvedByUserId = u.id
      LEFT JOIN comments c ON p.resolvedCommentId = c.id
      WHERE p.id = ?
    """, [postId]);

    return r.isNotEmpty ? r.first : null;
  }

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
        p.photos,
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