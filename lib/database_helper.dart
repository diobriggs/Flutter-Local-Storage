import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "CardOrganizer.db";
  static const _databaseVersion = 1;

  // Table names
  static const String folderTable = 'folders';
  static const String cardTable = 'cards';

  // Columns for folders
  static const String folderId = 'id';
  static const String folderName = 'folder_name';

  // Columns for cards
  static const String cardId = 'id';
  static const String cardName = 'name';
  static const String cardSuit = 'suit';
  static const String cardImageUrl = 'image_url';
  static const String foreignFolderId = 'folder_id';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  static final _databaseInitializer = Completer<Database>();

  Future<void> initializeDatabase() async {
    if (_database != null) return;
    
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);
      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
      );
      _databaseInitializer.complete(_database);
    } catch (e) {
      _databaseInitializer.completeError(e);
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    await initializeDatabase();
    return _database!;
  }

  Future _onCreate(Database db, int version) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE $folderTable (
        $folderId INTEGER PRIMARY KEY AUTOINCREMENT,
        $folderName TEXT NOT NULL
      )
    ''');

    // Create cards table
    await db.execute('''
      CREATE TABLE $cardTable (
        $cardId INTEGER PRIMARY KEY AUTOINCREMENT,
        $cardName TEXT NOT NULL,
        $cardSuit TEXT NOT NULL,
        $cardImageUrl TEXT NOT NULL,
        $foreignFolderId INTEGER,
        FOREIGN KEY ($foreignFolderId) REFERENCES $folderTable ($folderId)
      )
    ''');

    await _prepopulateFolders(db);
    await _prepopulateCards(db);
  }

  // Folders CRUD Methods
  Future<int> insertFolder(Map<String, dynamic> folder) async {
    Database db = await instance.database;
    return await db.insert(folderTable, folder);
  }

  Future<List<Map<String, dynamic>>> queryAllFolders() async {
    Database db = await instance.database;
    return await db.query(folderTable);
  }

  Future<Map<String, dynamic>?> queryFolder(int id) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      folderTable,
      where: '$folderId = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateFolder(Map<String, dynamic> folder) async {
    Database db = await instance.database;
    int id = folder[folderId];
    return await db.update(
      folderTable,
      folder,
      where: '$folderId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFolder(int id) async {
    Database db = await instance.database;
    return await db.delete(
      folderTable,
      where: '$folderId = ?',
      whereArgs: [id],
    );
  }

  // Cards CRUD Methods
  Future<int> insertCard(Map<String, dynamic> card) async {
    Database db = await instance.database;
    return await db.insert(cardTable, card);
  }

  Future<List<Map<String, dynamic>>> queryAllCards() async {
    Database db = await instance.database;
    return await db.query(cardTable);
  }

  Future<List<Map<String, dynamic>>> getAvailableCards() async {
    Database db = await instance.database;
    return await db.query(
      cardTable,
      where: '$foreignFolderId IS NULL',
    );
  }

  Future<List<Map<String, dynamic>>> queryCardsByFolder(int folderId) async {
    Database db = await instance.database;
    return await db.query(
      cardTable,
      where: '$foreignFolderId = ?',
      whereArgs: [folderId],
    );
  }

  Future<Map<String, dynamic>?> queryCard(int id) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      cardTable,
      where: '$cardId = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateCard(Map<String, dynamic> card) async {
    Database db = await instance.database;
    int id = card[cardId];
    return await db.update(
      cardTable,
      card,
      where: '$cardId = ?',
      whereArgs: [id],
    );
  }

  Future<int> assignCardToFolder(int cardId, int folderId) async {
    Database db = await instance.database;
    return await db.update(
      cardTable,
      {foreignFolderId: folderId},
      where: '$cardId = ?',
      whereArgs: [cardId],
    );
  }

  Future<int> deleteCard(int id) async {
    Database db = await instance.database;
    return await db.delete(
      cardTable,
      where: '$cardId = ?',
      whereArgs: [id],
    );
  }

  Future<void> _prepopulateCards(Database db) async {
  List<Map<String, int>> suitFolders = [
    {'Hearts': 1},    // Hearts folder has ID 1
    {'Diamonds': 2},  // Diamonds folder has ID 2
    {'Clubs': 3},     // Clubs folder has ID 3
    {'Spades': 4}     // Spades folder has ID 4
  ];
  
  List<String> ranks = ['Ace', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King'];

  for (var suitFolder in suitFolders) {
    String suit = suitFolder.keys.first;
    int folderId = suitFolder.values.first;
    
    for (String rank in ranks) {
      await db.insert(cardTable, {
        cardName: rank,
        cardSuit: suit,
        cardImageUrl: 'assets/cards/${rank.toLowerCase()}_of_${suit.toLowerCase()}.png',
        foreignFolderId: folderId,  // Directly assign the known folder ID
      });
    }
  }
}
  Future<void> _prepopulateFolders(Database db) async {
    List<String> folders = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
    for (String folder in folders) {
      await db.insert(folderTable, {folderName: folder});
    }
  }

  Future<String?> getFirstCardImage(int folderId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      cardTable,
      where: '$foreignFolderId = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first[cardImageUrl] : null;
  }

  Future<int> getCardCount(int folderId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) FROM $cardTable WHERE $foreignFolderId = ?',
      [folderId],
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }
}