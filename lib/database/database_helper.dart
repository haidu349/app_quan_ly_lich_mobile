import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quan_ly_lich/models/event.dart';
import 'package:quan_ly_lich/models/event_label.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;
  static const int _dbVersion = 2;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'lich.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createLabelsTable(db);
        await _createEventsTable(db, 'events');
        await db.execute(
          'CREATE INDEX idx_events_start_time ON events(start_time)',
        );
        await _seedDefaultLabels(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateV1ToV2(db);
        }
      },
    );
  }

  // ---------- Tạo bảng ----------

  Future<void> _createLabelsTable(Database db) async {
    await db.execute('''
      CREATE TABLE labels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createEventsTable(Database db, String tableName) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        label_id INTEGER REFERENCES labels(id) ON DELETE SET NULL,
        organizer TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _seedDefaultLabels(Database db) async {
    final defaults = <Map<String, Object?>>[
      {'name': 'Đi học', 'color': 0xFF1E88E5},
      {'name': 'Đi làm', 'color': 0xFF43A047},
      {'name': 'Sự kiện', 'color': 0xFFFB8C00},
    ];
    for (final label in defaults) {
      await db.insert('labels', label);
    }
  }

  // Nâng cấp từ v1 (events: id, name, date, organizer) lên v2
  Future<void> _migrateV1ToV2(Database db) async {
    await _createLabelsTable(db);
    await _seedDefaultLabels(db);
    await _createEventsTable(db, 'events_v2');

    // Sự kiện cũ chỉ có ngày: tạm đặt 08:00 - 09:00, không nhãn
    await db.execute('''
      INSERT INTO events_v2 (id, name, start_time, end_time, organizer)
      SELECT id, name, date + 28800000, date + 32400000, organizer
      FROM events
    ''');

    await db.execute('DROP TABLE events');
    await db.execute('ALTER TABLE events_v2 RENAME TO events');
    await db.execute(
      'CREATE INDEX idx_events_start_time ON events(start_time)',
    );
  }

  // ---------- Nhãn ----------

  Future<List<EventLabel>> getAllLabels() async {
    final db = await database;
    final rows = await db.query('labels', orderBy: 'id ASC');
    return rows.map(EventLabel.fromMap).toList();
  }

  Future<int> insertLabel(EventLabel label) async {
    final db = await database;
    return db.insert('labels', label.toMap()..remove('id'));
  }

  Future<void> updateLabel(EventLabel label) async {
    final db = await database;
    await db.update(
      'labels',
      label.toMap(),
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  // Xóa nhãn: các sự kiện đang dùng nhãn này chuyển thành "không nhãn"
  Future<void> deleteLabel(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'events',
        {'label_id': null},
        where: 'label_id = ?',
        whereArgs: [id],
      );
      await txn.delete('labels', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---------- Sự kiện ----------

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
    final rows = await db.query('events', orderBy: 'start_time ASC');
    return rows.map(Event.fromMap).toList();
  }

  // Xóa các sự kiện đã kết thúc cách đây hơn 1 năm
  Future<int> deleteOlderThanOneYear() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    return db.delete(
      'events',
      where: 'end_time < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
