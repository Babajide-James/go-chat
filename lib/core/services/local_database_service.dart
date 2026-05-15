import 'dart:convert';
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
      version: 1,
      onCreate: _onCreate,
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
          'data': jsonEncode(convo),
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
          'data': jsonEncode(msg),
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
}
