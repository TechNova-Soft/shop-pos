import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import '../database/database_service.dart';
import 'backup_service.dart';
import 'google_drive_service.dart';

class AutoBackupService {
  AutoBackupService._();

  static final AutoBackupService instance = AutoBackupService._();

  // TEST ONLY
  // Production: Duration(hours: 5)
  static const Duration backupInterval = Duration(minutes: 2);

  static const String _passwordKey = 'auto_backup_password';

  final FlutterSecureStorage _secureStorage =
  const FlutterSecureStorage();

  Timer? _timer;
  bool _running = false;

  // ---------------------------------------------------------------------------
  // START
  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_running) {
      return;
    }

    _running = true;

    // First backup immediately when app starts.
    await _backupNow();

    // Then repeat according to backup interval.
    _timer = Timer.periodic(
      backupInterval,
          (_) async {
        await _backupNow();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STOP
  // ---------------------------------------------------------------------------

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  // ---------------------------------------------------------------------------
  // SAVE BACKUP PASSWORD
  // ---------------------------------------------------------------------------

  Future<void> savePassword(String password) async {
    if (password.length < 8) {
      throw Exception(
        'Backup මුරපදය අවම වශයෙන් අකුරු 8ක් විය යුතුයි.',
      );
    }

    await _secureStorage.write(
      key: _passwordKey,
      value: password,
    );
  }

  // ---------------------------------------------------------------------------
  // CLEAR BACKUP PASSWORD
  // ---------------------------------------------------------------------------

  Future<void> clearPassword() async {
    await _secureStorage.delete(
      key: _passwordKey,
    );
  }

  // ---------------------------------------------------------------------------
  // CHECK BACKUP PASSWORD
  // ---------------------------------------------------------------------------

  Future<bool> hasPassword() async {
    final password = await _secureStorage.read(
      key: _passwordKey,
    );

    return password != null && password.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // CREATE LOCAL BACKUP + GOOGLE DRIVE UPLOAD
  // ---------------------------------------------------------------------------

  Future<void> _backupNow() async {
    try {
      debugPrint('==============================================');
      debugPrint('Auto backup started');

      // ---------------------------------------------------------------------
      // 1. Read backup password
      // ---------------------------------------------------------------------

      final password = await _secureStorage.read(
        key: _passwordKey,
      );

      if (password == null || password.isEmpty) {
        debugPrint(
          'Auto backup skipped: backup password not configured.',
        );
        return;
      }

      // ---------------------------------------------------------------------
      // 2. Get local backup directory
      // ---------------------------------------------------------------------

      final backupDirectory = await _getAutoBackupDirectory();

      // ---------------------------------------------------------------------
      // 3. Create filename
      // ---------------------------------------------------------------------

      final fileName =
      BackupService.instance.createAutomaticFileName();

      final destination = File(
        p.join(
          backupDirectory.path,
          fileName,
        ),
      );

      // ---------------------------------------------------------------------
      // 4. Create encrypted backup bytes
      // ---------------------------------------------------------------------

      final backupBytes =
      await BackupService.instance.createEncryptedBackupBytes(
        password: password,
      );

      // ---------------------------------------------------------------------
      // 5. Save local backup FIRST
      // ---------------------------------------------------------------------

      await destination.writeAsBytes(
        backupBytes,
        flush: true,
      );

      debugPrint(
        'Local auto backup completed: ${destination.path}',
      );

      // ---------------------------------------------------------------------
      // 6. Check Google Drive connection
      // ---------------------------------------------------------------------

      bool googleDriveConnected = false;

      try {
        googleDriveConnected =
        await GoogleDriveService.instance.isConnected();
      } catch (error) {
        debugPrint(
          'Google Drive connection check failed: $error',
        );
      }

      // ---------------------------------------------------------------------
      // 7. Upload to Google Drive if connected
      // ---------------------------------------------------------------------

      if (!googleDriveConnected) {
        debugPrint(
          'Google Drive not connected. '
              'Local backup kept only.',
        );
        return;
      }

      try {
        debugPrint(
          'Uploading backup to Google Drive: $fileName',
        );

        final fileId =
        await GoogleDriveService.instance.uploadBackup(
          bytes: backupBytes,
          fileName: fileName,
        );

        debugPrint(
          'Google Drive upload completed. File ID: $fileId',
        );
      } catch (error, stackTrace) {
        // IMPORTANT:
        // Local backup already exists.
        // So Drive failure does NOT delete/lose local backup.
        debugPrint(
          'Google Drive upload failed: $error',
        );
        debugPrint(
          stackTrace.toString(),
        );
      }

      debugPrint('Auto backup finished');
      debugPrint('==============================================');
    } catch (error, stackTrace) {
      debugPrint(
        'Auto backup failed: $error',
      );
      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // GET AUTO BACKUP DIRECTORY
  // ---------------------------------------------------------------------------

  Future<Directory> _getAutoBackupDirectory() async {
    final databasePath =
    await DatabaseService.instance.getDatabasePath();

    final databaseDirectory = Directory(
      File(databasePath).parent.path,
    );

    final backupDirectory = Directory(
      p.join(
        databaseDirectory.path,
        'auto_backups',
      ),
    );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(
        recursive: true,
      );
    }

    return backupDirectory;
  }
}