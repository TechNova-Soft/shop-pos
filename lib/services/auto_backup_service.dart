import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'backup_service.dart';
import '../database/database_service.dart';

class AutoBackupService {
  AutoBackupService._();

  static final AutoBackupService instance = AutoBackupService._();

  static const Duration backupInterval = Duration(minutes: 2); // TEST ONLY

  static const String _passwordKey = 'auto_backup_password';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    if (_running) {
      return;
    }

    _running = true;

    // First backup immediately when the app starts.
    await _backupNow();

    // Then repeat at the configured interval.
    _timer = Timer.periodic(backupInterval, (_) => _backupNow());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> savePassword(String password) async {
    if (password.length < 8) {
      throw Exception('Backup මුරපදය අවම වශයෙන් අකුරු 8ක් විය යුතුයි.');
    }

    await _secureStorage.write(key: _passwordKey, value: password);
  }

  Future<void> clearPassword() async {
    await _secureStorage.delete(key: _passwordKey);
  }

  Future<bool> hasPassword() async {
    final password = await _secureStorage.read(key: _passwordKey);

    return password != null && password.isNotEmpty;
  }

  Future<void> _backupNow() async {
    try {
      final password = await _secureStorage.read(key: _passwordKey);

      // Auto backup is skipped until the user has
      // configured a backup password.
      if (password == null || password.isEmpty) {
        debugPrint('Auto backup skipped: backup password not configured.');
        return;
      }

      final backupDirectory = await _getAutoBackupDirectory();

      final fileName = BackupService.instance.createAutomaticFileName();

      final destination = File('${backupDirectory.path}\\$fileName');

      final backupBytes = await BackupService.instance
          .createEncryptedBackupBytes(password: password);

      await destination.writeAsBytes(backupBytes, flush: true);

      debugPrint('Auto backup completed: ${destination.path}');
    } catch (error, stackTrace) {
      debugPrint('Auto backup failed: $error');
      debugPrint(stackTrace.toString());
    }
  }

  Future<Directory> _getAutoBackupDirectory() async {
    final databasePath = await DatabaseService.instance.getDatabasePath();

    final databaseDirectory = Directory(File(databasePath).parent.path);

    final backupDirectory = Directory(
      '${databaseDirectory.path}\\auto_backups',
    );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    return backupDirectory;
  }
}
