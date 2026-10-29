import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quan_ly_lich/models/event.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'lich.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            date INTEGER NOT NULL,
            organizer TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertEvent(Event event) async {
    final db = await database;
    await db.insert('events', event.toMap()..remove('id'));
  }

  Future<void> updateEvent(Event event) async {
    final db = await database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final rows = await db.query('events', orderBy: 'date ASC');
    return rows.map(Event.fromMap).toList();
  }

  // Xóa các sự kiện cũ hơn 1 năm
  Future<int> deleteOlderThanOneYear() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    return db.delete(
      'events',
      where: 'date < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
