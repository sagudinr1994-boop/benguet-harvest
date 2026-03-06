import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// LocalDb — manages the SQLite database stored on the phone
// This lets the app show prices even when there's no internet
class LocalDb {
  static Database? _db; // single instance of the database

  // Get the database, creating it if it doesn't exist yet
  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // Create the database file on the device
  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'benguet_harvest.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create the cached_prices table
        await db.execute('''
          CREATE TABLE cached_prices (
            id           TEXT PRIMARY KEY,
            crop_name    TEXT NOT NULL,
            market_name  TEXT NOT NULL,
            price        REAL NOT NULL,
            date_for     TEXT NOT NULL,
            date_updated TEXT,
            cached_at    TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Save a list of prices to the local database
  // Uses INSERT OR REPLACE so duplicates are updated, not doubled
  static Future<void> cachePrices(List<Map<String, dynamic>> rows) async {
    final database = await db;
    final batch = database.batch(); // batch = do many inserts at once
    for (final row in rows) {
      batch.insert('cached_prices', {
        'id': '${row["crop_name"]}_${row["market_name"]}_${row["date_for"]}',
        'crop_name': row['crop_name'],
        'market_name': row['market_name'],
        'price': (row['price_per_kilo'] as num).toDouble(),
        'date_for': row['date_for']?.toString() ?? '',
        'date_updated': row['date_updated']?.toString() ?? '',
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Load all cached prices for a specific date
  static Future<List<Map<String, dynamic>>> loadCached(String date) async {
    final database = await db;
    final rows = await database.query(
      'cached_prices',
      where: 'date_for = ?',
      whereArgs: [date],
      orderBy: 'crop_name ASC',
    );
    // Convert back to the same map format Supabase returns
    return rows
        .map(
          (r) => {
            'crop_name': r['crop_name'],
            'market_name': r['market_name'],
            'price_per_kilo': r['price'],
            'date_for': r['date_for'],
            'date_updated': r['date_updated'],
          },
        )
        .toList();
  }

  // Load price history for one crop+market, up to 7 days back
  static Future<List<Map<String, dynamic>>> loadHistory({
    required String crop,
    required String market,
    int days = 7,
  }) async {
    final database = await db;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return database
        .query(
          'cached_prices',
          where: 'crop_name = ? AND market_name = ? AND date_for >= ?',
          whereArgs: [crop, market, cutoff.toIso8601String().substring(0, 10)],
          orderBy: 'date_for ASC',
        )
        .then(
          (rows) => rows
              .map((r) => {'date_for': r['date_for'], 'price': r['price']})
              .toList(),
        );
  }
}
