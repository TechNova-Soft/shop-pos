import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_ffi/sqflite_ffi.dart';

import 'database_schema.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final appSupportDirectory = await getApplicationSupportDirectory();

    final databaseDirectory = Directory(
      p.join(appSupportDirectory.path, 'technova_shop_pos'),
    );

    if (!await databaseDirectory.exists()) {
      await databaseDirectory.create(recursive: true);
    }

    final databasePath = p.join(databaseDirectory.path, 'shop_pos.db');

    return databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await DatabaseSchema.create(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await DatabaseSchema.upgradeToV2(db);
          }
        },
      ),
    );
  }
}
