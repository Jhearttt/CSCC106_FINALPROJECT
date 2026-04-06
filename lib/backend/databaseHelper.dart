import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _dbName = 'campusaid.db';
  // v1→imageUrl, v2→gamification, v3→skillCards, v4→threads+notifications+commentCount
  static const _dbVersion = 5; // v5 → isAccepted on comments

  // Add this method to DatabaseHelper class
  // Add this method to your DatabaseHelper class
  // In databaseHelper.dart, replace the syncLocalUserToFirestore method with this:

  Future<void> syncLocalUserToFirestore(int localId) async {
    try {
      final user = await getUserById(localId);
      if (user != null) {
        final firestore = FirebaseFirestore.instance;

        // Get email - ensure it's not null
        String email = user['email'] ?? '';
        if (email.isEmpty) {
          email = '${user['userName']}@local.user';
        }

        // Get display name
        String displayName = user['fullName'] ?? user['userName'] ?? 'User';

        // Create document with local_ prefix (primary document)
        await firestore.collection('users').doc('local_$localId').set({
          'displayName': displayName,
          'email': email,
          'userName': user['userName'] ?? '',
          'localId': localId,
          'uid': null,
          'isLocalUser': true,
          'photoUrl': user['profilePic'] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ Synced local user $localId to Firestore with email: $email');
      }
    } catch (e) {
      print('❌ Error syncing local user to Firestore: $e');
    }
  }

  Future<void> updateUserProfilePicture(int userId, String base64Image) async {
    final db = await _database();
    await db.update(
      'users',
      {'profilePic': base64Image},
      where: 'id = ?',
      whereArgs: [userId],
    );
    profilePicVersion.value++;
  }

  static final ValueNotifier<int> profilePicVersion = ValueNotifier(0);

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
            commentCount  INTEGER NOT NULL DEFAULT 0,
            resolvedBy    INTEGER,
            resolvedAt    TEXT,
            synced        INTEGER NOT NULL DEFAULT 0,
            datePosted    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
          )
        """);

        // ── Comments ───────────────────────────────────────────────────────
        // parentCommentId NULL = top-level; non-null = reply to that comment
        await db.execute("""
          CREATE TABLE IF NOT EXISTS comments (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            postId           INTEGER NOT NULL,
            userId           INTEGER NOT NULL,
            comment          TEXT    NOT NULL,
            parentCommentId  INTEGER,
            isAccepted       INTEGER NOT NULL DEFAULT 0,
            synced           INTEGER NOT NULL DEFAULT 0,
            dateCommented    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (postId)          REFERENCES posts(id)    ON DELETE CASCADE,
            FOREIGN KEY (userId)          REFERENCES users(id)    ON DELETE CASCADE,
            FOREIGN KEY (parentCommentId) REFERENCES comments(id) ON DELETE CASCADE
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

        // ── Notifications ──────────────────────────────────────────────────
        // type: 'comment' | 'reply'
        await db.execute("""
          CREATE TABLE IF NOT EXISTS notifications (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            userId       INTEGER NOT NULL,
            fromUserId   INTEGER NOT NULL,
            fromUserName TEXT    NOT NULL,
            postId       INTEGER NOT NULL,
            postTitle    TEXT    NOT NULL,
            commentId    INTEGER,
            type         TEXT    NOT NULL DEFAULT 'comment',
            message      TEXT    NOT NULL,
            isRead       INTEGER NOT NULL DEFAULT 0,
            createdAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
          )
        """);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE posts ADD COLUMN imageUrl TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN points INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN helpCount INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN streak INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE users ADD COLUMN lastHelpDate TEXT');
          await db.execute(
            "ALTER TABLE posts ADD COLUMN urgencyLevel TEXT NOT NULL DEFAULT 'Low'",
          );
          await db.execute(
            'ALTER TABLE posts ADD COLUMN isBoosted INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE posts ADD COLUMN expiryTime TEXT');
          await db.execute("""
            CREATE TABLE IF NOT EXISTS skill_cards (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              userId INTEGER NOT NULL,
              skillCategory TEXT NOT NULL,
              skillPoints INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
              UNIQUE(userId, skillCategory)
            )
          """);
        }
        if (oldVersion < 4) {
          // Posts: comment count + resolver fields
          await db.execute(
            'ALTER TABLE posts ADD COLUMN commentCount INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE posts ADD COLUMN resolvedBy INTEGER');
          await db.execute('ALTER TABLE posts ADD COLUMN resolvedAt TEXT');
          // Comments: thread support
          await db.execute(
            'ALTER TABLE comments ADD COLUMN parentCommentId INTEGER',
          );
          // Notifications table
          await db.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              userId       INTEGER NOT NULL,
              fromUserId   INTEGER NOT NULL,
              fromUserName TEXT    NOT NULL,
              postId       INTEGER NOT NULL,
              postTitle    TEXT    NOT NULL,
              commentId    INTEGER,
              type         TEXT    NOT NULL DEFAULT 'comment',
              message      TEXT    NOT NULL,
              isRead       INTEGER NOT NULL DEFAULT 0,
              createdAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
            )
          """);
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE comments ADD COLUMN isAccepted INTEGER NOT NULL DEFAULT 0',
          );
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
      'fullName': fullName,
      'userName': userName,
      'password': password,
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
    required int userId,
    required String fullName,
    required String userName,
    required String password,
    String? email,
    String? profilePic,
  }) async {
    final db = await _database();
    return await db.update(
      'users',
      {
        'fullName': fullName,
        'userName': userName,
        'password': password,
        if (email != null) 'email': email,
        if (profilePic != null) 'profilePic': profilePic,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> deleteUser(int userId) async {
    final db = await _database();
    return await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<Map<String, dynamic>?> loginUser(
    String userName,
    String password,
  ) async {
    final db = await _database();
    final r = await db.query(
      'users',
      where: 'userName = ? AND password = ?',
      whereArgs: [userName, password],
    );
    return r.isNotEmpty ? r.first : null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REPUTATION & GAMIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addPoints(int userId, int points, String category) async {
    final db = await _database();
    final user = await getUserById(userId);
    if (user == null) return;

    final today = DateTime.now();
    final lastHelpStr = user['lastHelpDate'] as String?;
    int newStreak = (user['streak'] as int? ?? 0);

    if (lastHelpStr != null) {
      final last = DateTime.tryParse(lastHelpStr);
      if (last != null) {
        final diff = today.difference(last).inDays;
        if (diff == 1)
          newStreak += 1;
        else if (diff > 1)
          newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    await db.rawUpdate(
      """
      UPDATE users SET points = points + ?, helpCount = helpCount + 1,
        streak = ?, lastHelpDate = ? WHERE id = ?
    """,
      [points, newStreak, today.toIso8601String(), userId],
    );

    await db.rawInsert(
      """
      INSERT INTO skill_cards (userId, skillCategory, skillPoints) VALUES (?, ?, ?)
      ON CONFLICT(userId, skillCategory) DO UPDATE SET skillPoints = skillPoints + ?
    """,
      [userId, category, points, points],
    );
  }

  Future<List<Map<String, dynamic>>> getTopHelpers() async {
    final db = await _database();
    return await db.query(
      'users',
      columns: [
        'id',
        'fullName',
        'userName',
        'points',
        'helpCount',
        'streak',
        'profilePic',
      ],
      orderBy: 'points DESC',
      limit: 10,
    );
  }

  Future<List<Map<String, dynamic>>> getSkillCards(int userId) async {
    final db = await _database();
    return await db.query(
      'skill_cards',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'skillPoints DESC',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POST CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> insertPost({
    required int userId,
    required String title,
    required String description,
    required String postType,
    required String category,
    String status = 'Open',
    String urgencyLevel = 'Low',
    String? imageUrl,
  }) async {
    final db = await _database();
    final expiry = DateTime.now()
        .add(const Duration(hours: 48))
        .toIso8601String();
    return await db.insert('posts', {
      'userId': userId,
      'title': title,
      'description': description,
      'postType': postType,
      'category': category,
      'status': status,
      'urgencyLevel': urgencyLevel,
      'isBoosted': 0,
      'expiryTime': expiry,
      'commentCount': 0,
      'synced': 0,
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

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
    final whereClause = conditions.isNotEmpty
        ? 'WHERE ${conditions.join(' AND ')}'
        : '';
    return await db.rawQuery("""
      SELECT
        p.id, p.title, p.description, p.postType, p.category,
        p.status, p.urgencyLevel, p.isBoosted, p.expiryTime,
        p.imageUrl, p.synced, p.datePosted, p.commentCount,
        p.resolvedBy, p.resolvedAt,
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
    return await db.rawQuery(
      """
      SELECT
        p.id, p.title, p.description, p.postType, p.category,
        p.status, p.urgencyLevel, p.isBoosted, p.expiryTime,
        p.imageUrl, p.synced, p.datePosted, p.commentCount,
        p.resolvedBy, p.resolvedAt,
        u.id         AS userId,
        u.fullName   AS userFullName,
        u.userName   AS userUserName,
        u.profilePic AS userProfilePic,
        u.points     AS userPoints
      FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.userId = ?
      ORDER BY p.datePosted DESC
    """,
      [userId],
    );
  }

  Future<List<Map<String, dynamic>>> searchPosts(String keyword) async {
    final db = await _database();
    return await db.rawQuery(
      """
      SELECT p.*, u.fullName AS userFullName, u.userName AS userUserName
      FROM posts p JOIN users u ON p.userId = u.id
      WHERE p.title LIKE ? OR p.description LIKE ?
      ORDER BY p.isBoosted DESC, p.datePosted DESC
    """,
      ['%$keyword%', '%$keyword%'],
    );
  }

  Future<int> updatePost({
    required int postId,
    required String title,
    required String description,
    required String postType,
    required String category,
    required String status,
    String urgencyLevel = 'Low',
    String? imageUrl,
  }) async {
    final db = await _database();
    return await db.update(
      'posts',
      {
        'title': title,
        'description': description,
        'postType': postType,
        'category': category,
        'status': status,
        'urgencyLevel': urgencyLevel,
        'synced': 0,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  Future<int> updatePostStatus(
    int postId,
    String status, {
    int? resolvedBy,
    String? resolvedAt,
  }) async {
    final db = await _database();
    final data = <String, dynamic>{
      'status': status,
      'synced': 0,
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
    };
    return await db.update('posts', data, where: 'id = ?', whereArgs: [postId]);
  }

  Future<int> deletePost(int postId) async {
    final db = await _database();
    return await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  }

  // ── Comment count helpers ─────────────────────────────────────────────────

  Future<void> _incrementCommentCount(Database db, int postId) async {
    await db.rawUpdate(
      'UPDATE posts SET commentCount = commentCount + 1 WHERE id = ?',
      [postId],
    );
  }

  Future<void> _decrementCommentCount(Database db, int postId) async {
    await db.rawUpdate(
      'UPDATE posts SET commentCount = MAX(0, commentCount - 1) WHERE id = ?',
      [postId],
    );
  }

  /// Recalculates commentCount for every post from actual comment rows.
  /// Call once on feed load to fix counts for comments that existed
  /// before the commentCount column was added (DB v3 → v4 upgrade).
  Future<void> syncCommentCounts() async {
    final db = await _database();
    await db.rawUpdate("""
      UPDATE posts
      SET commentCount = (
        SELECT COUNT(*) FROM comments WHERE comments.postId = posts.id
      )
    """);
  }

  Future<int> getCommentCount(int postId) async {
    final db = await _database();
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM comments WHERE postId = ?',
      [postId],
    );
    return (r.first['c'] as int? ?? 0);
  }

  // ── Boost helpers ─────────────────────────────────────────────────────────

  Future<void> checkAndBoostExpiredPosts() async {
    final db = await _database();
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      """
      UPDATE posts SET isBoosted = 1
      WHERE status = 'Open' AND isBoosted = 0
        AND expiryTime IS NOT NULL AND expiryTime <= ?
    """,
      [now],
    );
  }

  Future<List<Map<String, dynamic>>> getBoostedPosts() async {
    final db = await _database();
    return await db.rawQuery("""
      SELECT p.*, u.fullName AS userFullName FROM posts p
      JOIN users u ON p.userId = u.id
      WHERE p.isBoosted = 1 AND p.status = 'Open' ORDER BY p.datePosted ASC
    """);
  }

  // ── Smart Match ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSuggestedHelpers(
    String category,
  ) async {
    final db = await _database();
    return await db.rawQuery(
      """
      SELECT DISTINCT u.id, u.fullName, u.userName, u.points,
        u.helpCount, u.profilePic, p.title AS skillTitle
      FROM posts p JOIN users u ON p.userId = u.id
      WHERE p.postType = 'Skill Offer' AND p.category = ? AND p.status = 'Open'
      ORDER BY u.points DESC LIMIT 5
    """,
      [category],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMMENT CRUD  (threaded)
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a top-level comment (parentCommentId = null) or a reply.
  /// Automatically increments the post's commentCount.
  Future<int> insertComment({
    required int postId,
    required int userId,
    required String comment,
    int? parentCommentId,
  }) async {
    final db = await _database();
    final id = await db.insert('comments', {
      'postId': postId,
      'userId': userId,
      'comment': comment,
      'synced': 0,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
    });
    if (id > 0) await _incrementCommentCount(db, postId);
    return id;
  }

  /// Returns all top-level comments for a post, each with a 'replies' key
  /// containing the list of child comments sorted oldest-first.
  Future<List<Map<String, dynamic>>> getCommentsByPost(int postId) async {
    final db = await _database();

    // All comments flat, joined with user info
    final flat = await db.rawQuery(
      """
      SELECT c.id, c.comment, c.synced, c.dateCommented,
             c.parentCommentId, c.isAccepted,
             u.id       AS userId,
             u.fullName AS userFullName,
             u.userName AS userUserName,
             u.points   AS userPoints,
             u.profilePic AS userProfilePic
      FROM comments c
      JOIN users u ON c.userId = u.id
      WHERE c.postId = ?
      ORDER BY c.dateCommented ASC
    """,
      [postId],
    );

    // Build thread: separate top-level and replies
    final topLevel = <Map<String, dynamic>>[];
    final replies = <int, List<Map<String, dynamic>>>{};

    for (final row in flat) {
      final parent = row['parentCommentId'] as int?;
      if (parent == null) {
        topLevel.add(
          Map<String, dynamic>.from(row)
            ..['replies'] = <Map<String, dynamic>>[],
        );
      } else {
        replies
            .putIfAbsent(parent, () => [])
            .add(Map<String, dynamic>.from(row));
      }
    }

    // Attach replies to their parents
    for (final c in topLevel) {
      c['replies'] = replies[c['id'] as int] ?? [];
    }

    return topLevel;
  }

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

  /// Deletes a comment and decrements the post's commentCount.
  Future<int> deleteComment(int commentId) async {
    final db = await _database();
    // Find the postId before deleting so we can decrement
    final rows = await db.query(
      'comments',
      columns: ['postId'],
      where: 'id = ?',
      whereArgs: [commentId],
    );
    final result = await db.delete(
      'comments',
      where: 'id = ?',
      whereArgs: [commentId],
    );
    if (result > 0 && rows.isNotEmpty) {
      final postId = rows.first['postId'] as int;
      await _decrementCommentCount(db, postId);
    }
    return result;
  }

  // ── Accept Solution ───────────────────────────────────────────────────────

  /// Marks a comment as the accepted solution (StackOverflow-style).
  ///
  /// Rules enforced:
  ///   1. Only the post owner can accept (enforced in UI + here).
  ///   2. Only ONE accepted solution per post.
  ///   3. Helper cannot accept their own comment.
  ///
  /// On success:
  ///   - comment.isAccepted = 1
  ///   - post.status = 'Resolved' + resolvedBy/resolvedAt set
  ///   - helper gets +20 points, helpCount++, streak updated
  ///   - helper's skill card for post category updated
  ///
  /// Returns true on success, false if a rule blocks it.
  Future<bool> acceptSolution({
    required int commentId,
    required int postId,
    required int helperId,
    required int postOwnerId,
    required String category,
  }) async {
    final db = await _database();

    // Rule 3 — cannot accept your own comment
    if (helperId == postOwnerId) return false;

    // Rule 2 — only one accepted solution per post
    final already = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM comments WHERE postId = ? AND isAccepted = 1',
      [postId],
    );
    if ((already.first['c'] as int? ?? 0) > 0) return false;

    // Mark comment accepted
    await db.update(
      'comments',
      {'isAccepted': 1},
      where: 'id = ?',
      whereArgs: [commentId],
    );

    // Resolve the post and record who resolved it
    final now = DateTime.now().toIso8601String();
    await db.update(
      'posts',
      {
        'status': 'Resolved',
        'resolvedBy': helperId,
        'resolvedAt': now,
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [postId],
    );

    // Award +20 points, update streak, update skill card
    await addPoints(helperId, 20, category);

    return true;
  }
  // ══════════════════════════════════════════════════════════════════════════

  /// Insert a notification for the post owner when someone comments.
  Future<int> insertNotification({
    required int userId, // recipient (post owner)
    required int fromUserId,
    required String fromUserName,
    required int postId,
    required String postTitle,
    required String type, // 'comment' | 'reply'
    required String message,
    int? commentId,
  }) async {
    final db = await _database();
    return await db.insert('notifications', {
      'userId': userId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'postId': postId,
      'postTitle': postTitle,
      'type': type,
      'message': message,
      'isRead': 0,
      if (commentId != null) 'commentId': commentId,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final db = await _database();
    return await db.query(
      'notifications',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
      limit: 50,
    );
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    final db = await _database();
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notifications WHERE userId = ? AND isRead = 0',
      [userId],
    );
    return (r.first['c'] as int? ?? 0);
  }

  Future<void> markNotificationRead(int notificationId) async {
    final db = await _database();
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsRead(int userId) async {
    final db = await _database();
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    final db = await _database();
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    );
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
    return await db.update(
      'posts',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedComments() async {
    final db = await _database();
    return await db.query('comments', where: 'synced = ?', whereArgs: [0]);
  }

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
    final r1 = await db.rawQuery("SELECT COUNT(*) AS c FROM posts");
    final r2 = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM posts WHERE postType='Help Request' AND status='Open'",
    );
    final r3 = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM posts WHERE postType='Skill Offer'",
    );
    final r4 = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM posts WHERE status='Resolved'",
    );
    return {
      "totalPosts": r1.first["c"] as int,
      "openRequests": r2.first["c"] as int,
      "skillOffers": r3.first["c"] as int,
      "resolvedPosts": r4.first["c"] as int,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentPosts({int limit = 5}) async {
    final db = await _database();
    return await db.rawQuery(
      """
      SELECT p.id, p.title, p.description, p.postType, p.category,
             p.status, p.urgencyLevel, p.isBoosted, p.imageUrl,
             p.synced, p.datePosted, p.commentCount,
             u.id AS userId, u.fullName AS userFullName,
             u.userName AS userUserName
      FROM posts p JOIN users u ON p.userId = u.id
      ORDER BY p.isBoosted DESC, p.datePosted DESC LIMIT ?
    """,
      [limit],
    );
  }
}
