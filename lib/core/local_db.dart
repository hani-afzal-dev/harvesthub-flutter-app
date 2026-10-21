import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'secure_store.dart';

class LocalDb {
  static const int _version = 4;

  static Database? _database;
  static Future<Database>? _pending;

  static Future<Database> get instance async {
    final existing = _database;
    if (existing != null) return existing;
    return _pending ??= _openAndStore();
  }

  static Future<Database> _openAndStore() async {
    try {
      final db = await _open();
      _database = db;
      return db;
    } finally {
      _pending = null;
    }
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'harvesthub_cache.db');
    final key = await SecureStore.getOrCreateDbKey();

    try {
      return await _openWithKey(path, key);
    } on DatabaseException {
      await deleteDatabase(path);
      return _openWithKey(path, key);
    }
  }

  static Future<Database> _openWithKey(String path, String key) {
    return openDatabase(
      path,
      password: key,
      version: _version,
      onCreate: (db, version) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS products_cache');
        await db.execute('DROP TABLE IF EXISTS orders_cache');
        await _createTables(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE products_cache (
        productId TEXT PRIMARY KEY,
        farmerId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        description TEXT NOT NULL,
        pricePerUnit REAL NOT NULL,
        unit TEXT NOT NULL,
        stockQty INTEGER NOT NULL,
        imageUrl TEXT,
        isAvailable INTEGER NOT NULL,
        cachedAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_products_cache_name ON products_cache (itemName)');
    await db.execute('''
      CREATE TABLE orders_cache (
        orderId TEXT PRIMARY KEY,
        customerId TEXT NOT NULL,
        farmerId TEXT NOT NULL,
        itemsJson TEXT NOT NULL,
        totalPrice REAL NOT NULL,
        promoCode TEXT,
        discount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        pickupSlotId TEXT,
        pickupSlotTime INTEGER,
        deliveryAddr TEXT NOT NULL,
        customerRating INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        cachedAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_orders_cache_customer ON orders_cache (customerId, createdAt)');
  }

  static Future<void> clearAll() async {
    final db = await instance;
    await db.delete('products_cache');
    await db.delete('orders_cache');
  }
}
