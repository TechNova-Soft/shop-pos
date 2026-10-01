import 'package:bcrypt/bcrypt.dart';

import '../database/database_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<bool> hasUsers() async {
    final db = await DatabaseService.instance.database;

    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM users');

    final count = (result.first['count'] as int?) ?? 0;
    return count > 0;
  }

  Future<void> createOwner({
    required String username,
    required String password,
    required String displayName,
  }) async {
    final db = await DatabaseService.instance.database;

    final cleanUsername = username.trim();
    final cleanDisplayName = displayName.trim();

    if (cleanUsername.isEmpty || cleanDisplayName.isEmpty || password.isEmpty) {
      throw Exception('අවශ්‍ය සියලු තොරතුරු ඇතුළත් කරන්න.');
    }

    final existingUser = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [cleanUsername],
      limit: 1,
    );

    if (existingUser.isNotEmpty) {
      throw Exception('මෙම පරිශීලක නම දැනටමත් භාවිතා වේ.');
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    final now = DateTime.now().toIso8601String();

    await db.insert('users', {
      'username': cleanUsername,
      'password_hash': passwordHash,
      'display_name': cleanDisplayName,
      'role': 'owner',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    final db = await DatabaseService.instance.database;

    final result = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    final user = result.first;

    final storedHash = user['password_hash'] as String;

    final validPassword = BCrypt.checkpw(password, storedHash);

    if (!validPassword) {
      return null;
    }

    return user;
  }
}
