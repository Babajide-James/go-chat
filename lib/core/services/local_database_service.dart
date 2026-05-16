import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'go_chat.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await _createUploadQueueTable(db);
    await _createUsersTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUploadQueueTable(db);
    }
    if (oldVersion < 3) {
      await _createUsersTable(db);
    }
  }

  Future<void> _createUploadQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS upload_queue (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL,
        firestoreMessageId TEXT NOT NULL,
        localFilePath TEXT NOT NULL,
        mediaType TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retries INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
  }

  // --- Users ---

  Future<void> cacheUser(String uid, Map<String, dynamic> userData) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'id': uid,
        'data': jsonEncode(userData, toEncodable: (item) {
          if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedUser(String uid) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    }
    return null;
  }

  // --- Conversations ---

  Future<void> cacheConversations(List<Map<String, dynamic>> conversations) async {
    final db = await database;
    Batch batch = db.batch();
    
    for (var convo in conversations) {
      batch.insert(
        'conversations',
        {
          'id': convo['id'],
          'data': jsonEncode(convo, toEncodable: (item) {
            if (item is Timestamp) {
              return item.toDate().toIso8601String();
            }
            return item;
          }),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'updatedAt DESC',
    );
    
    return maps.map((map) {
      return jsonDecode(map['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // --- Messages ---
  
  Future<void> cacheMessages(String conversationId, List<Map<String, dynamic>> messages) async {
    final db = await database;
    Batch batch = db.batch();
    
    for (var msg in messages) {
      batch.insert(
        'messages',
        {
          'id': msg['id'] ?? msg['createdAt'].toString(),
          'conversationId': conversationId,
          'data': jsonEncode(msg, toEncodable: (item) {
            if (item is Timestamp) {
              return item.toDate().toIso8601String();
            }
            return item;
          }),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt DESC',
    );
    
    return maps.map((map) {
      return jsonDecode(map['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  // --- Upload Queue ---

  Future<void> insertQueueItem({
    required String id,
    required String conversationId,
    required String firestoreMessageId,
    required String localFilePath,
    required String mediaType,
  }) async {
    final db = await database;
    await db.insert(
      'upload_queue',
      {
        'id': id,
        'conversationId': conversationId,
        'firestoreMessageId': firestoreMessageId,
        'localFilePath': localFilePath,
        'mediaType': mediaType,
        'status': 'pending',
        'retries': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQueueItems({String? status}) async {
    final db = await database;
    if (status != null) {
      return db.query(
        'upload_queue',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'createdAt ASC',
      );
    }
    return db.query('upload_queue', orderBy: 'createdAt ASC');
  }

  Future<void> updateQueueItemStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'upload_queue',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementQueueItemRetries(String id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE upload_queue SET retries = retries + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> deleteQueueItem(String id) async {
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getQueueItemByFirestoreId(
    String firestoreMessageId,
  ) async {
    final db = await database;
    final results = await db.query(
      'upload_queue',
      where: 'firestoreMessageId = ?',
      whereArgs: [firestoreMessageId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
}
